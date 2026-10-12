# Compact engine improvement — 2026-10-10

Owner request: improve the compact car sounds. The first local slice addresses
the engine's character and acceleration transitions. Owner preference and
listening acceptance remain open; no other vehicle or surface/impact sound is
changed. Requirements: **SND33** compact-specific coherent engine layers;
**SND02–SND03** authored banks/presentation-only drivetrain; **SND05–SND06**
lifecycle, headroom and provenance; **G01/R01/Q01** canonical separation and checks.

The old compact bank mixes rear recordings with a front recording at high revs.
Its strongest repeating engine order differs across playback anchors, and the
shared 1.85 pitch cap flattens the low layer before its crossfade finishes.
The six revised recordings use the existing pinned Nox CC0 rear-exterior masters,
with measured engine orders of 40/100/200 Hz at 1200/3000/6000 sound-model RPM.
Warm low/mid voicing and reduced high-frequency detail target a fuller, less harsh
engine. Coasting retains the same order with less bright detail. Compact-only
0.4–2.55 pitch bounds cover the full adjacent-anchor crossfade; other cars retain
their previous bounds. Gears, response/envelopes, audio buses, controls, physics,
timing, camera, weather, tires and collisions remain unchanged.

[Listen to the matched native before/after recordings](evidence/compact-audio-2026-10-10/audition.html).
Each 19-second engine-bus capture contains idle, acceleration through gears,
cruise, lift-off, stationary rev and pause. These use synthetic presentation
states rather than a completed race. They exclude tire, impact, weather and music
voices. The actual mixer observed at least eight loop wraps per original voice
and eleven per revised voice; no tested segment drops out. Both last half-seconds
are exactly silent. Peak changes from -8.041 to -10.229 dBFS; cruising RMS is
-20.43 versus -20.31 dBFS, so this does not simply raise overall engine volume.
Numerical results: [review.json](evidence/compact-audio-2026-10-10/review.json).

Changed files: `game/vehicle/vehicle_audio.gd`; six `compact_*_load/coast.wav`
and their lossless imports; bank `manifest.json` and `NOTICE.txt`;
`scripts/build_vehicle_audio.py`, `compact_audio_mastering.py`,
`review_compact_audio.py`; `game/tests/capture_compact_audio.gd` and its generated
UID; this document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md` and
`docs/PHASE_0_PLAN.md`; task evidence. Six revised WAVs total 1,019,856 bytes.
All other **41 WAV SHA-256 values match** the saved baseline. Existing source
licences and hashes are unchanged; shipping credits describe the edits. No new
service, download, purchase or runtime dependency is added.

Actual commands (pinned `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`):

| Command | Actual result |
| --- | --- |
| `python scripts/build_vehicle_audio.py --compact-only` | Six compact loops rebuilt; manifest updated without regenerating other clips. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Exit 0 with normal Windows certificate-store access. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_compact_audio.gd -Graphical -TestArgument '--variant=before'` | Native engine-bus recording, wraps `[10,8,8,10,8,8]`, zero failures. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_compact_audio.gd -Graphical -TestArgument '--variant=after'` | Native engine-bus recording, wraps `[11,17,19,11,17,19]`, zero failures; state snapshots unchanged by presentation. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,446 checks, zero failures**; bank hashes/format/headroom, drivetrain/lifecycle, actual contacts and exact 960-tick simulation equivalence. |
| `… dev.ps1 TestRewind` | **61 checks, zero failures**. |
| `python scripts/review_compact_audio.py` | Matched captures audible/unclipped, no measured segment dropout, silent paused tails, calibrated asset orders and six-only asset scope pass. |
| Repeat `python scripts/build_vehicle_audio.py --compact-only`, compare complete bank hashes | **47/47 WAV hashes identical** to the first revised build. |
| `git diff --check -- scripts/build_vehicle_audio.py game/vehicle/vehicle_audio.gd game/tests/capture_compact_audio.gd scripts/compact_audio_mastering.py scripts/review_compact_audio.py` | Exit 0. |
| `git apply --reverse --check --ignore-whitespace docs/evidence/compact-audio-2026-10-10/scoped-change.patch` | Exit 0; task-only text checkpoint applies in reverse to this workspace. |

The initial restricted native capture could not open the user log and exited 1;
the restricted import hit certificate-store access denial and exited 1. Both were
rerun successfully with ordinary Windows audio/certificate access. Original
failed/successful launcher logs are retained under the task evidence. The first
permitted shell also reported an execution-policy refusal for the user's shell
profile; the explicit `-NoProfile` launcher still completed its capture. Later
commands disabled shell profile loading.

No visible UI changed; playable audio is the presentation evidence. No phone
attachment check, phone/tablet listening or performance test, Android export or
install, full Validate, backend operation or deployment was performed. Remaining
acceptance: owner engine-character preference and before/after listening;
phone speaker/headphone balance; real prolonged driving across biomes, repeated
shifts, focus changes, retry and rewind. Calibrated layers and automated checks
do not establish acoustic realism or subjective sound quality.

The mixed workspace is preserved. Task-only Git-format patch and artifact hashes
live under `docs/evidence/compact-audio-2026-10-10/`; no shared-index or commit
operation is required for this review checkpoint.
