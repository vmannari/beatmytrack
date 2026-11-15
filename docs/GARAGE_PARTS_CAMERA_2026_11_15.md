# Garage Parts keeps the Appearance camera — 2026-11-15

GPC01: Parts entry, category changes and part previews use the same whole-car camera as Appearance. Previously each category selected a local direction transformed by the car's world rotation. Turning the pedestal could therefore put the camera on the opposite side of the room, facing the empty area instead of the Garage door.

GPC02: Switching between Appearance and Parts retains the editing camera and manual orbit/zoom. Leaving editing still restores the preceding Garage view. Existing sticker surface views remain available in Appearance.

GPC03: Validate six cars at three pedestal rotations, every Parts category, selected-part previews, manual tilt/zoom, Appearance/Parts round trips, compact resizing and restoration on exit. Browsing preserves isolated saved settings and makes no purchases.

Changed runtime file: `game/ui/garage_page.gd` (four camera-routing sites). Regression: `game/tests/test_garage_parts_camera.gd`, extending the existing carousel fixture helpers. The legacy carousel suite's category-specific and low Body-kit preset expectations describe the superseded behavior; that entire suite was not run or claimed passing. Its assertions were not removed or relaxed.

Actual commands:

```powershell
python scripts/run_shared_car_pictures.py headless-parts-camera res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-parts-camera res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py mobile-parts-camera res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py headless-parts-camera-selection res://tests/test_garage_selection_feedback.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Pinned Godot 4.7.2, isolated player storage and disabled backend: camera checks pass 342/0 headless and 347/0 on each desktop renderer; retained selection feedback passes 20/0. The selection fixture retains its existing raw-PNG import warnings. Desktop Mobile is a desktop Vulkan run, not a phone test.

Native Compatibility views of the same turned car: [Appearance](evidence/shared-car-pictures-2026-11-15/gl_compatibility-parts-camera/appearance-turned.png), [rear aero](evidence/shared-car-pictures-2026-11-15/gl_compatibility-parts-camera/parts-turned-aero.png), [body kit](evidence/shared-car-pictures-2026-11-15/gl_compatibility-parts-camera/parts-turned-body.png). The Garage door stays behind the car. Equivalent Mobile captures and exact commands/logs are under the matching `mobile-parts-camera` folder.

Task-only normalized source checkpoint and checked forward/reverse patch: [receipt](evidence/garage-parts-camera-2026-11-15/checkpoint.json), [patch](evidence/garage-parts-camera-2026-11-15/source.patch). Initial byte-only verification rejected Git's LF versus workspace CRLF for the new test; normalized text equality passes. The checkpoint includes the runtime change and new regression, excluding concurrent source edits. No shared-index staging or commit was performed.

Required build retention completed: 34.13 GiB remains recent/protected/locked, zero eligible entries removed; no task pin. Reload for owner review. No physical-device test or attachment query, export, backend/deployment action, owner-save modification or owner-process restart was performed. Phone appearance/input and owner acceptance remain.
