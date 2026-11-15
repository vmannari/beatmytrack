# More vertical space for the live 3D Garage - 2026-11-15

The owner clarifies that the carousel reduction must give noticeably more space to the live 3D Garage. This supersedes the earlier small ten-percent reduction (GCH01-GCH02).

G3S01: a 96-144 px carousel replaces the previous 116-212 px range, using 16% of viewport height instead of 22%. The actual live SubViewport receives the freed height through the existing expanding preview slot. There is no change to the authored Garage, car model, handling or camera configuration.

| Native window | Carousel before / after | Live 3D viewport before / after |
|---|---|---|
| 1280 x 720 | 158 / 115 px | 380 / 423 px (+43) |
| 960 x 540 | 119 / 96 px | 243 / 269 px (+26) |

G3S02: thumbnail minimum height is 80 px, footers use 32/36 px, and titles use 20/22 px. Cached pictures reserve the footer's height so names do not cover the car picture. The existing Selected badge, shared image service, actions and selection routing remain. Initial height reservations also use the compact dimensions.

Runtime changes are confined to `game/ui/garage_page.gd`. The native capture adapter `game/tests/capture_garage_carousel_space.gd` extends the existing actual-App regression to record real preview/carousel/action rectangles and SubViewport pixels. It checks all car-title rectangles, the visible Selected badge, and separation between the live view, carousel and action row. No existing assertion was removed or relaxed.

Validation:

- Before Compatibility: 96 checks, zero failures, retaining native starting measurements.
- After Compatibility and desktop Mobile: 96 checks, zero failures each. Live-preview and carousel rectangles match between renderers. A separate comparison asserts that the measured 3D-height gain is at least the carousel-height saving at both sizes; 1280 transfers all 43 px directly.
- Existing headless selection feedback: 20 checks, zero failures; raw-image warnings in its legacy standalone picture path remain. This is not an export qualification.
- Standard build retention applied without a task pin. Exact forward/reverse task checkpoint uses a private Git repository; concurrent work and shared index are preserved.

Native views:

- [Before, 1280](evidence/garage-3d-space-2026-11-15/gl_compatibility-3d-space-before/stock-1280.png), [after, 1280](evidence/garage-3d-space-2026-11-15/gl_compatibility-3d-space-after/stock-1280.png).
- [Before, 960](evidence/garage-3d-space-2026-11-15/gl_compatibility-3d-space-before/stock-960.png), [after, 960](evidence/garage-3d-space-2026-11-15/gl_compatibility-3d-space-after/stock-960.png).
- [Desktop Mobile, 1280](evidence/garage-3d-space-2026-11-15/mobile-3d-space-after/stock-1280.png).

Actual commands:

```powershell
python scripts/run_shared_car_pictures.py gl_compatibility-3d-space-before res://tests/capture_garage_carousel_space.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-3d-space-after res://tests/capture_garage_carousel_space.gd --direct
python scripts/run_shared_car_pictures.py mobile-3d-space-after res://tests/capture_garage_carousel_space.gd --direct
python scripts/run_shared_car_pictures.py headless-3d-space-selection res://tests/test_garage_selection_feedback.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The direct wrapper verifies the exact pinned Godot 4.7.2 binary and uses private APPDATA/LOCALAPPDATA with the backend disabled, avoiding a shared build-identity rewrite for this layout task. Full commands, logs, native images, before/after comparison, task-start source and checkpoint receipt are in [the evidence report](evidence/garage-3d-space-2026-11-15/report.json).

Reload for owner appearance review. No physical-device test or attachment query, export, backend/deployment operation, owner-save modification, owner-process restart or main-index staging was performed. Phone appearance and input remain unqualified; no FPS or latency gain is claimed.
