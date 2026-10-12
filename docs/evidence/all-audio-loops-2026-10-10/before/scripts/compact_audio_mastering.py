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


def locked_loop(values, rate, engine_order, seconds=8.0):
    """Average recorded firing cycles, retaining their waveform without pitch drift."""
    frequencies = np.fft.fftfreq(len(values), 1 / rate)
    band = (frequencies > engine_order * .9) & (frequencies < engine_order * 1.1)
    analytic = np.fft.ifft(np.where(band, np.fft.fft(values) * 2, 0))
    phase = np.unwrap(np.angle(analytic)) / (2 * np.pi)
    margin = round(.12 * rate)
    phase = phase[margin:-margin]
    recorded = values[margin:-margin]
    if not np.all(np.diff(phase) > 0):
        raise ValueError("Engine firing phase must advance monotonically")
    cycles = np.arange(np.ceil(phase[0]), np.floor(phase[-1]))
    if len(cycles) < 30:
        raise ValueError("Too few recorded firing cycles to sustain")
    grid = np.arange(1024) / 1024
    aligned = np.interp((cycles[:, None] + grid).ravel(), phase, recorded).reshape(-1, 1024)
    cycle = aligned.mean(axis=0)
    count = round(seconds * rate)
    if abs(seconds * engine_order - round(seconds * engine_order)) > 1e-8:
        raise ValueError("Sustained bank must contain whole firing cycles")
    output_phase = np.arange(count, dtype=np.float64) * engine_order / rate % 1
    tonal = np.interp(output_phase, np.r_[grid, 1.0], np.r_[cycle, cycle[0]])
    # A restrained continuous air/mechanical bed retains recorded spectral
    # character. Broad frequency bins avoid carrying the source's wandering
    # narrow tones into the new sustain. Generated offline, never in the game.
    residual = recorded - np.interp(phase % 1, np.r_[grid, 1.0], np.r_[cycle, cycle[0]])
    source_hz = np.fft.rfftfreq(len(residual), 1 / rate)
    power = abs(np.fft.rfft(residual))**2
    edges = np.arange(0, rate / 2 + 100, 100)
    density = np.array([np.mean(power[(source_hz >= low) & (source_hz < high)]) for low, high in zip(edges[:-1], edges[1:])])
    output_hz = np.fft.rfftfreq(count, 1 / rate)
    shape = np.sqrt(np.interp(output_hz, (edges[:-1] + edges[1:]) / 2, density))
    shape *= 1 - np.exp(-(output_hz / 400)**4)
    rng = np.random.default_rng(10102026 + round(engine_order))
    noise = np.fft.irfft(np.fft.rfft(rng.normal(0, 1, count)) * shape, n=count)
    noise *= .16 * np.sqrt(np.mean(tonal**2)) / max(np.sqrt(np.mean(noise**2)), 1e-12)
    return tonal + noise


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
        if index > 0:
            sustained = locked_loop(loaded, 44100, target_order)
            write(f"compact_{index}_load", sustained, [source], engine_order=target_order, loop_ready=True)
            coasting = filter_audio(sustained, low=25, high=2400, warmth=.12)
            write(f"compact_{index}_coast", coasting, [source], rms=.11, engine_order=target_order, loop_ready=True)
            continue
        write(f"compact_{index}_load", loaded, [source], engine_order=target_order)
        # Preserve the same engine order on lift-off; reduce bright exhaust detail.
        coasting = filter_audio(voiced, low=25, high=2400, warmth=.12)
        write(f"compact_{index}_coast", steady(coasting, seconds=seconds, start=.25 / factor), [source], rms=.11, engine_order=target_order)
