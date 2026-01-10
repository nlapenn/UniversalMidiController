extends Resource
class_name ModularSynthBlockRegistry

## Maps a SynthConstants.SynthBlockType (int) -> PackedScene
@export var block_scenes: Dictionary = {}

## Optional: maps a SynthConstants.SynthBlockType (int) -> JSON spec file path.
## If present for a given type, the graph editor can instantiate a generic block and
## build the UI/ports from the spec.
@export var block_specs: Dictionary = {}

## Optional human-readable labels for UI.
@export var block_labels: Dictionary = {}

## Optional UI categories. If set, the graph editor can group blocks in an "Add Block" menu.
## Maps SynthConstants.SynthBlockType (int) -> String (e.g. "Sources", "Math", "Filters").
@export var block_categories: Dictionary = {}

func get_scene(block_type: int) -> PackedScene:
	var scene = block_scenes.get(block_type)
	return scene if scene is PackedScene else null

func get_spec_path(block_type: int) -> String:
	var p = block_specs.get(block_type)
	return str(p) if p != null else ""

func has_spec(block_type: int) -> bool:
	return get_spec_path(block_type) != ""

func get_block_types() -> Array[int]:
	# Union of all known block types (scene-backed and spec-backed).
	var types: Dictionary = {}
	for k in block_scenes.keys():
		types[int(k)] = true
	for k in block_specs.keys():
		types[int(k)] = true
	var out: Array[int] = []
	for k in types.keys():
		out.append(int(k))
	out.sort()
	return out

func get_label(block_type: int) -> String:
	var label = block_labels.get(block_type)
	return str(label) if label != null else str(block_type)

func get_category(block_type: int) -> String:
	var cat = block_categories.get(block_type)
	return str(cat) if cat != null else ""
