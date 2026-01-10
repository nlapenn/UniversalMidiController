extends Control

## Drop-in modular patch editor UI.
##
## Usage (minimal):
## - Add this scene to your project.
## - Add a ModularSynthEngineAdapter node somewhere and point it at your backend.
## - Assign engine_adapter_path and a ModularSynthBlockRegistry.

var _engine_adapter_path: NodePath = NodePath("")

@export var engine_adapter_path: NodePath:
	set(value):
		_engine_adapter_path = value
		_refresh_refs()
	get:
		return _engine_adapter_path
@export var registry: ModularSynthBlockRegistry

var _graph_edit_path: NodePath = NodePath("VoiceGraph")

var _add_menu_path: NodePath = NodePath("TopBar/AddBlockMenu")

@export var graph_edit_path: NodePath:
	set(value):
		_graph_edit_path = value
		_refresh_refs()
	get:
		return _graph_edit_path

@export var add_menu_path: NodePath:
	set(value):
		_add_menu_path = value
		_refresh_refs()
	get:
		return _add_menu_path

@export var initial_pos: Vector2 = Vector2(50, 50)
@export var node_offset_per_insert: Vector2 = Vector2(20, 20)

signal selected_block_changed(block_id: int)
signal blocks_changed(action: String, block_id: int, block_type: int)

var selected_block_id: int = -1
var _block_id_to_node: Dictionary = {} # int -> Node
@export var debug_logs: bool = false

var playing: bool = true
var block_index: int = 0

var engine: ModularSynthEngineAdapter
var graph: GraphEdit
var _selection_signals_connected: bool = false
var add_menu: MenuButton
var _add_menu_connected: bool = false
var _last_menu_key: String = ""
var _menu_registry_fingerprint: int = 0

var _spec_loader := ModularSynthBlockSpecLoader.new()
var _mappings := ModularSynthMappings.new()

var _generic_block_scene := preload("res://addons/modular_synth/blocks/generic_block.tscn")

func _ready() -> void:
	# The host scene often sets engine_adapter_path/registry *after* instancing.
	# Resolve references on the next idle frame so exported properties have been applied.
	call_deferred("_refresh_refs")


## Convenience for host scenes: call instead of setting properties directly.
func set_engine_adapter_path(path: NodePath) -> void:
	engine_adapter_path = path

## Convenience for host scenes: call instead of setting properties directly.
func set_registry(reg: ModularSynthBlockRegistry) -> void:
	registry = reg
	# Ensure the Add Block menu is rebuilt when the host assigns the registry after _ready().
	_last_menu_key = ""
	if is_inside_tree():
		call_deferred("_rebuild_add_menu_if_needed")

func _refresh_refs() -> void:
	if !is_inside_tree():
		return
	# Resolve GraphEdit.
	graph = get_node_or_null(_graph_edit_path) as GraphEdit
	if graph == null:
		# Fallback: first GraphEdit descendant.
		graph = find_child("VoiceGraph", true, false) as GraphEdit
		if graph == null:
			graph = find_child("GraphEdit", true, false) as GraphEdit

	# Resolve engine adapter.
	engine = get_node_or_null(_engine_adapter_path) as ModularSynthEngineAdapter
	if engine == null:
		# Fallback: sibling/ancestor by name.
		engine = get_parent().find_child("EngineAdapter", true, false) as ModularSynthEngineAdapter
	if engine == null:
		# Fallback: any adapter in group.
		var candidates := get_tree().get_nodes_in_group("modular_synth_engine_adapter")
		if candidates.size() > 0:
			engine = candidates[0] as ModularSynthEngineAdapter
	# Don't hard-hide permanently; allow the host to set paths later.
	# Resolve the Add Block menu (optional).
	add_menu = get_node_or_null(_add_menu_path) as MenuButton
	if add_menu == null:
		add_menu = find_child("AddBlockMenu", true, false) as MenuButton

	# Hook selection signals once so external controllers can track selection.
	if graph != null and !_selection_signals_connected:
		if graph.has_signal("node_selected"):
			graph.node_selected.connect(Callable(self, "_on_graph_node_selected"))
		if graph.has_signal("node_deselected"):
			graph.node_deselected.connect(Callable(self, "_on_graph_node_deselected"))
		_selection_signals_connected = true

	# Build the Add Block menu from the registry (does not require a valid engine).
	_rebuild_add_menu_if_needed()

	if graph == null:
		return
	if engine != null and engine.is_valid() and debug_logs:
		print("[ModularSynth] EngineAdapter ok. backend_path=", engine.backend_path, " backend=", engine.backend)
	elif engine != null and !engine.is_valid():
		push_warning("ModularSynth: EngineAdapter is present but not valid (backend not assigned?)")


