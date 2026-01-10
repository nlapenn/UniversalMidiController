extends GraphNode
class_name ModularSynthGenericBlock

## A spec-driven GraphNode that builds its ports and parameter UI from JSON.

signal ParamChanged(blockId: int, param: int, value: float)

var IsOutput: bool = false
var BlockID: int = -1
var BlockType: int = -1

var _spec: Dictionary = {}
var _engine: ModularSynthEngineAdapter
var _mappings: ModularSynthMappings

var _input_targets: Array[int] = []
var _output_signals: Array[int] = []

var _param_controls: Dictionary = {} # param_id -> Control
var _param_defs: Dictionary = {} # param_id -> spec dict (with resolved param_id, key, kind, step, min, max, values)
var _param_order: Array[int] = []
var _param_key_to_id: Dictionary = {} # key(string) -> param_id
var _suppress_events: bool = false

func _as_bool(v) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT:
			return int(v) != 0
		TYPE_FLOAT:
			return float(v) != 0.0
		TYPE_STRING:
			var s := String(v).strip_edges().to_lower()
			return s == "1" or s == "true" or s == "yes" or s == "on"
		_:
			return v != null

func Init(block_id: int) -> void:
	# Compatibility with legacy blocks.
	BlockID = block_id

func configure(spec: Dictionary, engine: ModularSynthEngineAdapter, mappings: ModularSynthMappings, block_id: int) -> void:
	_spec = spec if spec != null else {}
	_engine = engine
	_mappings = mappings
	BlockID = block_id
	BlockType = int(_spec.get("type", -1))
	IsOutput = _as_bool(_spec.get("is_output", false))
	title = str(_spec.get("title", "Block"))

	_rebuild_from_spec()

func update_param(param: int, value: float) -> void:
	# Host/backend can call this to reflect parameter changes in the UI.
	var ctrl: Control = _param_controls.get(int(param))
	if ctrl == null:
		return
	_suppress_events = true
	if ctrl is HSlider:
		(ctrl as HSlider).value = float(value)
	elif ctrl is SpinBox:
		(ctrl as SpinBox).value = float(value)
	elif ctrl is CheckBox:
		(ctrl as CheckBox).button_pressed = (value != 0.0)
	elif ctrl is OptionButton:
		(ctrl as OptionButton).selected = int(value)
	_suppress_events = false


func GetNodeType() -> int:
	return BlockType

func GetModulationTargetForInputPort(port: int) -> int:
	return _input_targets[port] if port >= 0 and port < _input_targets.size() else SynthConstants.ModulationTarget.None

func GetModulationTargetForOutputPort(port: int) -> int:
	return _output_signals[port] if port >= 0 and port < _output_signals.size() else SynthConstants.ModulationTarget.None


func _rebuild_from_spec() -> void:
	# Clear children (rows) and cached parameter controls.
	_param_controls.clear()
	_param_defs.clear()
	_param_order.clear()
	_param_key_to_id.clear()
	for c in get_children():
		c.free()

	_input_targets.clear()
	_output_signals.clear()

	var ports: Dictionary = _spec.get("ports", {})
	var inputs: Array = ports.get("inputs", [])
	var outputs: Array = ports.get("outputs", [])
	var params: Array = _spec.get("params", [])

	# Resolve targets/signals.
	for i in inputs:
		_input_targets.append(_mappings.resolve_modulation_target(i.get("target")))
	for o in outputs:
		_output_signals.append(_mappings.resolve_modulation_target(o.get("signal")))

	# Layout strategy:
	# - First rows: outputs (right ports)
	# - Next rows: inputs (left ports)
	# - Then a separator row
	# - Then parameter rows (no ports)
	var row: int = 0
	row = _add_port_rows(outputs, true, row)
	row = _add_port_rows(inputs, false, row)

	# Separator
	var sep := HSeparator.new()
	add_child(sep)
	_set_row_slot(row, false, false)
	row += 1

	# Params
	for p in params:
		row = _add_param_row(p, row)

	# Apply default values to UI + backend.
	_apply_defaults(params)


