# Track loading stage analysis — 31 October 2026

An offline actual-App Star fixture on Windows spent most of its first race load in covered graphics preparation. These are wall-clock spans, not isolated GPU or driver timings. The fixture compiles the local document before the timed race and bypasses track-selection prefetch; it does not measure cloud download, ticket latency or the real selection dwell. It uses a fresh private App and road-cache directory, but OS and driver caches were not cleared. The host was shared. No Android device was measured.

Godot 4.7.2, Compatibility/OpenGL, NVIDIA RTX 3090, 1280×720, Dummy audio:

| Sequential stage | First race | Repeat |
| --- | ---: | ---: |
| Road preparation wait | 4,962.627 ms | 0.036 ms |
| Game construction through readiness | 6,710.014 ms | 2,080.692 ms |
| World graphics preparation | 33,528.489 ms | 0.061 ms |
| Effects and final covered draw | 8,916.109 ms | 420.323 ms |
| Other transitions and overhead | 123.322 ms | 55.335 ms |
| Total | 54,240.561 ms | 2,556.447 ms |

World graphics preparation submitted 34 groups on the first race and zero on repeat. Its largest individual draw wait was 3,404.519 ms. The longest measured full frame was 6,925.945 ms initially and 220.756 ms on repeat. Car setup took 1,037.320 ms within first Game construction, not in addition to it. The document compile before the race took 272.303 ms. The effects span includes the combined final draw; it is not a measurement of particles or any single effect alone. See [raw graphical timings](evidence/track-load-stage-analysis-2026-10-31/compat.json) and [log](evidence/track-load-stage-analysis-2026-10-31/compat.log).

This run makes world graphics preparation the first target for this fixture. Earlier native tracing attributed a separate long frame to driver compilation and linking, but no native driver calls were instrumented in this run. Reducing graphics variants or preparing them earlier needs paired cold and warm measurements and first-lap frame checks; simply removing the covered draws can move stalls into driving. Road preparation remains a worthwhile second target on a cache miss. Earlier preparation of checkpoint layout is a candidate, but its current contribution and safe ownership/cancellation behavior need measurement. Representative Android measurements and multiple tracks are needed before predicting a phone gain.

The diagnostic [probe](../game/tests/profile_track_load_stages.gd) inserts timestamp hooks into an in-memory App script copy. It checks its source anchors and does not edit shipping App code. The graphical run exited zero; the Windows certificate store emitted an error in this offline sandbox. A subsequent error-handling-only change makes missing anchors exit nonzero; the hook placement was unchanged. The final probe passed a headless smoke run and deliberately returned exit 1 for an invalid-anchor control. Headless timings are not substitutes for graphical timings.

Reproduce with a fresh task-specific `APPDATA` directory and empty `BMT_API_URL`, then run:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/profile_track_load_stages.gd
```

The probe writes its JSON to its isolated `user://` directory. It does not clear the owner's data or graphics-driver caches. No production optimization, device query or test, installation, deployment, owner-save change or process restart was performed.
