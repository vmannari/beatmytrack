# Header car picture sizing correction (2026-10-26)

HIF01: Keep the selected car inside its header slot. HIF02: Preserve smooth changes through navigation, resizing and reattachment. HIF03/R01/Q01: Strengthen picture-bound checks and retain actual native views, failures and a scoped checkpoint.

The owner's Create screenshot shows the Electric picture escaping the account button and overlapping the name and page. The transition reset assigned `position = Vector2.ZERO` to a full-rectangle anchored TextureRect. That can preserve a size and anchor offsets from its previous attachment. Earlier transition checks verified the outer icon rectangle and selection but did not independently verify the child picture rectangle after reattachment.

`game/ui/profile_car.gd` now restores all anchors and offsets through `MenuStyle.fill(preview)` on completion and cancellation, and clips the icon's contents to its slot. The picture fits the existing 88×56 header rectangle, preserving aspect ratio. The 0.24-second crossfade, small slide, cached PNGs, rapid-selection coalescing, native input/save behavior and resource cleanup remain. No art, model, studio/camera factory or game behavior changes are included.

The strengthened `game/tests/test_header_car_icon_transition.gd` checks actual picture sizes and offsets independently of the outer slot. It exercises intermediate parent sizes, reattachment, ongoing and settled blends, all seven cars and repeated Create/Profile/Settings/Create visits at 960×540, the supplied screenshot's 1411×877 size, and 1720×900. Existing keyboard/mouse selection, preference reload, identity, account replacement, cleanup and viewport assertions remain. A destination environment variable keeps this task's captures separate from the preceding task's evidence.

The exact original profile source fails **two of 543 headless checks**, both new picture-rectangle assertions after reattachment. The correction passes **543 headless / 556 Compatibility / 556 desktop Mobile checks**, with **1,286 scripts** compiling. Native totals include thirteen capture writes each. Create-screen Electric captures at all three sizes show the fitted header picture; the 1411×877 captures were visually inspected in both renderers.

Concurrent App attachment guards arrived independently during this task: the current `_attach_profile_car` also clips the retained view and resets the child picture after attachment. Those edits are preserved and excluded from this patch. The standalone widget regression reproduces and verifies the picture's own reset defect separately from App. Task-start and integrated App source hashes are recorded as separate evidence. No task changes were made to App.

Actual commands used pinned Godot 4.7.2 with reviewed Windows certificate-store access, isolated local records, no configured API, and process-local `APPDATA`/`LOCALAPPDATA` at `build/header-car-icon-fit-appdata`:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/header-car-icon-fit-appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:BMT_HEADER_ICON_OUTPUT = 'res://../docs/evidence/header-car-icon-fit-2026-10-26/baseline'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -CommandTimeoutSeconds 240
$env:BMT_HEADER_ICON_OUTPUT = 'res://../docs/evidence/header-car-icon-fit-2026-10-26/headless'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -CommandTimeoutSeconds 240
$env:BMT_HEADER_ICON_OUTPUT = 'res://../docs/evidence/header-car-icon-fit-2026-10-26/native'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Review the corrected [Create view](evidence/header-car-icon-fit-2026-10-26/native/gl_compatibility/create-electric-1411.png) and [desktop Mobile view](evidence/header-car-icon-fit-2026-10-26/native/mobile/create-electric-1411.png). Raw reports, original failures, logs, source hashes and the task-only patch are in `docs/evidence/header-car-icon-fit-2026-10-26/`. The patch is checked in reverse against current sources and forward against exact task-start copies.

Reload and owner appearance/motion/touch acceptance remain. No device attachment check or physical-device test, APK, real authentication/purchase, live account/backend mutation, deployment, staging, commit, merge or owner-process restart was performed. Concurrent work is preserved.
