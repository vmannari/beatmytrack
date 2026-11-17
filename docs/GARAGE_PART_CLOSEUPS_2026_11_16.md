# Garage part close-ups with a rotating car

The owner requests close-ups of customised parts while keeping the Garage camera pointed towards the door. This supersedes GPC01–GPC03's whole-car Parts view.

GPC04 restores the existing per-car hood, rear-aero, rim and body-kit framing. The camera controller aligns the desired local viewing direction with the Appearance camera's horizontal heading by rotating the turntable through the shortest angle. The selected region's target uses the resulting car transform. Body-kit fitting also uses that transform.

GPC05 animates the car rotation alongside the existing camera transition. Category changes replace the active transition using the current poses. Dragging cancels the automatic turn through the existing orbit handler. Resizing retains the destination rotation and refits the selected region. Leaving editing restores the captured camera, turntable angle, tilt and zoom.

GPC06 revises the camera regression to exercise six cars at three starting turntable angles, all four categories, selected-part previews, manual rotation/zoom, Appearance/Parts round trips, resizing, rapid category changes and exit restoration. Each animated frame is checked against the Appearance horizontal heading. The final headless sweep additionally checks resize during a turn, drag cancellation and leaving during a turn.

Changed files are `game/ui/garage_page.gd`, `game/ui/garage_customisation_camera.gd` and `game/tests/test_garage_parts_camera.gd`. The existing per-car targets, distances and elevations supply the close-ups. The regression's previous whole-car expectations are updated for the owner's explicit change in behaviour.

Actual commands use the pinned Godot 4.7.2 engine with isolated player storage and a disabled backend.

```powershell
python scripts/run_shared_car_pictures.py headless-part-closeups res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-part-closeups res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py mobile-part-closeups res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py headless-part-closeups-final res://tests/test_garage_parts_camera.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-part-closeups-app res://tests/capture_garage_configurator.gd --direct
python scripts/run_shared_car_pictures.py headless-part-closeups-selection res://tests/test_garage_selection_feedback.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The first headless sweep passes 577 checks. Compatibility and desktop Mobile each pass 607 checks, including 30 native captures. The final headless sweep passes 581 checks with the additional interruption cases. The existing full-App configurator review passes 14 checks at 960, 1280 and 1720 widths. Selection feedback passes 20 checks. All runs have zero failures. Exact command receipts are recorded in the evidence report.

Native views show the door behind the focused car for rear aero and rims. Forklift uses its engine-cover region and turns its rear towards the camera. Full-App captures qualify the normal Garage entry and preview path. [Rear aero](evidence/shared-car-pictures-2026-11-15/gl_compatibility-part-closeups/compact-parts-aero.png), [rim](evidence/shared-car-pictures-2026-11-15/gl_compatibility-part-closeups/compact-parts-rims.png), [Forklift engine cover](evidence/shared-car-pictures-2026-11-15/gl_compatibility-part-closeups/forklift-parts-hood.png), [full App](evidence/shared-car-pictures-2026-11-15/gl_compatibility-part-closeups-app/hood-preview-1280.png).

The task-only three-file private Git checkpoint passes byte-exact forward and reverse patch checks. Concurrent workspace edits and the shared index are preserved. Standard build retention completes with 23.83 GiB remaining in recent, protected or locked entries. Zero eligible entries are removed. The task adds no retention pin. [Checkpoint receipt](evidence/garage-part-closeups-2026-11-16/checkpoint.json), [source patch](evidence/garage-part-closeups-2026-11-16/source.patch).

Reload for owner appearance review. Physical-device testing was not performed. Phone appearance and input acceptance remain. [Evidence report](evidence/garage-part-closeups-2026-11-16/report.json).
