# Stationary selected-car crossfade (2026-10-26)

HSC01: Keep the header car stationary when selecting another car. HSC02/R01/Q01: Retain the smooth fade, exact fitting, selection/save and lifetime guards, with native evidence and a scoped checkpoint.

The owner rejects the sideways movement after selection. `game/ui/profile_car.gd` now changes opacity only: both outgoing and incoming pictures fill the same fixed icon rectangle throughout the existing 0.24-second crossfade. The eight-unit incoming offset and both horizontal position tweens are removed. Initial display, rapid-selection coalescing, clipping, anchor reset, cached pictures, native dropdown behavior and cleanup remain.

The retained transition test now requires zero position for both pictures during the blend and through repeated navigation. This strengthens the previous -6 to +8 movement envelope; the old positive incoming-position assertion is superseded by the owner's explicit no-movement request. Alpha progression, actual picture sizes, all seven cars, three window sizes, reattachment, navigation, account replacement, saving and teardown assertions remain.

Actual command used pinned Godot 4.7.2, reviewed Windows certificate-store access, unique isolated records and a disabled API connection:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/header-car-stationary-crossfade-appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:BMT_HEADER_ICON_OUTPUT = 'res://../docs/evidence/header-car-stationary-crossfade-2026-10-26/native'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
```

All **556 native Compatibility checks pass**, including thirteen capture writes. The mid-selection frame was visually inspected. Runtime scope is the selected-picture transition in `profile_car.gd`; the static studio/camera factory text, App, dropdown opening/closing motion, images and concurrent work remain untouched. The focused native run compiles the changed scripts; no broader parser or regression pass is claimed for this small revision.

Review the [stationary crossfade](evidence/header-car-stationary-crossfade-2026-10-26/native/gl_compatibility/keyboard-change-middle.png) and [Create view](evidence/header-car-stationary-crossfade-2026-10-26/native/gl_compatibility/create-electric-1411.png). Original sources, actual log, raw report, hashes and the task-only patch are under `docs/evidence/header-car-stationary-crossfade-2026-10-26/`. The patch is checked in reverse against current files and forward against exact task-start copies.

Reload and owner appearance/touch acceptance remain. No physical-device attachment check or test, APK, real authentication/purchase, live account/backend mutation, deployment, staging, commit, merge or owner-process restart was performed.
