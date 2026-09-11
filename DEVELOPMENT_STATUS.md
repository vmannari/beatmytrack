# Development status

Updated: 2026-09-11. Active product gate: **P0 handling proof**. Current implementation checkpoint: **Phase 2 playable driving playground**. The overall vertical slice is not complete. Windows driving is ready for owner evaluation; physical-phone handling has not been tested.

## Completed

- Replaced the bootstrap screen with one drivable original compact car and a flat handling yard: braking lane/distance markers, two skid circles, concrete collisions and non-colliding slalom cones.
- Added isolated typed planar simulation, fixed 120 Hz quantized controls, acceleration/braking/delayed reverse, speed-sensitive steering, lateral/longitudinal grip, recoverable slip, mass/yaw inertia, countersteer assistance and throttle rotation.
- Handling parameters live in Resources. Stable/Balanced/Loose presets, F2 live tuning and F6 reload make comparisons quick. Restart restores the same initial state immediately.
- Added a high-oblique fixed-yaw camera, bounded look-ahead, render interpolation, original matte car geometry, steering wheels/brake lamps and a capped skid-trail pool. Initial framing uses baseline / 1.15; full reference calibration is pending.
- Keyboard and simultaneous touch adapters work. Focus/background loss pauses and clears inputs. Added optional speed/longitudinal/lateral/slip/input/yaw/grip/FPS/tick telemetry.
- F3 records up to two minutes of quantized controls with handling/physics metadata and periodic states, then saves a local diagnostic JSON. No backend/analytics.
- Added 46 passing driving/replay/input/lifecycle/tuning/camera checks to the validation wrapper. Exact same-engine replay passed for 2,400 ticks at four render batch sizes; Android remains untested.
- Inspected real Windows driving captures. Guide: `docs/DRIVING_PLAYGROUND.md`; evidence: `docs/evidence/driving-playground.png` and `docs/evidence/driving-tests.txt`.

- Reviewed the full blueprint package, all supplied visual references/UI screens, camera contracts, architecture, roadmap/backlog and nine-sheet financial model. The 71 manifest entries match their supplied SHA-256 hashes. Original package files are preserved unchanged.
- Documented definitive requirements, contradictions, exact repository/module structure and eight ordered tasks in `docs/PHASE_0_PLAN.md`.
- Found and pinned Godot standard `4.7.2.stable.official.ed1daf0bf`. PATH's 4.6.2 engine is deliberately rejected by the wrapper.
- Created `game/project.godot`, minimal runnable composition scene, module directories and keyboard input actions. Configured landscape, Compatibility baseline and 120 Hz physics setting.
- Added Git ignore/attributes/editor conventions, project agent instructions, asset provenance notes and developer README.
- Added `scripts/dev.ps1`: doctor, import/parse/startup validation, Windows run/editor/capture, Android debug export/install/launch/deploy. Export validates first and publishes an APK filename only after success.
- Added an arm64 Android Debug preset, SDK/template guidance and exact future device-test instructions. Android tooling setup and execution remain open.
- Captured and inspected actual Windows startup: `docs/evidence/bootstrap-windows.png`.

## Currently working

Owner feedback: turning radius was too large; requested Slicks 'n' Slide Formula-like feel. Implemented handling-0.3 with quicker steering/yaw response and stronger cornering/sliding grip across all presets. Effective quarter-turn radii at initial 43/65/86 km/h improved from 15.36/25.27/41.44 m to 7.56/10.66/15.61 m. All 46 checks pass through Validate; inspected the Windows scripted driving capture in docs/evidence/driving-formula.png. Revised feel awaits owner evaluation. No owner approval is implied by the automated results. Android toolchain remains unavailable at the configured paths.

## Next

1. Owner drives Balanced, Stable and Loose on Windows; adjust response and recovery based on a concrete maneuver and preferred preset. This is the immediate feedback request.
2. Phase 3: precise reference-camera fixture/bounds measurement and comparison at 1672×941; evaluate every heading and wider screens.
3. Phase 4/5: build the compact circuit, then directed swept checkpoints, three laps, countdown/timers/PB and race restart. No progression/store/backend.
4. Complete Android prerequisites and the actual APK/device loop, including safe areas and real simultaneous touch. Iterate phone feel before final art/content expansion.

## Unresolved decisions

- Physical target phone/model, Android version and USB availability. ADB is not installed/configured here, so no device was enumerated and attachment state is unknown.
- Actual camera projection/pitch/extent: calibrate to the supplied target, not invented camera metres. World yaw stays fixed for acceptance.
- Compatibility versus Mobile: baseline is Compatibility; final choice requires the same visual scene profiled on phone.
- Handling balance and touch layout require driving. No claim that generic drift code will satisfy the intended feel.
- Package p95 targets differ: ≤20 ms in Q01/master, ≤16.7 ms in visual acceptance. Report both, aim for the stricter visual target, and record actual traces.
- Cross-device replay equivalence remains an explicit future test gate.

