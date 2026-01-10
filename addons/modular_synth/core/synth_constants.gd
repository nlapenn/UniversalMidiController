extends Node
class_name SynthConstants

# NOTE:
# These enums must match the uint32_t enums used by the synth GDExtension backend.

enum SynthBlockType {
    PolyBlepOscillator = 0,
    LFOOscillator = 1,
    SimpleEnvelope = 2,
    LPFBlock = 3,
    MoogFilterBlock = 4,
    SynthOutputBlock = 5,
    LinGainBlock = 6,
    DCOffsetBlock = 7,
    ClampBlock = 8,
    AddSignalsBlock = 9,
    MultSignalsBlock = 10,
    MaxSignalsBlock = 11,
    MinSignalsBlock = 12,
    RectifyBlock = 13,
    HalfWaveRectifyBlock = 14
}

# Modulation targets / connection targets.
enum ModulationTarget {
    Samples = 0,
    Frequency = 1,
    PulseWidth = 2,
    Amplitude = 3,
    PitchCoarse = 4,
    PitchFine = 5,
    Attack = 6,
    Release = 7,
    Resonance = 8,
    Sync = 9,
    None = 10
}

# Params (per block type)
enum PolyBlepParams { Waveform, Frequency, FreqRatio, PitchCoarse, PitchFine, PulseWidth, Amplitude, SyncAmplitude }
enum LFOParams { Frequency, Amplitude }
enum EnvelopeParams { Attack, Release, Amplitude }
enum FilterParams { Cutoff, Resonance }
enum GainParams { Gain }
enum DCOffsetParams { Amount }
enum ClampParams { MinValue, MaxValue }
