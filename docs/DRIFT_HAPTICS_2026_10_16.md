# Drift haptics (2026-10-16)

DH01: add vibration during drifting. DH02: let the player enable/disable it in Settings and retain the preference. G01/R01/Q01: preserve canonical driving/replay, bounded feedback work and honest verification.

Settings > Haptics now has an independent **Drift feedback** On/Off toggle. It defaults to On, stages until Apply, survives relaunch and restores to On with Reset haptics. Reset controls preserves it. The optional Boolean `drift_haptics` uses the existing recoverable local settings save, including validation and failed-save rollback; no backend contract changes.

The live race presenter observes speed and actual slip, for buttons, analog controls, keyboard and gamepad alike. A slide must reach 10 degrees above 4 m/s and persist for 60 ms. Seven-degree exit hysteresis avoids threshold chatter. Grounded slides request 20 ms pulses at most every 100 ms, with bounded amplitude increasing from light to moderate with slip and speed. Straight driving, slow manoeuvres, airborne/rolling cars, pause/focus loss, countdown, finish, rewind/return, demo and AI driving remain silent. Restart clears the observer. These are proposed feel values pending owner/device acceptance.

The existing Android worker is shared with steering-button feedback: at most one platform request is outstanding, and additional requests are dropped while it is busy. Steering retains its original 12 ms default. No platform calls enter canonical simulation, snapshots, input recordings or race verification. Existing Android vibration permission was already enabled.

Changed runtime files:

- `game/platform/drift_haptics.gd`: bounded slide observer and pulse cadence.
- `game/platform/steering_haptics.gd`: optional bounded pulse duration on the existing platform adapter.
- `game/core/game.gd`: saved preference, presentation observer and lifecycle gates/reset.
- `game/persistence/local_records.gd`: validate the optional Boolean preference.
- `game/ui/settings_page.gd`: staged toggle, independent reset and saved preference.
- `game/tests/test_drift_haptics.gd`, `game/tests/capture_settings.gd`: focused behavior and actual touch/navigation coverage.

Actual validation used pinned Godot `4.7.2.stable.official.ed1daf0bf`, disposable APPDATA directories under `build/drift-haptics-2026-10-16`, and `scripts/dev.ps1`. No player profile was used.

| Check | Actual result |
|---|---|
| Focused headless | 45 checks, 0 failures |
| Native Compatibility Settings/navigation/captures | 299 checks, 0 failures |
| Native Mobile/Vulkan Settings/navigation/captures | 299 checks, 0 failures |
| Existing menu presentation/preferences | 41 checks, 0 failures |
| Existing driving/replay | 72 checks, 0 failures |
| Pinned editor import / native script UID generation | pass |
| Whitespace on changed existing runtime/tests | pass |

Focused coverage includes stronger/left/right slides, hysteresis, transients, low speed, four frame rates from 30 to 240 fps, delayed/invalid frame durations, 1,200 exact real simulation steps with actual drift feedback, malformed settings/failed-save retry, application-focus loss and actual race-scene lifecycle gates. A held worker accepts no extra queued work across 100 attempted submissions, then accepts fresh work after completion.

Actual commands, each with its own workspace APPDATA profile:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-focused'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_drift_haptics.gd -CommandTimeoutSeconds 150

$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-capture'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_settings.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--capture-settings=C:/Codes/Godot/Beat my track/docs/evidence/drift-haptics-2026-10-16/compatibility' -CommandTimeoutSeconds 180

$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_settings.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--capture-settings=C:/Codes/Godot/Beat my track/docs/evidence/drift-haptics-2026-10-16/mobile' -CommandTimeoutSeconds 180

$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-menu'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_presentation.gd -CommandTimeoutSeconds 120

$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-driving'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDriving -CommandTimeoutSeconds 120

$env:APPDATA = Join-Path (Get-Location) 'build/drift-haptics-2026-10-16/profile-import'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 150

git diff --check -- game/core/game.gd game/platform/steering_haptics.gd game/ui/settings_page.gd game/persistence/local_records.gd game/tests/capture_settings.gd
```

Initial direct PowerShell execution was blocked by the machine's execution policy. Process-local `-ExecutionPolicy Bypass` resolved it. Initial sandboxed engine launches could not open the default log directory/read the Windows certificate store; isolated APPDATA plus approved native execution resolved startup. Only the identified hung initial test process was stopped (PID 1496, verified parent 22652 and exact test command).

An additional `-Action TestPerformance -CommandTimeoutSeconds 120` run passed the initial 9 impact checks, then failed the optional historical tire-mark comparison `early distance rejection preserves every mark exactly`, before its haptics checks. This compares unchanged tire-mark code against `build/performance-2026-09-21/trails-before.gd`; it is outside the drift slice. The failure is retained in `evidence/drift-haptics-2026-10-16/performance-initial-failure.log`. The focused worker checks pass independently; no assertion was weakened and no broader performance pass is claimed.

Actual Haptics screenshots at 960x540, 1280x720 and 1600x720 are retained for both renderers under `evidence/drift-haptics-2026-10-16/`. The 960x540 Compatibility and 1280x720 Mobile captures were visually reviewed: the full drift row, toggle and Apply action fit. The evidence manifest records logs, hashes and the scoped Git checkpoint/patch.

Concurrent bridge presentation changes in the shared `game.gd` are preserved and excluded from the task-only patch. No canonical physics/rules, car/camera, track, input layout, backend, APK or deployment changes belong to this slice. No phone attachment check or physical-phone test was performed. Remaining acceptance is actual vibration feel and hardware support on the owner's phone; desktop renderer checks do not prove these.
