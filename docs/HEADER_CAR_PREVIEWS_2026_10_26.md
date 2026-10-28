# Header dropdown car previews (2026-10-26)

HCP01: Show car pictures in the same presentation as the header car. HCP02: Exclude the active car, leaving six alternatives. HCP03: Retain car selection, saving, dismissal and the separate profile-name action. R01/Q01: Record native review and a scoped source checkpoint.

The dropdown now shows an 88×56 car preview beside each existing car label. It uses the header's existing `profile_car.gd` factory, with the same camera, lighting, model detail and each car's saved paint and fitted parts. The active vehicle is omitted when the list is built, including after changing cars. Native item IDs continue to map to catalogue IDs, so filtering does not shift the selected vehicle.

`game/ui/header_car_icons.gd` renders one temporary studio at a time, captures a 176×112 icon and releases the studio. A bounded fourteen-image cache reuses matching appearance/renderer pictures on reopening. Closing or hiding the dropdown cancels outstanding work. No image files, models or shared rendering sources are changed.

Runtime changes are `game/ui/header_car_picker.gd`, the new icon helper and one records binding in `game/core/app.gd`. Concurrent App race profiling and draft recovery edits are preserved and excluded from the task patch. The existing capture script now records six visible previews, the active car's absence before and after selection, keyboard/mouse selection and saved preference reload, Escape, name navigation, cache reuse and studio cleanup. Its previous seven-choice/checked-active expectations are superseded by the owner's request.

Commands use pinned Godot 4.7.2 through `scripts/dev.ps1`, with process-local `APPDATA` and `LOCALAPPDATA` set to `build/header-car-preview-appdata`. Captures set `BMT_PROFILE_CAR_OUTPUT=res://../docs/evidence/header-car-preview-2026-10-26`. Native execution uses reviewed Windows certificate-store access.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
```

Both renderer reports contain six nonempty thumbnails, visible label pixels, successful active-car filtering before/after selection, passing selection/save/name actions, cache reuse, a peak of one temporary icon studio and zero remaining icon studios after generation/closure. The initial full-frame Mobile preview was mistakenly read as missing its labels. A native crop and pixel inspection show they were already visible: the original and final Mobile screenshots are byte-identical, with 242 bright label pixels in the inspected PNG region. No label-rendering defect was reproduced; the diagnostic additionally checks label pixels. The original capture remains under `initial-review/` with its initially assigned filename. Icon binding is deferred outside the renderer callback, with the same generation/visibility guards. These are desktop native observations, not a phone performance benchmark. The prior task's broader App results are historical and are not represented as newly passed here. Actual results, source hashes and logs are in `evidence/header-car-preview-2026-10-26/report.json`.

Review the [dropdown](evidence/header-car-preview-2026-10-26/gl_compatibility/car-dropdown.png) and [profile opened from the name](evidence/header-car-preview-2026-10-26/gl_compatibility/profile-opened-from-name.png). `task-only.patch` is checked forward against exact task-start sources and in reverse against current sources; unrelated concurrent App edits are omitted.

Reload and owner/device appearance and input acceptance remain. No device attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart was performed.
