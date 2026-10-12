"""Compact-only engine voicing from the existing pinned CC0 recordings."""

# Strongest repeating low engine order in the selected 3.2 s source regions.
# Match that order at every playback anchor; source filename RPM is approximate.
LAYERS = (
    ("Vehicle_Car_Engine_1000_RPM_Rear_Exterior_Loop_Mono.wav", 44.6875, 40.0, .18, 4800),
    ("Vehicle_Car_Engine_2000_RPM_Rear_Exterior_Loop_Mono.wav", 52.1875, 100.0, .38, 5200),
    ("Vehicle_Car_Engine_2000_RPM_Rear_Exterior_Loop_Mono.wav", 52.1875, 200.0, .48, 5600),
)


def render(read, steady, filter_audio, transpose, write):
    for index, (source, recorded_order, target_order, warmth, high) in enumerate(LAYERS):
        factor = target_order / recorded_order
        # Bound source bandwidth before resampling. The rear recording supplies
        # both moving-speed layers, avoiding the old rear/front tonal switch.
        recorded = filter_audio(steady(read(source)), low=25, high=min(8500, 18000 / factor))
        voiced = filter_audio(transpose(recorded, factor), low=25, high=high, warmth=warmth)
        write(f"compact_{index}_load", voiced, [source])
        # Preserve the same engine order on lift-off; reduce bright exhaust detail.
        write(f"compact_{index}_coast", filter_audio(voiced, low=25, high=2400, warmth=.12), [source], rms=.11)
