# Header car dropdown motion (2026-10-26)

HCM01: Animate opening. HCM02: Animate closing on native dismissal or selection. HCM03: Preserve native input, saved selection, pictures, filtering and cleanup. R01/Q01: Record native views, actual checks and a scoped review patch.

The header dropdown fades in, moves down ten UI units and settles from a small inset scale over 0.22 seconds, using cubic ease out. Closing takes 0.15 seconds with a small upward movement, contraction and fade. The native menu continues to own selection and dismissal. Its last completed containing-viewport frame supplies one cropped, input-transparent exit image because the native Window releases its own rendering target when hidden. The crop accounts for viewport scaling at smaller and larger windows.

Runtime changes are the new `game/ui/header_car_motion.gd` helper and its three-line setup in `game/ui/header_car_picker.gd`. A new selection cancels the preceding exit. Hiding, removal and resizing clear animation state and temporary resources. There is no idle animation processing or additional retained viewport/world. The icon helper was restored byte-exact to its preceding checkpoint after an unsuccessful temporary buffer experiment.

The existing `game/tests/capture_profile_car.gd` review optionally captures opening, settled, closing and closed frames at 960×540, 1280×720 and 1720×900. It additionally checks rapid reopening and hiding during animation, then reruns its original selection, persistence, six pictures, active-car exclusion, Escape, Profile-name navigation, cache reuse and studio-cleanup observations. Final frames are collected in memory and written after each motion cycle so PNG compression does not distort playback timing. Earlier failed prototypes, coordinate errors and review-restoration findings remain in the evidence folders/report; no retained selection or visibility requirement was relaxed.

Actual commands used pinned Godot 4.7.2 via the repository runner, process-local `APPDATA` and `LOCALAPPDATA` at `build/header-car-motion-appdata`, and the review's disabled backend connection:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/header-car-motion-appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:BMT_HEADER_MOTION_REVIEW = '1'
$env:BMT_PROFILE_CAR_OUTPUT = 'res://../docs/evidence/header-car-motion-2026-10-26/motion-captures'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Both native reviews pass all 72 combined Boolean/count/progression/cleanup observations checked from their JSON reports. All 1,279 scripts compile. There are 18 motion stills per renderer; selected opening, settled and closing frames were visually inspected, including compact scaling. The two native key-event-to-exit-capture observations range from 24.1 to 26.0 ms across their three sizes; those include simulated input frames and are not a readback benchmark or phone performance claim. Initial sandboxed attempts failed on local log/certificate-store access; successful native and parser runs used reviewed certificate-store access with isolated test data.

Review the [opening](evidence/header-car-motion-2026-10-26/motion-captures/gl_compatibility/motion-960x540-open-start.png), [closing](evidence/header-car-motion-2026-10-26/motion-captures/gl_compatibility/motion-1280x720-close-mid.png) and [desktop Mobile closing](evidence/header-car-motion-2026-10-26/motion-captures/mobile/motion-960x540-close-mid.png) frames. Measurements, source hashes, actual logs and the task-only patch are in `docs/evidence/header-car-motion-2026-10-26/`. The patch is checked in reverse against current files and forward against exact task-start copies without staging or committing concurrent changes.

Reload and owner motion/touch acceptance remain. One containing-viewport readback occurs per close; physical-device frame pacing remains unmeasured. External, unembedded OS popup windows retain immediate native dismissal; the game's embedded popup receives both animations. No device attachment check or device test, APK, real authentication/purchase, live account/backend mutation, deployment, staging, commit or owner-process restart was performed.
