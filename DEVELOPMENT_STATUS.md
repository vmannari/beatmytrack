# Development status

Updated: 2026-09-11. Active product gate: **P0 handling proof**. Current implementation checkpoint: **Phase 0 review and Phase 1 bootstrap**. The overall vertical slice is not complete and driving feel has not been evaluated.

## Completed

- Reviewed the full blueprint package, all supplied visual references/UI screens, camera contracts, architecture, roadmap/backlog and nine-sheet financial model. The 71 manifest entries match their supplied SHA-256 hashes. Original package files are preserved unchanged.
- Documented definitive requirements, contradictions, exact repository/module structure and eight ordered tasks in `docs/PHASE_0_PLAN.md`.
- Found and pinned Godot standard `4.7.2.stable.official.ed1daf0bf`. PATH's 4.6.2 engine is deliberately rejected by the wrapper.
- Created `game/project.godot`, minimal runnable composition scene, module directories and keyboard input actions. Configured landscape, Compatibility baseline and 120 Hz physics setting.
- Added Git ignore/attributes/editor conventions, project agent instructions, asset provenance notes and developer README.
- Added `scripts/dev.ps1`: doctor, import/parse/startup validation, Windows run/editor/capture, Android debug export/install/launch/deploy. Export validates first and publishes an APK filename only after success.
- Added an arm64 Android Debug preset, SDK/template guidance and exact future device-test instructions. Android tooling setup and execution remain open.
- Captured and inspected actual Windows startup: `docs/evidence/bootstrap-windows.png`.

## Currently working

Bootstrap checkpoint is ready for the next implementation task. Android toolchain remains unavailable at the configured paths. No running handling session or subjective approval is implied by the startup screen.

## Next

1. Phase 2: flat physics playground with one original car, isolated typed planar simulation and a tunable handling Resource. Implement keyboard controls and meaningful collision/grip checks.
2. Add optional speed/longitudinal/lateral/slip/input/yaw/grip/FPS telemetry, rapid parameter variants and quantized input recording; keep persistence outside the canonical step.
3. Implement reference-camera calibration, then the compact circuit and three-lap race session in the order recorded in `docs/PHASE_0_PLAN.md`.
4. Complete Android prerequisites and actual APK/device build loop before accepting the handling gate. Iterate phone feel before art/content expansion.

## Unresolved decisions

- Physical target phone/model, Android version and USB availability. ADB is not installed/configured here, so no device was enumerated and attachment state is unknown.
- Actual camera projection/pitch/extent: calibrate to the supplied target, not invented camera metres. World yaw stays fixed for acceptance.
- Compatibility versus Mobile: baseline is Compatibility; final choice requires the same visual scene profiled on phone.
- Handling balance and touch layout require driving. No claim that generic drift code will satisfy the intended feel.
- Package p95 targets differ: ≤20 ms in Q01/master, ≤16.7 ms in visual acceptance. Report both, aim for the stricter visual target, and record actual traces.
- Cross-device replay equivalence remains an explicit future test gate.

Resolved override: **three laps**, per the current owner request, replaces the package's original four-lap first task. Package content remains unchanged. PB will mean best valid full race with a separate flying-lap record. Store/economy assumptions stay deferred.

## Technical debt and limitations

- Bootstrap only. Vehicle dynamics, car/track geometry, camera, touch controls, telemetry, timing, PB persistence, replay and cel-shading are not implemented yet. Registered keyboard actions have no driving effect yet.
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
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Capture` | Exit 0: editor import, one GDScript parse, headless `BOOTSTRAP_READY`, graphical OpenGL Compatibility run and PNG capture |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Expected exit 1: matching Android template, SDK/ADB/build-tools and JDK missing |
| `Validate -GodotPath C:\apps\Godot\Godot_v4.6.2-stable_win64_console.exe` | Expected exit 1: exact engine pin mismatch |
| Temporary malformed GDScript through `Validate` | Expected exit 1: syntax error detected; probe removed afterward; evidence saved |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` after removing the probe | Exit 0: clean import, one script parsed, main-scene startup passed |

The Windows capture reports NVIDIA GeForce RTX 3090 / OpenGL 3.3.0. This is startup evidence only, not a phone performance measurement. No APK export, ADB installation, Android launch, physical-phone test, race test or driving-feel approval was performed.

## Manual tests needed from owner

No handling evaluation is requested for the bootstrap screen. Optional Windows smoke check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
```

Expect the charcoal “CIRCUIT / 01 — Handling laboratory” screen and a message that driving comes next. Close the window normally. For Android prerequisites and the exact first driving-feel session to use after the playground is built, see `docs/ANDROID.md`.

The first subjective evaluation will be immediate steering response and whether deliberate countersteering/throttle changes reliably catch a slide. After the circuit exists, record ten consecutive lap times and whether braking/line choice visibly improve them. Stop expansion and tune handling if that loop is not enjoyable.
