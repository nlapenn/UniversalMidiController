extends Node
class_name ModularSynthEngineAdapter

## NodePath to an object that implements the synth engine API.
var _backend_path: NodePath = NodePath("")

@export var backend_path: NodePath:
	set(value):
		_backend_path = value
		_refresh_backend()
	get:
		return _backend_path

var backend: Node

func _ready() -> void:
	# Helpful for auto-wiring in host scenes.
	add_to_group("modular_synth_engine_adapter")
	_refresh_backend()

func _refresh_backend() -> void:
	if !is_inside_tree():
		return
	backend = get_node_or_null(_backend_path)

func set_backend_path(path: NodePath) -> void:
	backend_path = path

func is_valid() -> bool:
	return backend != null

func with_audio_paused(fn: Callable) -> void:
	# Simple, safe helper: pause -> call -> resume.
	if backend == null:
		return
	if backend.has_method("set_playing"):
		backend.call("set_playing", false)
	fn.call()
	if backend.has_method("set_playing"):
		backend.call("set_playing", true)

func set_playing(should_play: bool) -> void:
	if backend != null and backend.has_method("set_playing"):
		backend.call("set_playing", should_play)

func set_param(block_id: int, param: int, value: float) -> void:
	if backend != null and backend.has_method("set_param"):
		backend.call("set_param", block_id, param, value)

func add_block(block_type: int) -> int:
	if backend == null or !backend.has_method("add_block"):
		return -1
	return int(backend.call("add_block", block_type))

func connect_blocks(from_id: int, to_id: int, modulation_target: int) -> bool:
	if backend == null or !backend.has_method("connect_blocks"):
		return false
	# Godot 4 GDScript doesn't provide a bool() constructor; handle common return types.
	var r = backend.call("connect_blocks", from_id, to_id, modulation_target)
	match typeof(r):
		TYPE_BOOL:
			return r
		TYPE_INT:
			return int(r) != 0
		TYPE_FLOAT:
			return float(r) != 0.0
		_:
			return r != null

func disconnect_blocks(from_id: int, to_id: int, modulation_target: int) -> void:
	if backend != null and backend.has_method("disconnect_blocks"):
		backend.call("disconnect_blocks", from_id, to_id, modulation_target)

func reset() -> void:
	if backend != null and backend.has_method("reset"):
		backend.call("reset")

func clear_traversal_list() -> void:
	if backend != null and backend.has_method("clear_traversal_list"):
		backend.call("clear_traversal_list")

func add_block_to_traversal_list(block_id: int) -> void:
	if backend != null and backend.has_method("add_block_to_traversal_list"):
		backend.call("add_block_to_traversal_list", block_id)
