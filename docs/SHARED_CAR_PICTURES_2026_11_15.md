# Shared Garage and profile car pictures ? 2026-11-15

The Garage carousel and profile button now display the same cached texture object. Six native stock pictures are 512 ? 288, and customised paint/parts use one capture at that resolution. The profile button scales the same image down. The production Garage and its preloader no longer render separate carousel pictures or import the former stock picture sets. The live Garage remains interactive and retains saved dirt; the shared menu image shows the clean finish.

The owner then reported slow updates after changing paint or parts. The former permission rule required leaving the workshop and 750 ms of deliberate-input quiet. Saved appearances now refresh in the current Appearance/Parts section after 100 ms without active gestures. The cache coalesces saves for 120 ms and retries eligibility every 100 ms. Menu motion, foreground, memory pressure, account/navigation fences and active touches remain guarded. Capture uses a separate small world and never covers or replaces the live Garage.

Requirements and changed files:

- SCP01: one texture object for stock and customised profile/carousel pictures. `garage_shared_pictures.gd`, `garage_cached_thumbnail.gd`, `garage_page.gd`, `garage_preloader.gd`, `core/features/garage.gd`.
- SCP02: carousel resolution, versioned private keys, bounded validated PNG reads, and matching future offline bake sizes. `header_car_icons.gd`, `header_car_appearance_cache.gd`, nine header-producing bake scripts, and six `assets/menu/header_cars_v1/*.png` files. Dormant non-catalogue car images are unchanged.
- SCP03: retain the live car, paint/parts, saved condition and selection behavior; avoid separate Garage picture captures. The legacy standalone preview service remains for its existing tools/fixtures.
- SCP04: native views, actual-App pointer/capture/disk checks, cache correctness and production parsing. `test_shared_car_pictures.gd`, `run_shared_car_pictures.py` and this evidence directory.
- SCP05: paint and parts refresh without leaving the workshop, active-gesture exclusion, no cover and no live-world replacement. `core/app.gd`, the cache/preloader rules above, and `test_shared_car_picture_refresh.gd`.

Actual validation:

| Check | Result |
|---|---|
| Shared actual App, headless | 34 checks, 0 failures |
| Shared actual App, desktop Compatibility / Mobile | 69 checks, 0 failures each; six stock loads; one custom capture; one disk hit; zero separate Garage picture renders |
| Workshop refresh, desktop Compatibility / Mobile | 21 checks, 0 failures each on the instrumented runs; two captures for two committed looks; zero cover frames |
| Equipped cache correctness | 45 checks, 0 failures each desktop renderer; corruption recovery, paint/parts parity, coalescing, disk reuse and account fences |
| Selection feedback, headless | 20 checks, 0 failures |
| Production parser | 580 scripts, 0 failures |
| Native image imports | 9 existing image source MD5s verified, including the six regenerated catalogue images |

The first Compatibility refresh run retained a 2,750.167 ms kit update and failed its unchanged two-second desktop gate (paint 332.434 ms). The instrumented repeat measured paint 357.721 ms / kit 242.015 ms; desktop Mobile measured paint 439.466 ms / kit 1,732.042 ms. These are local samples, with first-use variability, not a guaranteed two-second bound, phone latency, FPS or whole-app improvement. Neither test assertions nor the failed result were removed. Known two-object/one-resource shutdown diagnostics appear in some initial runs and the instrumented Compatibility run; later clean exits do not erase them.

The broader `test_script_parse.gd` invocation fails at `tests/test_menu_quality.gd:171`: its historical five-argument `_start_race` override does not match App's six-argument signature. The exact six-argument parent signature is already present in the task-start App snapshot. This unrelated fixture was not edited; the full test-script parser is unqualified. The historical `test_garage_paint_flash.gd` assertion forbidding every Garage picture capture describes the former deferral policy and is superseded for saved Appearance/Parts refreshes. Its no-cover/live-world requirements are explicitly checked by the new regression.

Native views:

- [Stock, 1280](evidence/shared-car-pictures-2026-11-15/gl_compatibility-final/stock-1280.png), [stock, 960](evidence/shared-car-pictures-2026-11-15/gl_compatibility-final/stock-960.png), [custom paint and parts](evidence/shared-car-pictures-2026-11-15/gl_compatibility-final/custom-1280.png).
- [Paint updated inside Appearance](evidence/shared-car-pictures-2026-11-15/gl_compatibility-refresh-profile/paint-refreshed-in-appearance.png), [parts updated inside Parts](evidence/shared-car-pictures-2026-11-15/gl_compatibility-refresh-profile/kit-refreshed-in-parts.png).
- [Mobile paint](evidence/shared-car-pictures-2026-11-15/mobile-refresh/paint-refreshed-in-appearance.png), [Mobile parts](evidence/shared-car-pictures-2026-11-15/mobile-refresh/kit-refreshed-in-parts.png).

Reproduction uses the pinned Godot 4.7.2 through `scripts/dev.ps1` for the stock bake and initial parser invocation; the recorded `--direct` checks use that exact verified binary, private APPDATA/LOCALAPPDATA and disabled backend configuration to avoid repeatedly rewriting shared build identity. Every command and exit code is in the corresponding evidence subdirectory's `command.json`; raw logs, reports and task-start sources are retained. The initial pinned invocation applied standard build retention; no task pin was added. Later generated build identity is recorded separately from the task checkpoint. No vehicle geometry or handling source was authored.

Examples actually run:

```powershell
python scripts/run_shared_car_pictures.py gl_compatibility-bake res://tests/bake_header_car_thumbnails.gd
python scripts/run_shared_car_pictures.py gl_compatibility-final res://tests/test_shared_car_pictures.gd --direct
python scripts/run_shared_car_pictures.py mobile-final res://tests/test_shared_car_pictures.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-refresh-profile res://tests/test_shared_car_picture_refresh.gd --direct
python scripts/run_shared_car_pictures.py mobile-refresh res://tests/test_shared_car_picture_refresh.gd --direct
python scripts/run_shared_car_pictures.py headless-production-final res://tests/check_model_refinement_parse.gd --direct
```

The task patch is produced and checked in a private Git repository, without staging the shared workspace. Concurrent documentation is preserved from a fresh pre-insertion snapshot; concurrent work and the main index are retained. See [report](evidence/shared-car-pictures-2026-11-15/report.json) and [checkpoint receipt](evidence/shared-car-pictures-2026-11-15/checkpoint.json) for exact files, hashes and forward/reverse checks.

Reload the game for owner appearance and interaction review. No physical device test or attachment query, export, backend/deployment operation, owner-save modification or owner-process restart was performed. Phone performance and visual acceptance remain outstanding.