func _add_port_rows(items: Array, is_output: bool, row: int) -> int:
	for item in items:
		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var left_label := Label.new()
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var right_label := Label.new()
		right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var name := str(item.get("name", ""))
		if is_output:
			right_label.text = name
			left_label.text = ""
		else:
			left_label.text = name
			right_label.text = ""

		h.add_child(left_label)
		h.add_child(right_label)
		add_child(h)

		# Enable the appropriate side's port on this row.
		_set_row_slot(row, !is_output, is_output)
		# Try to set slot titles if available (Godot 4).
		if !is_output and has_method("set_slot_title_left"):
			call("set_slot_title_left", row, name)
		if is_output and has_method("set_slot_title_right"):
			call("set_slot_title_right", row, name)
		row += 1
	return row


func _add_param_row(p: Dictionary, row: int) -> int:
	var kind := str(p.get("kind", ""))
	var label_text := str(p.get("label", p.get("key", "Param")))
	var param_id := _mappings.resolve_param_id(BlockType, p.get("param"))
	var key_str := str(p.get("key", ""))
	if key_str != "":
		_param_key_to_id[key_str] = param_id
	var def := p.duplicate(true)
	def["param_id"] = param_id
	def["key"] = key_str
	def["kind"] = kind
	_param_defs[param_id] = def
	_param_order.append(param_id)

	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)

	h.add_child(lbl)

	match kind:
		"float":
			var slider := HSlider.new()
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.min_value = float(p.get("min", 0.0))
			slider.max_value = float(p.get("max", 1.0))
			slider.step = float(p.get("step", 0.01))
			slider.value = float(p.get("default", slider.min_value))
			slider.set_meta("param_id", param_id)
			slider.value_changed.connect(Callable(self, "_on_float_changed").bind(slider))
			h.add_child(slider)

			var v := Label.new()
			v.custom_minimum_size = Vector2(60, 0)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.text = _format_value(slider.value, p)
			v.set_meta("param_id", param_id)
			h.add_child(v)

			_param_controls[param_id] = slider
			# Keep the value label synced.
			slider.value_changed.connect(func(val: float): v.text = _format_value(val, p))
		"int":
			var sp := SpinBox.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sp.min_value = float(p.get("min", 0))
			sp.max_value = float(p.get("max", 127))
			sp.step = float(p.get("step", 1))
			sp.value = float(p.get("default", sp.min_value))
			sp.set_meta("param_id", param_id)
			sp.value_changed.connect(Callable(self, "_on_float_changed").bind(sp))
			h.add_child(sp)
			_param_controls[param_id] = sp
		"bool":
			var cb := CheckBox.new()
			cb.button_pressed = _as_bool(p.get("default", false))
			cb.set_meta("param_id", param_id)
			cb.toggled.connect(Callable(self, "_on_bool_changed").bind(cb))
			h.add_child(cb)
			_param_controls[param_id] = cb
		"enum":
			var ob := OptionButton.new()
			var values: Array = p.get("values", [])
			for i in range(values.size()):
				ob.add_item(str(values[i]), i)
			ob.selected = int(p.get("default", 0))
			ob.set_meta("param_id", param_id)
			ob.item_selected.connect(Callable(self, "_on_enum_changed").bind(ob))
			h.add_child(ob)
			_param_controls[param_id] = ob
		_:
			var unknown := Label.new()
			unknown.text = "(unsupported)"
			h.add_child(unknown)

	add_child(h)
	_set_row_slot(row, false, false)
	return row + 1


func _set_row_slot(row: int, enable_left: bool, enable_right: bool) -> void:
	# GraphNode.set_slot exists in Godot 3/4. Colors are purely visual.
	set_slot(row, enable_left, 0, Color(1, 1, 1, 1), enable_right, 0, Color(1, 1, 1, 1))


func _apply_defaults(params: Array) -> void:
	if _engine == null or !_engine.is_valid():
		return
	_suppress_events = true
	for p in params:
		if !p.has("default"):
			continue
		var kind := str(p.get("kind", ""))
		var param_id := _mappings.resolve_param_id(BlockType, p.get("param"))
		if param_id < 0:
			continue
		match kind:
			"float", "int":
				_engine.set_param(BlockID, param_id, float(p.get("default")))
			"bool":
				_engine.set_param(BlockID, param_id, 1.0 if _as_bool(p.get("default")) else 0.0)
			"enum":
				_engine.set_param(BlockID, param_id, float(int(p.get("default"))))
	_suppress_events = false