Resolved override: **three laps**, per the current owner request, replaces the package's original four-lap first task. Package content remains unchanged. PB will mean best valid full race with a separate flying-lap record. Store/economy assumptions stay deferred.

## Technical debt and limitations

- No race circuit, lap/checkpoint/timer/PB systems yet. Handling yard has no lap-duration claim. No audio/haptics or final graphic-novel material/outline pipeline; default toon materials and simple geometry are stand-ins.
- Single circular car collision approximation does not match exact front/side body clearance. Cones are deliberately non-colliding. Real phone safe-insets/handedness/layout work remains.
- Diagnostic replay JSON is capped but not compact, not a trusted competition record, and not an atomic progress save. A new save replaces the diagnostic file. R/tuning/profile change discards unsaved recording; pause saves it. Cross-device float equivalence remains unproved.
- Android export preset and install/launch commands are prepared but cannot be end-to-end verified without matching templates, SDK/ADB and JDK. Minimum Android 10/arm64 is a prototype proposal, not a tested device-support claim.
- Godot import prints `Unable to open Android 'build-tools' directory.` because the configured SDK does not exist. Windows import/parse/startup still succeed; Doctor correctly fails Android readiness.
- Release signing/Play submission and production asset notices are later distribution gates. No release build or production asset is claimed.
- The isolated `.tools/review` Python environment was used only to inspect documents/images/workbook and run supplied contract examples. It is ignored and not a runtime dependency.

## Actual validation

Commands ran from `C:\Codes\Godot\Beat my track` with PowerShell `-NoProfile`:

| Command / check | Actual outcome |
|---|---|
| Godot 4.7.2 console `--version` | `4.7.2.stable.official.ed1daf0bf` |
| Package manifest SHA-256 comparison | 71 entries checked; zero mismatches |
| `.tools/review/Scripts/python.exe -X utf8 -m unittest discover -s Android_racing_game_blueprint_v2/technical/tests -v` | 24/24 pass; documentation/schema examples only |
| Initial bootstrap `scripts/dev.ps1 Capture` | Exit 0: one script, bootstrap startup and graphical capture; retained historical evidence |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Expected exit 1: matching Android template, SDK/ADB/build-tools and JDK missing |
| `Validate -GodotPath C:\apps\Godot\Godot_v4.6.2-stable_win64_console.exe` | Expected exit 1: exact engine pin mismatch |
| Temporary malformed GDScript through `Validate` | Expected exit 1: syntax error detected; probe removed afterward; evidence saved |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` after removing the probe | Exit 0: clean import, one script parsed, main-scene startup passed |
| Driving `scripts/dev.ps1 Capture` | Exit 0: import, 17 script parses, `PLAYGROUND_READY`, driving regression checks and graphical capture |
| Godot `--headless --path game --script res://tests/test_driving.gd` | Latest suite: 46 checks, zero failures; includes JSON replay/diagnostic save and scene integration |
| Godot `--path game -- --demo --capture=.../build/driving-demo.png` | Exit 0: rendered 400 physics ticks of scripted acceleration/turn, screenshot inspected; synthetic demo, not human playtest |

The Windows capture reports NVIDIA GeForce RTX 3090 / OpenGL 3.3.0. This is desktop rendering evidence, not a phone performance measurement. The braking test covered 16.35 m versus 31.53 m coasting over 1.33 s from 24 m/s. Power produced -15.5 degrees corner slip versus -6.3 degrees lifting. Same-engine JSON replay had zero final-state divergence for batches of 1/2/4/8 ticks. No APK export, ADB installation, Android launch, physical-phone test, race test or driving-feel approval was performed.

## Manual tests needed from owner

Open `game/project.godot` in Godot 4.7.2 and press F5, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
```

Use W/Up throttle, A/D or Left/Right steering, S/Down/Space brake (hold at rest to reverse), R restart. F1 toggles telemetry, F2 tuning, 1/2/3 selects Stable/Balanced/Loose. First drive Balanced at 60–80 km/h, turn toward a circle, lift and countersteer, then repeat with the other presets. Report which preset you prefer and whether response is delayed, too twitchy or difficult to recover. See `docs/DRIVING_PLAYGROUND.md` for the detailed session and recording commands; Android setup remains in `docs/ANDROID.md`.

The first subjective evaluation is immediate steering response and whether deliberate countersteering/throttle changes reliably catch a slide. After the circuit exists, record ten consecutive lap times and whether braking/line choice visibly improve them. Stop expansion and tune handling if that loop is not enjoyable.