func _rebuild_add_menu_if_needed() -> void:
	if add_menu == null or registry == null:
		return

	# Compute a cheap "fingerprint" of the menu contents so we don't rebuild every time.
	var types: Array[int] = registry.get_block_types()
	var parts: PackedStringArray = []
	for t in types:
		var ti: int = int(t)
		parts.append("%d|%s|%s" % [ti, registry.get_category(ti), registry.get_label(ti)])
	var menu_key := ";".join(parts)
	if menu_key == _last_menu_key:
		return
	_last_menu_key = menu_key

	var popup := add_menu.get_popup()
	popup.clear()
	var cb := Callable(self, "_on_add_block_menu_id_pressed")
	if !popup.id_pressed.is_connected(cb):
		popup.id_pressed.connect(cb)

	# Group by category and sort.
	var grouped: Dictionary = {}
	for ti in types:
		var cat := registry.get_category(ti)
		if cat == "":
			cat = "Blocks"
		if !grouped.has(cat):
			grouped[cat] = []
		(grouped[cat] as Array).append(ti)

	var categories: Array = grouped.keys()
	categories.sort()
	for cat in categories:
		var arr: Array = grouped[cat]
		# Sort within category by label.
		arr.sort_custom(func(a, b):
			return registry.get_label(int(a)).to_lower() < registry.get_label(int(b)).to_lower()
		)
		for ti in arr:
			var label := registry.get_label(int(ti))
			popup.add_item("%s / %s" % [str(cat), label], int(ti))
		popup.add_separator()

	# Remove trailing separator if we added one.
	if popup.get_item_count() > 0:
		var last_index := popup.get_item_count() - 1
		if popup.is_item_separator(last_index):
			popup.remove_item(last_index)


func _on_add_block_menu_id_pressed(id: int) -> void:
	_add_block(id)

func _on_param_changed(block_id: int, param: int, value: float) -> void:
	engine.set_param(block_id, param, value)

func insert_node_for_type(block_type: int, block_id: int) -> void:
	if registry == null:
		push_warning("ModularSynth: No registry assigned; cannot spawn blocks.")
		return

	var node: Node = null
	if registry.has_spec(block_type):
		var spec_path := registry.get_spec_path(block_type)
		var spec := _spec_loader.load_spec(spec_path)
		if spec.is_empty():
			push_warning("ModularSynth: Failed to load spec for type %s (%s)" % [str(block_type), spec_path])
			return
		# Ensure the spec's type matches the requested type.
		spec["type"] = int(block_type)
		node = _generic_block_scene.instantiate()
		if node.has_method("configure"):
			node.call("configure", spec, engine, _mappings, block_id)
	else:
		var scene := registry.get_scene(block_type)
		if scene == null:
			push_warning("ModularSynth: Registry missing scene/spec for type %s" % str(block_type))
			return
		node = scene.instantiate()
	if node is GraphNode:
		(node as GraphNode).set_position_offset(initial_pos + (node_offset_per_insert * float(block_index)))
	if node.has_method("Init"):
		node.call("Init", block_id)
	if node.has_signal("ParamChanged"):
		node.connect("ParamChanged", Callable(self, "_on_param_changed"))
	graph.add_child(node)
	# Controller-friendly groups / lookup
	_block_id_to_node[int(block_id)] = node
	node.add_to_group("modular_synth_block")
	node.add_to_group("modular_synth_block_id_%d" % int(block_id))
	node.add_to_group("modular_synth_block_type_%d" % int(block_type))
	blocks_changed.emit("added", int(block_id), int(block_type))
	# Clean up lookup when node is freed
	if node.has_signal("tree_exited"):
		node.tree_exited.connect(func():
			_block_id_to_node.erase(int(block_id))
			blocks_changed.emit("removed", int(block_id), int(block_type))
			if selected_block_id == int(block_id):
				selected_block_id = -1
				selected_block_changed.emit(-1)
		)
	block_index += 1

