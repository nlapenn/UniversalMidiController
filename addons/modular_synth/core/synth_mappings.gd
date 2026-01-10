extends RefCounted
class_name ModularSynthMappings

## Helpers to resolve human-readable strings in JSON specs to the engine enums.
## Assumes SynthConstants.* enums stay in sync with the GDExtension.

func resolve_modulation_target(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) != TYPE_STRING:
		return SynthConstants.ModulationTarget.None
	match String(value):
		"Samples": return SynthConstants.ModulationTarget.Samples
		"Frequency": return SynthConstants.ModulationTarget.Frequency
		"PulseWidth": return SynthConstants.ModulationTarget.PulseWidth
		"Amplitude": return SynthConstants.ModulationTarget.Amplitude
		"PitchCoarse": return SynthConstants.ModulationTarget.PitchCoarse
		"PitchFine": return SynthConstants.ModulationTarget.PitchFine
		"Attack": return SynthConstants.ModulationTarget.Attack
		"Release": return SynthConstants.ModulationTarget.Release
		"Resonance": return SynthConstants.ModulationTarget.Resonance
		"Sync": return SynthConstants.ModulationTarget.Sync
		"None": return SynthConstants.ModulationTarget.None
		_:
			return SynthConstants.ModulationTarget.None


func resolve_param_id(block_type: int, value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) != TYPE_STRING:
		return -1
	var name := String(value)
	match block_type:
		SynthConstants.SynthBlockType.PolyBlepOscillator:
			return _resolve_polyblep_param(name)
		SynthConstants.SynthBlockType.LFOOscillator:
			return _resolve_lfo_param(name)
		SynthConstants.SynthBlockType.SimpleEnvelope:
			return _resolve_env_param(name)
		SynthConstants.SynthBlockType.MoogFilterBlock, SynthConstants.SynthBlockType.LPFBlock:
			return _resolve_filter_param(name)
		SynthConstants.SynthBlockType.LinGainBlock:
			return _resolve_gain_param(name)
		SynthConstants.SynthBlockType.DCOffsetBlock:
			return _resolve_dcoffset_param(name)
		SynthConstants.SynthBlockType.ClampBlock:
			return _resolve_clamp_param(name)
		_:
			return -1


func _resolve_polyblep_param(name: String) -> int:
	match name:
		"Waveform": return SynthConstants.PolyBlepParams.Waveform
		"Frequency": return SynthConstants.PolyBlepParams.Frequency
		"FreqRatio": return SynthConstants.PolyBlepParams.FreqRatio
		"PitchCoarse": return SynthConstants.PolyBlepParams.PitchCoarse
		"PitchFine": return SynthConstants.PolyBlepParams.PitchFine
		"PulseWidth": return SynthConstants.PolyBlepParams.PulseWidth
		"Amplitude": return SynthConstants.PolyBlepParams.Amplitude
		"SyncAmplitude": return SynthConstants.PolyBlepParams.SyncAmplitude
		_:
			return -1

func _resolve_lfo_param(name: String) -> int:
	match name:
		"Frequency": return SynthConstants.LFOParams.Frequency
		"Amplitude": return SynthConstants.LFOParams.Amplitude
		_:
			return -1

func _resolve_env_param(name: String) -> int:
	match name:
		"Attack": return SynthConstants.EnvelopeParams.Attack
		"Release": return SynthConstants.EnvelopeParams.Release
		"Amplitude": return SynthConstants.EnvelopeParams.Amplitude
		_:
			return -1

func _resolve_filter_param(name: String) -> int:
	match name:
		"Cutoff": return SynthConstants.FilterParams.Cutoff
		"Resonance": return SynthConstants.FilterParams.Resonance
		_:
			return -1

func _resolve_gain_param(name: String) -> int:
	match name:
		"Gain": return SynthConstants.GainParams.Gain
		_:
			return -1

func _resolve_dcoffset_param(name: String) -> int:
	match name:
		"Amount": return SynthConstants.DCOffsetParams.Amount
		_:
			return -1

func _resolve_clamp_param(name: String) -> int:
	match name:
		"MinValue": return SynthConstants.ClampParams.MinValue
		"MaxValue": return SynthConstants.ClampParams.MaxValue
		_:
			return -1
