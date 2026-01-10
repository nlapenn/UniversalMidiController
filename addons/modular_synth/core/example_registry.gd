extends ModularSynthBlockRegistry
class_name ModularSynthExampleRegistry

func _init() -> void:
	# Example registry wired to the addon-shipped JSON specs.
	# All blocks are spec-driven; no per-block scenes required.
	block_scenes = {}
	block_specs = {
		SynthConstants.SynthBlockType.PolyBlepOscillator: "res://addons/modular_synth/specs/poly_blep_osc.json",
		SynthConstants.SynthBlockType.LFOOscillator: "res://addons/modular_synth/specs/lfo_osc.json",
		SynthConstants.SynthBlockType.SimpleEnvelope: "res://addons/modular_synth/specs/simple_envelope.json",
		SynthConstants.SynthBlockType.MoogFilterBlock: "res://addons/modular_synth/specs/moog_filter.json",
		SynthConstants.SynthBlockType.SynthOutputBlock: "res://addons/modular_synth/specs/output.json",
		SynthConstants.SynthBlockType.LinGainBlock: "res://addons/modular_synth/specs/gain.json",
		SynthConstants.SynthBlockType.DCOffsetBlock: "res://addons/modular_synth/specs/dcoffset.json",
		SynthConstants.SynthBlockType.ClampBlock: "res://addons/modular_synth/specs/clamp.json",
		SynthConstants.SynthBlockType.AddSignalsBlock: "res://addons/modular_synth/specs/add.json",
		SynthConstants.SynthBlockType.MultSignalsBlock: "res://addons/modular_synth/specs/mult.json",
		SynthConstants.SynthBlockType.MaxSignalsBlock: "res://addons/modular_synth/specs/max.json",
		SynthConstants.SynthBlockType.MinSignalsBlock: "res://addons/modular_synth/specs/min.json",
		SynthConstants.SynthBlockType.RectifyBlock: "res://addons/modular_synth/specs/rectify.json",
		SynthConstants.SynthBlockType.HalfWaveRectifyBlock: "res://addons/modular_synth/specs/half_rectify.json",
	}

	block_labels = {
		SynthConstants.SynthBlockType.PolyBlepOscillator: "PolyBLEP Osc",
		SynthConstants.SynthBlockType.LFOOscillator: "LFO",
		SynthConstants.SynthBlockType.SimpleEnvelope: "Envelope",
		SynthConstants.SynthBlockType.MoogFilterBlock: "Moog Filter",
		SynthConstants.SynthBlockType.SynthOutputBlock: "Output",
		SynthConstants.SynthBlockType.LinGainBlock: "Gain",
		SynthConstants.SynthBlockType.DCOffsetBlock: "DC Offset",
		SynthConstants.SynthBlockType.ClampBlock: "Clamp",
		SynthConstants.SynthBlockType.AddSignalsBlock: "Add",
		SynthConstants.SynthBlockType.MultSignalsBlock: "Multiply",
		SynthConstants.SynthBlockType.MaxSignalsBlock: "Max",
		SynthConstants.SynthBlockType.MinSignalsBlock: "Min",
		SynthConstants.SynthBlockType.RectifyBlock: "Rectify",
		SynthConstants.SynthBlockType.HalfWaveRectifyBlock: "Half Rectify",
	}

	block_categories = {
		SynthConstants.SynthBlockType.PolyBlepOscillator: "Sources",
		SynthConstants.SynthBlockType.LFOOscillator: "Sources",
		SynthConstants.SynthBlockType.SimpleEnvelope: "Modulators",
		SynthConstants.SynthBlockType.MoogFilterBlock: "Filters",
		SynthConstants.SynthBlockType.SynthOutputBlock: "Routing",
		SynthConstants.SynthBlockType.LinGainBlock: "Utilities",
		SynthConstants.SynthBlockType.DCOffsetBlock: "Utilities",
		SynthConstants.SynthBlockType.ClampBlock: "Utilities",
		SynthConstants.SynthBlockType.AddSignalsBlock: "Math",
		SynthConstants.SynthBlockType.MultSignalsBlock: "Math",
		SynthConstants.SynthBlockType.MaxSignalsBlock: "Math",
		SynthConstants.SynthBlockType.MinSignalsBlock: "Math",
		SynthConstants.SynthBlockType.RectifyBlock: "Waveshaping",
		SynthConstants.SynthBlockType.HalfWaveRectifyBlock: "Waveshaping",
	}
