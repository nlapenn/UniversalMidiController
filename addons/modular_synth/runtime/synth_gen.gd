extends Node

var playing = true
var initialized = false

var playback: AudioStreamPlayback = null # Actual playback stream, assigned in _ready().

func init_test_graph_godot():
	var lfo1ID = add_block(SynthConstants.SynthBlockType.LFOOscillator)
	set_param(lfo1ID, SynthConstants.LFOParams.Frequency, .1)
	set_param(lfo1ID, SynthConstants.LFOParams.Amplitude, .5)
	
	var lfo2ID = add_block(SynthConstants.SynthBlockType.LFOOscillator)
	set_param(lfo2ID, SynthConstants.LFOParams.Frequency, .1)
	set_param(lfo2ID, SynthConstants.LFOParams.Amplitude, .9)
	
	var lfo3ID = add_block(SynthConstants.SynthBlockType.LFOOscillator)
	set_param(lfo3ID, SynthConstants.LFOParams.Frequency, .02)
	set_param(lfo3ID, SynthConstants.LFOParams.Amplitude, .01)
	
	var envelope1ID = add_block(SynthConstants.SynthBlockType.SimpleEnvelope)
	set_param(envelope1ID, SynthConstants.EnvelopeParams.Attack, .001)
	set_param(envelope1ID, SynthConstants.EnvelopeParams.Release, .4)
	
	var osc1ID = add_block(SynthConstants.SynthBlockType.PolyBlepOscillator)
	set_param(osc1ID, SynthConstants.PolyBlepParams.Waveform, 4)
	connect_blocks(envelope1ID, osc1ID, SynthConstants.ModulationTarget.Amplitude)
	connect_blocks(lfo2ID, osc1ID, SynthConstants.ModulationTarget.PulseWidth)
	
	var osc2ID = add_block(SynthConstants.SynthBlockType.PolyBlepOscillator)
	set_param(osc2ID, SynthConstants.PolyBlepParams.Waveform, 5)
	set_param(osc2ID, SynthConstants.PolyBlepParams.FreqRatio, 1.)
	connect_blocks(lfo3ID, osc2ID, SynthConstants.ModulationTarget.Frequency)
	connect_blocks(lfo2ID, osc2ID, SynthConstants.ModulationTarget.PulseWidth)
	connect_blocks(envelope1ID, osc2ID, SynthConstants.ModulationTarget.Amplitude)
	
	var osc3ID = add_block(SynthConstants.SynthBlockType.PolyBlepOscillator)
	set_param(osc3ID, SynthConstants.PolyBlepParams.FreqRatio, 2.)
	
	var osc4ID = add_block(SynthConstants.SynthBlockType.PolyBlepOscillator)
	set_param(osc4ID, SynthConstants.PolyBlepParams.FreqRatio, .5)
	
	var moogFilterID = add_block(SynthConstants.SynthBlockType.MoogFilterBlock)
	connect_blocks(lfo1ID, moogFilterID, SynthConstants.ModulationTarget.Frequency)
	connect_blocks(osc1ID, moogFilterID, SynthConstants.ModulationTarget.Samples)
	connect_blocks(osc2ID, moogFilterID, SynthConstants.ModulationTarget.Samples)
	connect_blocks(osc3ID, moogFilterID, SynthConstants.ModulationTarget.Samples)
	connect_blocks(osc4ID, moogFilterID, SynthConstants.ModulationTarget.Samples)
	
	var synthOutputID = add_block(SynthConstants.SynthBlockType.SynthOutputBlock)
	connect_blocks(moogFilterID, synthOutputID, SynthConstants.ModulationTarget.Samples)

func _fill_buffer():
	var to_fill = playback.get_frames_available()
	$Synth.processBlock(to_fill)
	var outputBuffer = $Synth.getOutputBuffer()
	for value in range(to_fill):
		playback.push_frame(Vector2.ONE * outputBuffer[value])

func _process(_delta):
	if playing and initialized:
		_fill_buffer()
	else:
		var to_fill = playback.get_frames_available()
		print(to_fill)
		for value in range(to_fill):
			playback.push_frame(Vector2.ZERO)
		
func _ready():
	$Player.play()
	playback = $Player.get_stream_playback()
	$Synth.init($Player.stream.mix_rate, playback.get_frames_available())
	#$Synth.init_test_graph()
	#init_test_graph_godot()
	initialized = true
	_fill_buffer()

func set_param(block_id: int, param: int, value: float):
	$Synth.set_param(block_id, param, value)
	
func add_block(blockType: SynthConstants.SynthBlockType):
	playing = false
	var id = $Synth.add_block(blockType)
	playing = true
	return id
	
func connect_blocks(fromID, toID, modulationTarget):
	if modulationTarget == SynthConstants.ModulationTarget.None:
		return false
	
	playing = false
	var success = $Synth.connect_blocks(fromID, toID, modulationTarget)
	playing = true
	#reset()
	return success

func disconnect_blocks(fromID, toID, modulationTarget):
	playing = false
	$Synth.disconnect_blocks(fromID, toID, modulationTarget)
	
func setFrequency(freqInHz):
	$Synth.setFrequency(freqInHz)

func reset():
	playing = false
	$Synth.reset()
	AudioServer.set_bus_mute(0, false)
	print("Master Bus Volume: ", AudioServer.get_bus_volume_db(0))
	print("Master Bus Effect 1: ", AudioServer.get_bus_effect(0, 0))
	playing = true

func clear_traversal_list():
	$Synth.reset_traversal_list()
	
func add_block_to_traversal_list(id: int):
	$Synth.add_block_to_traversal_list(id)