func _add_block(block_type: int) -> void:
	if engine == null:
		push_warning("ModularSynth: No EngineAdapter found. Set engine_adapter_path or add an EngineAdapter node.")
		return
	if !engine.is_valid():
		push_warning("ModularSynth: EngineAdapter found, but backend is null. Set EngineAdapter.backend_path.")
		return
	engine.with_audio_paused(func():
		var new_id := engine.add_block(block_type)
		if debug_logs:
			print("[ModularSynth] add_block type=", block_type, " -> id=", new_id)
		if new_id >= 0:
			insert_node_for_type(block_type, new_id)
	)

# --- Button handlers (kept for compatibility with the demo scene) ---
func _on_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.PolyBlepOscillator)

func _on_lfo_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.LFOOscillator)

func _on_envelope_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.SimpleEnvelope)

func _on_filter_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.MoogFilterBlock)

func _on_output_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.SynthOutputBlock)

func _on_gain_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.LinGainBlock)

func _on_dcoffset_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.DCOffsetBlock)

func _on_clamp_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.ClampBlock)

func _on_add_signals_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.AddSignalsBlock)

func _on_mult_signals_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.MultSignalsBlock)

func _on_max_signals_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.MaxSignalsBlock)

func _on_min_signals_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.MinSignalsBlock)

func _on_rectify_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.RectifyBlock)

func _on_half_rectify_button_pressed() -> void:
	_add_block(SynthConstants.SynthBlockType.HalfWaveRectifyBlock)

# --- Graph connection handling ---
func _on_voice_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if engine == null or !engine.is_valid() or graph == null:
		return
	if from_node == to_node:
		return
	var from_node_obj := graph.get_node(NodePath(from_node))
	var to_node_obj := graph.get_node(NodePath(to_node))
	if from_node_obj == null or to_node_obj == null:
		return
	if !to_node_obj.has_method("GetModulationTargetForInputPort"):
		return
	var target := int(to_node_obj.call("GetModulationTargetForInputPort", to_port))
	if target == SynthConstants.ModulationTarget.None:
		return

	engine.with_audio_paused(func():
		var ok := engine.connect_blocks(int(from_node_obj.BlockID), int(to_node_obj.BlockID), target)
		if ok:
			graph.connect_node(from_node, from_port, to_node, to_port)
	)

func _on_voice_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if engine == null or !engine.is_valid() or graph == null:
		return
	if from_node == to_node:
		return
	var from_node_obj := graph.get_node(NodePath(from_node))
	var to_node_obj := graph.get_node(NodePath(to_node))
	if from_node_obj == null or to_node_obj == null:
		return
	if !to_node_obj.has_method("GetModulationTargetForInputPort"):
		return
	var target := int(to_node_obj.call("GetModulationTargetForInputPort", to_port))

	engine.with_audio_paused(func():
		engine.disconnect_blocks(int(from_node_obj.BlockID), int(to_node_obj.BlockID), target)
		graph.disconnect_node(from_node, from_port, to_node, to_port)
	)

# --- Optional demo controls ---
func _on_reset_button_pressed() -> void:
	# Don't hardwire AudioServer changes in the portable version.
	engine.with_audio_paused(func():
		engine.reset()
	)

func _on_pause_arp_button_pressed() -> void:
	playing = !playing
	engine.set_playing(playing)

func _on_bypass_effects_button_pressed() -> void:
	# Demo-only: host projects can remove this button or override behavior.
	push_warning("ModularSynth: Bypass FX is demo-only (no-op in addon scene).")

# --- Debug / traversal ordering (optional) ---
func _get_node_from_string_path(path: String) -> Node:
	return graph.get_node(NodePath(path))

func _get_id_from_node_string_path(path: String) -> int:
	var node := graph.get_node(NodePath(path))
	return int(node.BlockID) if node != null else -1

func _get_max_distance_to_output(from_node: String, depth: int) -> int:
	var node := _get_node_from_string_path(from_node)
	if node != null and node.IsOutput:
		return depth
	var next_depth := depth + 1
	var connection_list: Array = graph.get_connection_list().duplicate()
	var max_depth := next_depth
	for c in connection_list:
		if c.get("from_node", "") == from_node:
			max_depth = max(max_depth, _get_max_distance_to_output(str(c.get("to_node")), next_depth))
	return max_depth

func _get_node_distances() -> Dictionary:
	var all_nodes: Array[String] = []
	var connection_list: Array = graph.get_connection_list().duplicate()
	for c in connection_list:
		var fn := str(c.get("from_node", ""))
		if fn != "" and !all_nodes.has(fn):
			all_nodes.append(fn)

	var depths := {}
	for node_path in all_nodes:
		var d := _get_max_distance_to_output(node_path, 0)
		depths[_get_id_from_node_string_path(node_path)] = d
	return depths

