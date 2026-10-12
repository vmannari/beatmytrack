# Continuous vehicle audio correction — 2026-10-06

The owner correctly reported intermittent engine fragments and suspected looping.
The loop player was repeating corrupted audio: the offline 48/96 kHz resampler
multiplied NumPy's Windows-default 32-bit sample indexes by the source sample rate.
That overflowed around one second, producing negative interpolation coordinates
and flat stretches that became silence after filtering. Original recordings are
continuous. Formula/kart inputs at 44.1 kHz skipped this faulty resampling path.

The direct reproduction used installed NumPy 1.24.2: the first wrong 48 kHz
coordinate occurred at output frame 44,740; 87,560 of a three-second test's
132,300 coordinates were wrong. This matches NumPy's documented warning about
integer-array overflow, but the diagnosis is based on the actual local reproduction
and before/after waveforms. [NumPy arange documentation](https://numpy.org/doc/stable/reference/generated/numpy.arange.html).

`scripts/build_vehicle_audio.py` now creates float64 interpolation coordinates
before multiplication, verifies monotonic advancement, and rejects looped masters
with low-energy gaps. All 40 clips were rebuilt and reimported. The bank remains
7,971,368 bytes with the same clip/frame counts and existing PCM/provenance/volume
contracts. Source recordings/licenses, virtual drivetrain and canonical simulation
are unchanged. The owner's subsequent muted-tire report also raises the dry-slip
mix coefficient from 0.38 to 0.62 (**+4.25 dB**); thresholds and contact/pause behavior
are retained. The initial clipping checks were insufficient:
audible peaks and silence after pausing did not prove uninterrupted playback.

This fulfills the owner continuity correction within SND02/SND05/SND06,
G01/R01 feedback, Q01 presentation verification and V06 derivative provenance.

## Actual checks and evidence

| Actual command | Outcome |
| --- | --- |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/vehicle-audio-continuity-2026-10-06/before-continuity.json` | Before fix: **22 interrupted loops** among 36 looped assets. Before report retained. |
| `python scripts/build_vehicle_audio.py` | All 40 clips rebuilt; no generator continuity guard failures. |
| `python scripts/test_vehicle_audio_continuity.py --captures docs/evidence/vehicle-audio-continuity-2026-10-06 --report docs/evidence/vehicle-audio-continuity-2026-10-06/after-continuity.json` | Final: **36 looped assets, 15 actual engine-bus segments, 0 failures**. Three repetitions of each asset test wrap boundaries; 20 ms windows at 10 ms intervals detect low-energy gaps. Wrap jumps also stay within the ordinary waveform-step bound. No detected dropout windows; recorded paused tails exactly silent. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio_continuity.gd -Graphical` | **48 checks, 0 failures**. Five actual twelve-second engine-bus recordings, with idle, acceleration, six seconds of sustained revs, lift-off and pause. All 30 engine voices crossed multiple observed wrap boundaries (4–10 per voice in the final run). |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,418 checks, 0 failures**; includes 960 identical canonical ticks with/without audio. |
| `… scripts/dev.ps1 TestHandling` | **88 checks, 0 failures**, including the preserved tire endpoint and historical replay invariants. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | **311 scripts, 0 failures** at this run. Concurrent work can change counts. |
| `… scripts/dev.ps1 Import` | Final exit 0 with pinned `4.7.2.stable.official.ed1daf0bf`. Initial import/audio integration encountered a concurrent `resume_credits.gd` indentation error; the other work corrected it, and these checks subsequently passed. No backend/resume file edited here. |
| `python scripts/review_vehicle_audio.py --continuous` | Five audible engine-only previews, no clipping, exactly silent paused tails; review page and levels written, including tire A/B audio. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_vehicle_tire_mix.gd -Graphical` | Two actual six-second full-mix captures of the same held slide, with former/revised tire gain. No clipped samples; exact silent tails. Sliding full-mix RMS rises from 0.08914 to 0.10228; peaks 0.3663/0.4306. Final audio regression rerun: 1,418/0. |

An intermediate wrap diagnostic incorrectly used WAV `get_loop_count()`, which
returns a placeholder zero in Godot. It failed 30 assertions; the test was corrected
to count actual playback cursor wraparounds while retaining the same playback
instance. The requirement for multiple repeats and uninterrupted rendered output
was preserved. [Godot WAV playback source](https://raw.githubusercontent.com/godotengine/godot/master/scene/resources/audio/audio_stream_wav.cpp).

[Listen to the corrected continuous engine previews](evidence/vehicle-audio-continuity-2026-10-06/audition.html).
Tires/wind/impacts are absent from these engine-bus captures so the engine tone is
easy to judge. The earlier eight-second mixes remain historical evidence of the
fault; their page links to this correction. Reports and actual logs are under
`docs/evidence/vehicle-audio-continuity-2026-10-06/`.

Changed files: `scripts/build_vehicle_audio.py`, `scripts/review_vehicle_audio.py`,
new `scripts/test_vehicle_audio_continuity.py`, `game/vehicle/vehicle_audio.gd` tire
gain, new `game/tests/capture_vehicle_tire_mix.gd`/`.uid`, new
`game/tests/test_vehicle_audio_continuity.gd`/`.uid`, regenerated
`game/assets/audio/vehicles/*.wav` and `manifest.json`, review evidence, asset/status
notes and this document. No runtime gameplay UI changes; sound recordings are the
presentation evidence. A scoped text patch and binary SHA-256 inventory retain
only this correction and preserve concurrent work; no shared-index/commit change.

No phone attachment check or phone audio test, Android export/install, full Validate,
backend deployment or canonical behavior change was performed in this correction.
Owner listening for timbre, subtle transitions and phone performance remains open;
the reported intermittent silence is reproduced and resolved by the measured tests.
