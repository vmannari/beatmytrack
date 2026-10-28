# Selected header car icon transition (2026-10-26)

HIT01: Smoothly change the selected header car picture. HIT02: Coalesce rapid selections and retain exact final identity. HIT03/R01/Q01: Preserve native selection, saving, picture bounds and ownership; record lifetime checks, native frames and a scoped checkpoint.

The selected header icon now crossfades over 0.24 seconds with a small horizontal slide and cubic ease out. The outgoing picture moves six UI units left while the incoming picture settles from eight units right. Initial attachment displays the current car immediately. Repeated refreshes for that same car do not restart the animation.

Only `game/ui/profile_car.gd` changes at runtime. It retains the current lightweight imported pictures and original picture Control, sharing the cached texture with one temporary outgoing TextureRect. Rapid selections let the current blend complete, then blend directly to the latest requested car; intermediate queued choices are discarded. Logical selection and saving happen immediately. Hiding, resizing, detaching or freeing the widget cancels the blend and releases the outgoing picture. Navigation retains the header; another records owner replaces it through the existing App behavior. There is no extra viewport, model, readback or idle processing. The offline studio factory and its camera/presentation code remain exact task-start text.

`game/tests/test_header_car_icon_transition.gd` exercises each of the seven cars, intermediate alpha/movement, exact endpoints, unchanged refresh, rapid replacement, the two-picture bound, hide/resize/detach/reattach/free and the absence of new viewports. Its actual App section selects through the native dropdown with keyboard and mouse, reloads the saved preference, checks header layout, navigates during motion and replaces the records owner. Native frames cover 960×540, 1280×720 and 1720×900. Frames are held in memory until motion completes, then saved.

Actual pinned-runner commands used process-local `APPDATA` and `LOCALAPPDATA` at `build/header-car-icon-transition-appdata`, unique local records and a disabled API connection:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/header-car-icon-transition-appdata'
$env:LOCALAPPDATA = $env:APPDATA
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Results: 51 headless checks, 61 Compatibility checks and 61 desktop Mobile checks pass; all 1,282 scripts compile. The native totals include ten successful capture writes each. Initial restricted execution reached its report but the runner rejected Windows certificate-store access; the complete successful runs used reviewed native certificate access. The existing live-studio capture script predates the concurrent lightweight-header change, so this task uses the focused actual-App review without restoring its obsolete studio assumptions.

Review the [selection start](evidence/header-car-icon-transition-2026-10-26/gl_compatibility/keyboard-change-start.png), [crossfade](evidence/header-car-icon-transition-2026-10-26/gl_compatibility/keyboard-change-middle.png), [finished icon](evidence/header-car-icon-transition-2026-10-26/gl_compatibility/keyboard-change-finished.png) and [compact desktop Mobile view](evidence/header-car-icon-transition-2026-10-26/mobile/change-960-middle.png). Raw reports, logs, hashes, exact original source and the task-only patch are under `docs/evidence/header-car-icon-transition-2026-10-26/`. The patch is checked forward against task-start files and in reverse against current files. Concurrent header assets, dropdown motion, App, Garage and other work are preserved and excluded.

Reload and owner appearance/motion/touch acceptance remain. This is desktop verification; device frame pacing is unmeasured. No device attachment check or physical-device test, APK, real authentication/purchase, live account/backend mutation, deployment, staging, commit, merge or owner-process restart was performed.
