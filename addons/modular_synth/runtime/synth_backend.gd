extends Node2D
class_name ModularSynthBackend

@onready var SynthGen := $SynthGen

func set_playing(should_play: bool) -> void:
	SynthGen.playing = should_play

func set_param(block_id: int, param: int, value: float) -> void:
	SynthGen.set_param(block_id, param, value)

func add_block(block_type: int) -> int:
	return SynthGen.add_block(block_type)

func connect_blocks(from_id: int, to_id: int, modulation_target: int) -> bool:
	# Forward the backend result (GDExtension returns a success value).
	return SynthGen.connect_blocks(from_id, to_id, modulation_target)

func disconnect_blocks(from_id: int, to_id: int, modulation_target: int) -> void:
	SynthGen.disconnect_blocks(from_id, to_id, modulation_target)

func reset() -> void:
	SynthGen.reset()

func clear_traversal_list() -> void:
	SynthGen.clear_traversal_list()

func add_block_to_traversal_list(block_id: int) -> void:
	SynthGen.add_block_to_traversal_list(block_id)
