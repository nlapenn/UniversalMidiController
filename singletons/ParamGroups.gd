extends Node
class_name ConfigStore

# Raw JSON roots
var params_root: Dictionary = {}
var groups_root: Dictionary = {}

# Indexed / normalized
var parameters_by_id: Dictionary = {}   # String -> Dictionary (param)
var groups_list: Array = []             # Array[Dictionary] (group)
var active_group_index: int = 0

func load_all(params_path: String = "res://data/parameters.json", groups_path: String = "res://data/groups_micron.json") -> void:
	params_root = _load_json(params_path)
	groups_root = _load_json(groups_path)

	_build_parameters_index()
	_build_groups()

func _build_parameters_index() -> void:
	parameters_by_id.clear()

	var arr = params_root.get("parameters", [])
	if arr is Array:
		for p in arr:
			if p is Dictionary and p.has("id"):
				parameters_by_id[str(p["id"])] = p

func _build_groups() -> void:
	groups_list = []
	active_group_index = int(groups_root.get("active", 0))

	var arr = groups_root.get("groups", [])
	if not (arr is Array):
		return

	for g in arr:
		if not (g is Dictionary):
			continue

		var ng = g.duplicate(true)  # deep copy so we can normalize

		# Ensure expected fields exist
		if not ng.has("name"):
			ng["name"] = "Unnamed"
		if not ng.has("parameters") or not (ng["parameters"] is Array):
			ng["parameters"] = []
		if not ng.has("controllers") or not (ng["controllers"] is Dictionary):
			ng["controllers"] = {}
		if not ng.has("controller_colors") or not (ng["controller_colors"] is Array):
			ng["controller_colors"] = []

		# Validate parameter ids exist; drop unknowns (or keep and warn)
		var cleaned_params: Array = []
		for pid in ng["parameters"]:
			var id := str(pid)
			if parameters_by_id.has(id):
				cleaned_params.append(id)
			else:
				push_warning("Group '%s' references missing parameter id: %s" % [ng["name"], id])
		ng["parameters"] = cleaned_params

		# Normalize controller mapping keys to strings, values to ints
		var ctrl_map: Dictionary = {}
		for k in ng["controllers"].keys():
			ctrl_map[str(k)] = int(ng["controllers"][k])
		ng["controllers"] = ctrl_map

		# Normalize colors to exactly 16 entries (strings for now)
		var cols: Array = ng["controller_colors"]
		while cols.size() < 16:
			cols.append("Grey")
		if cols.size() > 16:
			cols = cols.slice(0, 16)
		ng["controller_colors"] = cols

		groups_list.append(ng)

	# Clamp active index
	if groups_list.size() == 0:
		active_group_index = 0
	else:
		active_group_index = clampi(active_group_index, 0, groups_list.size() - 1)

func get_active_group() -> Dictionary:
	return get_group(active_group_index)

func get_group(i: int) -> Dictionary:
	if i < 0 or i >= groups_list.size():
		return {}
	return groups_list[i]

func set_active_group(i: int) -> void:
	if groups_list.size() == 0:
		active_group_index = 0
		return
	active_group_index = clampi(i, 0, groups_list.size() - 1)

func get_parameter(pid: String) -> Dictionary:
	return parameters_by_id.get(pid, {})

func get_parameters_for_group(group: Dictionary) -> Array:
	# returns Array[Dictionary] for this group, in group order
	var out: Array = []
	var ids = group.get("parameters", [])
	if ids is Array:
		for pid in ids:
			var p = get_parameter(str(pid))
			if not p.is_empty():
				out.append(p)
	return out

func get_controller_for_param(group: Dictionary, pid: String) -> int:
	# returns controller number or -1 if unmapped
	var m = group.get("controllers", {})
	if m is Dictionary and m.has(pid):
		return int(m[pid])
	return -1

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open JSON: %s" % path)
		return {}

	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Invalid JSON in: %s" % path)
		return {}

	if parsed is Dictionary:
		return parsed

	push_error("JSON root must be an object: %s" % path)
	return {}
