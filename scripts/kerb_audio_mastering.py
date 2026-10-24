"""Recorded cobblestone clatter with a quiet, repeating suspension thud."""

import numpy as np

REVISION = "cobblestone-thuds-8"
GENERATOR = "kerb-cobblestone-thuds-8"
DESIGN = "Recorded cobblestone clatter with subtle repeating recorded body thuds"
SOURCE = "car_cobblestone_cc0.wav"
SOURCE_CUT = (8.0, 16.0)
BODY_SOURCE = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
BODY_CUT = (.92, 1.045)
BODY_PULSE_HZ = 6.0
BODY_RELATIVE_RMS = .38


def layers(read, filter_audio, rate):
    source = read(SOURCE)
    values = source[round(SOURCE_CUT[0]*rate):round(SOURCE_CUT[1]*rate)].copy()
    if len(values) != 8*rate:
        raise ValueError("Expected the complete eight-second cobblestone excerpt")
    clatter = filter_audio(values, low=100, high=6500)

    # Retain the recorded, irregular tyre detail. Under it, a short rounded
    # body movement supplies the owner's missing thud-thud-thud. Filtering and
    # a quick decay remove the source's rattly tail; there is no generated tone.
    body = filter_audio(read(BODY_SOURCE), low=95, high=420)
    body = body[round(BODY_CUT[0]*rate):round(BODY_CUT[1]*rate)].copy()
    time = np.arange(len(body))/rate
    body *= np.minimum(time/.004, 1)*np.exp(-time/.036)
    release = round(.012*rate)
    body[-release:] *= np.linspace(1, 0, release)
    pulses = np.zeros(len(clatter))
    for number, offset in enumerate(range(0, len(pulses), round(rate/BODY_PULSE_HZ))):
        # Small level differences keep a body pulse from becoming a drum beat.
        weight = .94 + .06*np.sin(number*2.399963229728653)
        count = min(len(body), len(pulses)-offset)
        pulses[offset:offset+count] += body[:count]*weight
    pulses *= BODY_RELATIVE_RMS*np.sqrt(np.mean(clatter**2)/np.mean(pulses**2))
    return clatter, pulses


def render(read, steady, filter_audio, write, rate):
    clatter, pulses = layers(read, filter_audio, rate)
    # Match the previous cue's loudness; the pulse changes character, not gain.
    write("kerb_roll", clatter+pulses, [SOURCE, BODY_SOURCE], rms=.1417)
