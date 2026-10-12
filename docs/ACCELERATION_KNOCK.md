# Acceleration body-cue correction, 2026-10-10

Requirements: **SND38** (remove the faint added knock during smooth acceleration),
SND02-SND06 (retain engine, surface and physical-contact sound), G01/R01/Q01
(presentation-only change, lifecycle and measured verification).

`VehicleAudio.present()` played `chassis.wav` at gain 0.12/pitch 1.32 on every
virtual gear change. This recording is body-movement foley, so the first upshift
adds a separate thud during otherwise smooth acceleration. The compact first
upshift is just above 12.696 m/s; this does not explain a knock occurring while
stationary immediately at pedal onset.

The runtime now retains the body cue only for downshifts. The virtual drivetrain,
RPM drop, 120 ms shift cut and engine blending remain unchanged. Collision,
kerb and landing paths are untouched. No audio asset or native adapter changes.
All **47 vehicle WAV files** match their starting SHA-256 hashes.

[Before/after listening comparison](evidence/acceleration-knock-2026-10-10/audition.html)
and [numerical/event review](evidence/acceleration-knock-2026-10-10/review.json).
The four native recordings start throttle at 1 second, ramp smoothly to 24 m/s
at 7 seconds where applicable, and pause at 8 seconds. The old compact emits
two chassis events at approximately **4.175 and 6.292 seconds**; the corrected
acceleration emits **zero**. Both stationary-throttle cases emit zero body cues.
All recordings exceed 8.5 seconds, have zero clipped samples and a digitally
silent final half-second. These are synthetic presentation states rather than
a physical race or microphone capture. The diagnostic selects the existing
Godot body fallback because the native Windows body adapter bypasses the
Godot recorder; shipping routing remains unchanged.

The deterministic comparison covers compact, pickup, classic, Formula and kart,
stationary throttle and smooth acceleration, with positive downshift controls.
It verifies unchanged canonical snapshots and that geared cars still shift and
apply their engine shift cut. The direct-hit integration test separately verifies
that actual physical impact deceleration retains the accompanying chassis cue.

Changed files: `game/vehicle/vehicle_audio.gd`;
new `game/tests/test_acceleration_knock.gd`;
new `scripts/review_acceleration_knock.py`; this document,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and task evidence.
The shared dirty index is preserved. A task-only Git-format source patch and
SHA-256 inventory provide the review checkpoint.

Actual commands, pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

| Command | Actual outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_acceleration_knock.gd -TestArgument '--baseline'` | Initial trace reproduces compact four upshift thuds and no stationary cues; process stalled at shutdown and was stopped, so not accepted as a completed test. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_acceleration_knock.gd -Graphical` | Final **1,646 checks, zero failures**, exit 0, four native captures. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_direct_hit_body_audio.gd` | **5 checks, zero failures**, exit 0; actual impact and following downshift cue retained. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,446 checks, zero failures**, exit 0; exact simulation separation and race/retry lifecycle. |
| `python scripts/review_acceleration_knock.py` | Event, source hash, native duration, clipping and pause checks pass. |

Logs are copied into the evidence directory. The initial fixture accumulated
many synthetic audio updates without yielding and stalled; only its two owned
processes were stopped after checking their command lines. The final fixture
uses bounded 100 ms deterministic steps and yields between banks; native captures
use actual frame deltas. An initial duplicate compact alias was corrected to
`classic`; the final comparison uses all five actual car IDs. The first review
attempt used the wrong hash-ledger path prefix; corrected without replacing any
original hashes or weakening the asset assertion.

No visible UI changed. No phone attachment check, device listening test, Android
export/install, full Validate, backend operation or deployment was performed.
Restart the local game to load the correction; installed Android builds remain
unchanged. Remaining acceptance: owner listening on the actual affected client,
and determining whether the reported faint knock corresponds to this first
upshift or happens immediately at stationary throttle onset. These captures
establish removal of the added upshift body cue, not identification of every
audible artefact on the owner's device.
