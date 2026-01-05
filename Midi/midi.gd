extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(MidiOut.get_port_count()):
		print(MidiOut.get_port_name(i))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