func _on_float_changed(value: float, ctrl: Control) -> void:
	if _suppress_events:
		return
	var param_id := int(ctrl.get_meta("param_id"))
	ParamChanged.emit(BlockID, param_id, float(value))

func _on_bool_changed(pressed: bool, cb: CheckBox) -> void:
	if _suppress_events:
		return
	var param_id := int(cb.get_meta("param_id"))
	ParamChanged.emit(BlockID, param_id, 1.0 if pressed else 0.0)

func _on_enum_changed(index: int, ob: OptionButton) -> void:
	if _suppress_events:
		return
	var param_id := int(ob.get_meta("param_id"))
	ParamChanged.emit(BlockID, param_id, float(index))


# --- Controller / host API ---

func get_param_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pid in _param_order:
		var d = _param_defs.get(pid)
		if d != null:
			result.append(d)
	return result

func resolve_param_id_by_key(key: String) -> int:
	return int(_param_key_to_id.get(key, -1))

func get_param_value(param_id: int) -> Variant:
	var ctrl: Control = _param_controls.get(int(param_id))
	if ctrl == null:
		return null
	if ctrl is HSlider:
		return float((ctrl as HSlider).value)
	if ctrl is SpinBox:
		return float((ctrl as SpinBox).value)
	if ctrl is CheckBox:
		return 1.0 if (ctrl as CheckBox).button_pressed else 0.0
	if ctrl is OptionButton:
		return float((ctrl as OptionButton).selected)
	return null

func set_param_value(param_id: int, value: float, update_ui: bool = true) -> void:
	# Updates UI (optional) and emits ParamChanged so the graph editor drives the engine.
	var pid := int(param_id)
	if update_ui:
		var ctrl: Control = _param_controls.get(pid)
		if ctrl != null:
			_suppress_events = true
			if ctrl is HSlider:
				(ctrl as HSlider).value = float(value)
			elif ctrl is SpinBox:
				(ctrl as SpinBox).value = float(value)
			elif ctrl is CheckBox:
				(ctrl as CheckBox).button_pressed = (value != 0.0)
			elif ctrl is OptionButton:
				(ctrl as OptionButton).selected = int(value)
			_suppress_events = false
	ParamChanged.emit(BlockID, pid, float(value))

func nudge_param(param_id: int, steps: int) -> void:
	var pid := int(param_id)
	var def: Dictionary = _param_defs.get(pid, {})
	if def.is_empty():
		return
	var kind := str(def.get("kind", ""))
	var cur_v := get_param_value(pid)
	if cur_v == null:
		cur_v = float(def.get("default", 0))
	match kind:
		"enum":
			var values: Array = def.get("values", [])
			var n := int(values.size())
			if n <= 0:
				return
			var idx := int(cur_v) + int(steps)
			idx = clampi(idx, 0, n - 1)
			set_param_value(pid, float(idx), true)
		"bool":
			if steps == 0:
				return
			var nv := 0.0 if float(cur_v) != 0.0 else 1.0
			set_param_value(pid, nv, true)
		"int":
			var step_i := int(def.get("step", 1))
			var min_i := int(def.get("min", -2147483648))
			var max_i := int(def.get("max", 2147483647))
			var nv_i := int(cur_v) + int(steps) * step_i
			nv_i = clampi(nv_i, min_i, max_i)
			set_param_value(pid, float(nv_i), true)
		_:
			# float (default)
			var min_f := float(def.get("min", -1e20))
			var max_f := float(def.get("max",  1e20))
			var step_f := float(def.get("step", 0.0))
			if step_f == 0.0:
				# Reasonable default resolution if spec doesn't include step.
				step_f = max(0.001, (max_f - min_f) / 200.0) if (max_f > min_f and max_f < 1e19 and min_f > -1e19) else 0.01
			var nv_f := float(cur_v) + float(steps) * step_f
			nv_f = clamp(nv_f, min_f, max_f)
			set_param_value(pid, nv_f, true)

func nudge_param_key(key: String, steps: int) -> void:
	var pid := resolve_param_id_by_key(key)
	if pid < 0:
		return
	nudge_param(pid, steps)

func _format_value(v: float, p: Dictionary) -> String:
	var fmt := str(p.get("format", ""))
	if fmt != "":
		return fmt % v
	# Default: keep it compact.
	if abs(v) >= 10.0:
		return "%.2f" % v
	return "%.3f" % v
