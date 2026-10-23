# Snowbank driving sound — 2026-10-22

SBA01–SBA03/R01/Q01 implement the owner's request for appropriate sound when driving into snowbanks. Winter now has a recorded snow-compression entry crunch and continuous ploughing texture, with stronger/faster sound as contact and speed increase. Quiet snow-ground travel uses the same texture; Winter snow wheels no longer dispatch grass, sand or scattered pebble sounds.

The presentation reads the existing snowbank height mesh at the same four wheels, centre and front/rear bumper positions as the physical resistance. This covers nose-first, reverse and sideways contact without changing simulation state, track geometry, collision resistance, rules or replay identities. The physics callback starts the entry cue before the next rendered frame. A 350 ms clear-contact debounce bridges the gap between bumper and axle contact; the continuous texture still stops immediately on leaving snow. Clear ice, paused/countdown, airborne/rolling and elevated-deck states remain quiet. Actual solid crashes retain their original impact channel.

The race retains 23 original playback nodes outside Winter. Winter lazily adds one loop (24 maximum), and its short entry uses the existing four body-event slots. The original 24 MiB prepared-stream cache and teardown/reset paths are retained. The new lossless mono clips add approximately 559 kB of source PCM; there is no runtime synthesis or remote audio dependency. No performance improvement or physical-device quality is claimed.

## Files and provenance

- `game/vehicle/surface_audio_model.gd`: snow wheel coverage, exact bank depth and bumper-aware shared-contact compatibility.
- `game/vehicle/vehicle_audio.gd`: bounded Winter loop, immediate entry, debounce, speed/depth gain and lifecycle cleanup. Concurrent bridge-landing changes already present at task start are preserved and excluded from the task patch.
- `game/assets/audio/vehicles/snow.wav`, `snow_hit.wav`, both `.import` settings, `snow_manifest.json` and the appended `NOTICE.txt` credit.
- `scripts/fetch_snow_audio.py`, `build_snow_audio.py`, `review_snow_audio.py`: scoped source acquisition, reproducible mastering and listening/capture analysis.
- `game/tests/test_snow_bank_audio.gd` and `capture_snow_bank_audio.gd`, with their UIDs.

Four original snow recordings come from [Nox Sound Design's Essentials Series](https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound). The author's CC0 statement and commercial/personal-use permission were observed on 2026-10-22; source and archive member names plus original and derivative SHA-256 values are in the new manifest. This is authored foley from recorded snow compression, not a recording of a car striking a snowbank. The six-second bed uses irregular overlapping recorded grains, band shaping, level/headroom mastering and a cyclic join; the 337 ms entry uses a separate recorded compression. No generated tones/noise are added. Existing audio masters and manifests are not rebuilt.

## Actual validation

All commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. Native Windows execution used normal OS access after the sandbox blocked network/certificate-store access. Actual logs and hashes are retained in [the evidence report](evidence/snowbank-audio-2026-10-22/report.json).

| Command / check | Actual result |
| --- | --- |
| `python scripts/fetch_snow_audio.py` | Four original CC0 snow WAVs fetched; archive identities/hashes retained in ignored build storage. |
| `python scripts/build_snow_audio.py` | Two mono 44.1 kHz/16-bit clips and manifest built; cyclic endpoint step zero. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Pass after setting both new WAV imports to lossless PCM. |
| `... -Action TestScript -ScriptPath res://tests/test_snow_bank_audio.gd -TestArgument --baseline` | Preserved original mixer reproduces missing bumper-contact snow sound for all five cars: 16 checks / 5 expected failures. Uses the final contact sampler to isolate the original mixer's missing playback. |
| `... -Action TestScript -ScriptPath res://tests/test_snow_bank_audio.gd` | 89 checks / 0 failures headless, including all five actual physical crossings with byte-exact control states, entry/re-entry, shared contacts, near passes and lifecycle gates. |
| Same focused suite with `-Graphical -RenderingMethod gl_compatibility` | 89 checks / 0 failures with native playback. |
| `... -Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical -RenderingMethod gl_compatibility` | 1,469 checks / 0 failures, including its built-in native capture assertions. |
| `test_desert_soft_sand_audio.gd`, `test_grass_kerb_audio.gd`, `test_audio_loops.gd` via `-Action TestScript` | 67 / 76 / 208 checks; all pass headless. |
| `... -Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 927 project scripts / 0 failures at the recorded parser run. |
| `... -Action TestScript -ScriptPath res://tests/capture_snow_bank_audio.gd -Graphical -RenderingMethod gl_compatibility` | 6 checks / 0 failures; actual runtime master, isolated snow and unwanted-surface buses recorded. |
| `python scripts/review_snow_audio.py` | 6 checks / 0 failures. Snow RMS 0.03385 during the bank push; unwanted surface bus exactly zero; snow silent on clear ice/after exit/during pause; master peak 0.47818. |
| Scoped `git diff --check` | Pass; existing line-ending normalization warning retained. |

Initial corrections are retained, without removing assertions: the first snow import used Godot's default compressed WAV mode and failed the existing lossless-loop guard; both import settings now use mode 0. The first physical-crossing run dispatched two entries for Pickup and Formula because their bumper/axle contact briefly cleared; the debounce fixes both, while the separate-entry rearm check remains. A combined command-line argument was initially passed as one string; the original-pause reproduction uses one dedicated flag instead.

The existing vehicle-audio suite has a separate headless pause assertion failure (1,454 checks / 1 failure): headless output deliberately never starts the loop, so `stream_paused` does not report a playing suspended stream. The preserved original mixer reproduces that assertion with `test_snow_bank_audio.gd -TestArgument --baseline-pause` (2 checks / 1 failure). The untouched full suite passes with native playback, as recorded above. No assertion or existing test was weakened.

## Review and remaining acceptance

[Listen to the native game mix](evidence/snowbank-audio-2026-10-22/driving.wav), [isolated snow](evidence/snowbank-audio-2026-10-22/snow.wav), or the [listening preview](evidence/snowbank-audio-2026-10-22/review.html). The audition supplies controlled presentation states; the focused suite separately performs actual physical crossings. Owner listening, preferred volume/texture and physical-device audio acceptance remain. A running client needs a reload to use the source/assets. No phone attachment check or device test, APK build/install, backend/account mutation or deployment was performed.

The task-only source/binary patch in the evidence directory is relative to the task-start audio sources, preserving unrelated working-tree changes. No repository commit is made from the shared dirty workspace.
