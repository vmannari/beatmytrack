"""Compact-only engine voicing from the existing pinned CC0 recordings."""
import numpy as np

# Strongest repeating low engine order in the selected 3.2 s source regions.
# Match that order at every playback anchor; source filename RPM is approximate.
LAYERS = (
    ("Vehicle_Car_Engine_1000_RPM_Rear_Exterior_Loop_Mono.wav", 44.6875, 40.0, .18, 4800),
    ("Vehicle_Car_Engine_2000_RPM_Rear_Exterior_Loop_Mono.wav", 52.1875, 100.0, .38, 5200),
    ("Vehicle_Car_Engine_2000_RPM_Rear_Exterior_Loop_Mono.wav", 52.1875, 200.0, .48, 5600),
)


def seam_loop(values, rate, engine_order):
    """Align recorded waveform phase across a join, retaining continuous energy."""
    overlap = min(round(.12 * rate), len(values) // 6)
    head = values[:overlap]
    # Seek at most two firing periods near the tail. A fixed-duration fade can
    # blend opposite phases, baking a regular dip into every playback wrap.
    last = len(values) - overlap
    first = max(overlap + 1, last - round(2 * rate / engine_order))
    region = values[first:last + overlap]
    correlations = np.correlate(region, head, mode="valid")
    cumulative = np.concatenate(([0.0], np.cumsum(region**2)))
    energy = cumulative[overlap:] - cumulative[:-overlap]
    scores = correlations / np.sqrt(np.maximum(energy * np.sum(head**2), 1e-20))
    tail_start = first + int(np.argmax(scores))
    ramp = .5 - .5 * np.cos(np.linspace(0, np.pi, overlap))
    joined = values[tail_start:tail_start + overlap] * (1 - ramp) + head * ramp
    return np.concatenate((values[overlap:tail_start], joined))


def render(read, steady, filter_audio, transpose, write):
    for index, (source, recorded_order, target_order, warmth, high) in enumerate(LAYERS):
        factor = target_order / recorded_order
        # Bound source bandwidth before resampling. The rear recording supplies
        # both moving-speed layers, avoiding the old rear/front tonal switch.
        # Filter the full recording before selecting a cut. FFT filtering a cut
        # treats its unmatched ends as a periodic discontinuity and adds ringing.
        recorded = filter_audio(read(source), low=25, high=min(8500, 18000 / factor))
        voiced = filter_audio(transpose(recorded, factor), low=25, high=high, warmth=warmth)
        seconds = (3.2 if index == 0 else 6.4) / factor
        loaded = steady(voiced, seconds=seconds, start=.25 / factor)
        write(f"compact_{index}_load", loaded, [source], engine_order=target_order)
        # Preserve the same engine order on lift-off; reduce bright exhaust detail.
        coasting = filter_audio(voiced, low=25, high=2400, warmth=.12)
        write(f"compact_{index}_coast", steady(coasting, seconds=seconds, start=.25 / factor), [source], rms=.11, engine_order=target_order)
