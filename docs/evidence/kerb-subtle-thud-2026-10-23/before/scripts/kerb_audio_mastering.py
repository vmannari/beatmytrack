"""Recorded compact-car cobblestone clatter for the owner's kerb reference."""

REVISION = "cobblestone-recorded-7"
GENERATOR = "kerb-cobblestone-7"
DESIGN = "Recorded compact-car tyre/body clatter on cobblestones; natural uneven contacts"
SOURCE = "car_cobblestone_cc0.wav"
SOURCE_CUT = (8.0, 16.0)


def render(read, steady, filter_audio, write, rate):
    source = read(SOURCE)
    values = source[round(SOURCE_CUT[0]*rate):round(SOURCE_CUT[1]*rate)].copy()
    if len(values) != 8*rate:
        raise ValueError("Expected the complete eight-second cobblestone excerpt")
    # Keep the real, uneven contacts and body vibration. Remove sub-bass cabin
    # energy so tyre detail survives small speakers; never level the envelope
    # or impose synthetic tones, a fixed beat, or an added noise bed.
    # Fixed master gain is calibrated near the previous cue's -18.5 LUFS.
    write("kerb_roll",filter_audio(values,low=100,high=6500),[SOURCE],rms=.144)
