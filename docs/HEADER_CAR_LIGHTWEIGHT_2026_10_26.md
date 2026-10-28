# Lightweight header car pictures (2026-10-26)

HCL01: Remove runtime 3D rendering from the header and car dropdown. HCL02: Preserve six alternatives, active-car exclusion, selection/save and the profile-name action. HCL03: Preserve motion without a GPU screenshot. HCL04/R01/Q01: Verify bounded resources, native presentation and existing navigation, with a scoped checkpoint.

The header and dropdown now share seven imported 176×112 PNGs, baked offline from the existing profile studio. They total **93,780 bytes** of PNG data. All seven RGBA textures with their complete mip chains have a **735,700-byte payload** (about 0.70 MiB), excluding engine/driver overhead. A seven-entry texture cache replaces the previous model-building queue, live header viewport, offscreen studios, readbacks and per-appearance raster cache.

The pictures use standard car appearances. Saved custom paint, stickers and fitted parts remain in Garage/gameplay, but no longer regenerate these tiny menu pictures. The existing profile studio factories remain available for Garage paint icons and the offline bake. The concurrent 0.24-second selected-car blend is preserved in the shared profile component.

The dropdown's opening animation remains. Closing now recreates only its small 2D panel, labels and shared textures for the existing fade; it no longer reads back the full containing viewport. Header selection also avoids replacing the model in a hidden retained Garage; the existing Garage-entry refresh resolves the selection when that page is shown. Visible Garage selection still updates normally.

Runtime files: `game/ui/profile_car.gd`, `header_car_icons.gd`, `header_car_picker.gd`, `header_car_motion.gd`, and one visibility guard in `game/core/app.gd`. The shared profile file integrates the concurrent selected-picture animation; its final integrated source is included in the scoped checkpoint with that dependency acknowledged. Other concurrent App changes are excluded. Original model/configuration/physics sources are untouched.

`game/tests/bake_header_car_thumbnails.gd` creates the seven original-game-asset derivatives, preserving the camera/light presentation and transparent edges. `game/tests/capture_profile_car.gd` verifies all pictures, zero 3D nodes/SubViewports in the header, cached reuse, six alternatives, actual keyboard/mouse selection and saving, profile navigation, long names and opening/closing/interruption cleanup across three windows. It waits for the concurrent picture blend to settle; an initial in-flight fixture failure remains in `initial-review/`. Standard pictures replace the old dynamic-cosmetics assertions explicitly; saved cosmetic data is still checked unchanged.

Actual commands used pinned Godot 4.7.2 through the runner, with disposable `APPDATA`/`LOCALAPPDATA` under `build/header-car-lightweight-appdata`. Native captures set `BMT_PROFILE_CAR_OUTPUT=res://../docs/evidence/header-car-lightweight-2026-10-26` and `BMT_HEADER_MOTION_REVIEW=1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_header_car_thumbnails.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_responsiveness.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

The full editor import could not copy an already-locked native geometry DLL. Only the seven new PNGs were then imported successfully in `build/header-car-texture-import`, a minimal temporary project with matching resource paths and mipmap settings, using the exact pinned executable with `--headless --editor --import`. The resulting import descriptors and byte-exact compiled texture caches were copied to their matching project paths. No extension configuration or owner process was changed. The isolated UID helper emitted a nonfatal certificate-store diagnostic while creating the new bake script's UID; native app validation uses reviewed certificate-store access.

Both desktop renderer reports show zero header 3D nodes and zero header SubViewports, seven shared pictures, successful filtering/selection/save/name navigation and motion cleanup. Cached population timings are recorded as a hundred list rebuilds, separate from frame waits/screenshots; they are not phone FPS or thermal measurements. Existing App **141** and menu responsiveness **26** checks pass. Final parser output, hashes and the scoped source/binary patch checks are recorded in `evidence/header-car-lightweight-2026-10-26/report.json`.

Review [the lightweight dropdown](evidence/header-car-lightweight-2026-10-26/mobile/car-dropdown.png) and the per-renderer motion frames. Reload is required. Owner/device feel and performance acceptance remain; no attachment/device test, APK, real authentication/purchase, live mutation, deployment, staging, commit, merge or owner-process restart was performed.
