# Slightly shorter Garage carousel ? 2026-11-15

GCH01: reduce the responsive Garage carousel height by approximately ten percent. The viewport multiplier changes from 0.245 to 0.22, with a 116?212 px clamp instead of 128?236 px. At 1280?720 this changes the row from 176 to 158 px; at 960?540 it changes from 132 to 119 px. Width, existing footer sizing, title font rules, Selected badge, shared car-picture cache and car selection behavior keep their existing implementation.

GCH02: confirm that the visible pictures, titles and Selected badge still fit. Native actual-App review at 1280?720 and 960?540 passes the existing shared-picture/browsing regression with 69 checks and zero failures on both desktop Compatibility and desktop Mobile. There were no new tests or relaxed assertions. Raw logs and the exact commands are retained in [evidence](evidence/garage-carousel-height-2026-11-15/report.json).

- [1280?720](evidence/garage-carousel-height-2026-11-15/gl_compatibility/stock-1280.png)
- [960?540](evidence/garage-carousel-height-2026-11-15/gl_compatibility/stock-960.png)
- [Desktop Mobile](evidence/garage-carousel-height-2026-11-15/mobile/stock-1280.png)

The only runtime source change is the height calculation in `game/ui/garage_page.gd`. A task-only patch is forward/reverse checked in a private Git repository; the shared index and concurrent work are preserved. Standard build retention is applied, without a task pin. The checks use the exact pinned Godot 4.7.2 binary with isolated player storage and disabled backend settings.

Actual commands:

```powershell
python scripts/run_shared_car_pictures.py gl_compatibility-carousel-shorter res://tests/test_shared_car_pictures.gd --direct
python scripts/run_shared_car_pictures.py mobile-carousel-shorter res://tests/test_shared_car_pictures.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Reload for owner appearance review. No physical-device test or attachment query, export, backend/deployment operation, owner-save modification, owner-process restart or main-index staging was performed. Phone appearance and interaction remain unqualified; no load-time/FPS claim is made.