func _get_output_block_id() -> int:
	var connection_list: Array = graph.get_connection_list().duplicate()
	for c in connection_list:
		var tn := str(c.get("to_node", ""))
		var node := _get_node_from_string_path(tn)
		if node != null and node.IsOutput:
			return _get_id_from_node_string_path(tn)
	return -1

func _on_print_graph_button_pressed() -> void:
	if graph == null:
		return
	var node_depths := _get_node_distances()
	var traversal: Array[int] = []

	while !node_depths.is_empty():
		var furthest_id: int = -1
		var furthest_dist: int = -1
		for k in node_depths.keys():
			var dist := int(node_depths[k])
			if dist > furthest_dist:
				furthest_id = int(k)
				furthest_dist = dist
		traversal.append(furthest_id)
		node_depths.erase(furthest_id)

	print("Traversal order: ", traversal)

	# If your backend supports a manual traversal list, forward it.
	engine.clear_traversal_list()
	for block_id in traversal:
		engine.add_block_to_traversal_list(block_id)
	var out_id := _get_output_block_id()
	if out_id >= 0:
		engine.add_block_to_traversal_list(out_id)

# --- Selection tracking ---
func _on_graph_node_selected(node: Node) -> void:
	if node == null:
		return
	if node is ModularSynthGenericBlock:
		selected_block_id = int((node as ModularSynthGenericBlock).BlockID)
		selected_block_changed.emit(selected_block_id)

func _on_graph_node_deselected(node: Node) -> void:
	# Keep last selection if multiple nodes are selected; recompute if needed.
	if graph == null:
		return
	var any_selected := false
	for c in graph.get_children():
		if !(c is ModularSynthGenericBlock):
			continue
		var b := c as ModularSynthGenericBlock
		var entry := {
			"block_id": int(b.BlockID),
			"block_type": int(b.BlockType),
			"title": (b as GraphNode).title,
			"node_name": b.name,
		}

func get_block_node(block_id: int) -> Node:
	return _block_id_to_node.get(int(block_id))

func list_blocks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null:
		return result
	for c in graph.get_children():
		if !(c is ModularSynthGenericBlock):
			continue
		var b := c as ModularSynthGenericBlock
		result.append({
			"block_id": int(b.BlockID),
			"block_type": int(b.BlockType),
			"title": (b as GraphNode).title,
			"node_name": b.name,
		})
	return result

func set_selected_block(block_id: int) -> void:
	if graph == null:
		return
	var target := get_block_node(block_id)
	if target == null:
		# fallback scan
		for c in graph.get_children():
			if c is ModularSynthGenericBlock and int((c as ModularSynthGenericBlock).BlockID) == int(block_id):
				target = c
				break
	# Deselect others
	for c in graph.get_children():
		if c is GraphNode:
			(c as GraphNode).selected = false
	if target != null and target is GraphNode:
		(target as GraphNode).selected = true
		selected_block_id = int(block_id)
		selected_block_changed.emit(selected_block_id)

func get_selected_block_id() -> int:
	return selected_block_id

func list_params(block_id: int) -> Array[Dictionary]:
	var node := get_block_node(block_id)
	if node != null and node.has_method("get_param_list"):
		return node.call("get_param_list")
	return []

func list_all_params() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in list_blocks():
		var bid := int(b["block_id"])
		var params := list_params(bid)
		for p in params:
			var d := p.duplicate(true)
			d["block_id"] = bid
			result.append(d)
	return result

func nudge_param(block_id: int, param_id: int, steps: int) -> void:
	var node := get_block_node(block_id)
	if node != null and node.has_method("nudge_param"):
		node.call("nudge_param", int(param_id), int(steps))
		return

func nudge_param_key(block_id: int, key: String, steps: int) -> void:
	var node := get_block_node(block_id)
	if node != null and node.has_method("nudge_param_key"):
		node.call("nudge_param_key", key, int(steps))
		return

func nudge_selected_param(param_id: int, steps: int) -> void:
	if selected_block_id < 0:
		return
	nudge_param(selected_block_id, int(param_id), int(steps))

func nudge_selected_param_key(key: String, steps: int) -> void:
	if selected_block_id < 0:
		return
	nudge_param_key(selected_block_id, key, int(steps))
