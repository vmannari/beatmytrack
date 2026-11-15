# Car pictures survive restart and keep current saved looks - 2026-11-15

Stock car pictures already ship as assets. Customised shared profile/carousel pictures are already written as private, validated 512 x 288 PNGs beneath the records profile's `header_appearance_icons` directory. They can be restored across a normal app restart without rendering a new picture.

CPR01 fixes a retention weakness: the old fourteen-file cleanup kept only the newest versions, so many paint or kit edits to one car could evict another car's still-current picture. Each completed capture now snapshots all current saved appearance keys on the owner thread and passes those immutable strings to the file worker. Cleanup removes obsolete versions first and preserves current looks within the existing fourteen-file bound. The worker still never reads player records or UI nodes. Current source/account/renderer/paint/kit validity, PNG validation, publication and cancellation rules remain.

CPR02 verifies persistence with genuinely separate OS processes. An actual App saves a custom-painted/fitted Rally and custom-painted Kart, then exits. A headless retention fixture ages those two private files, adds eighteen newer historical versions, and compares the new policy with the former unprotected policy. A second actual App starts with empty customised-picture memory and all picture rendering disabled. It must load both files from disk, match their exact PNG and decoded pixel hashes, and share those textures with the profile button and Garage carousel.

Actual results, repeated for desktop Compatibility and desktop Mobile:

| Phase | Result per renderer |
|---|---|
| Initial actual App | 14 checks, zero failures; two captures, zero disk hits |
| Eighteen-history retention pressure | 7 checks, zero failures; fourteen files retained; both current PNGs byte-exact |
| Former-policy control | Both oldest current images evicted under the same fourteen-file bound |
| New actual App, different OS PID | 21 checks, zero failures; two disk hits, zero captures, zero picture studios; exact saved pixels |

Existing equipped-cache recovery passes 45 checks / zero failures on Compatibility, including corrupt-image regeneration, paint/kit matching, coalescing and account replacement. Production parsing passes 580 scripts / zero failures. No existing assertions were removed or relaxed.

The first restart-test fixture was rejected because it tried to serialize the unsupported `tutorial_complete` preference. The ensuing stock fallback and absent initial-menu profile produced the retained 14-check/5-failure attempt. The fixture now uses only accepted saved preferences, stops on save failure and explicitly opens the ordinary Race menu before inspecting its profile widget. The production save schema was not changed. The rejected attempt is retained under `gl_compatibility/5efd45ab38/seed`.

The only runtime implementation change is `game/ui/header_car_appearance_cache.gd`. Supporting regressions are `game/tests/test_car_picture_restart_cache.gd`, `game/tests/test_car_picture_cache_retention.gd` and `scripts/verify_car_picture_restart.py`. The orchestration uses fresh private storage and separate native engine processes, not an in-process cache reset. It checks that picture keys remain identical across the two processes and ages only validated paths inside the private fixture. No owner saves or process state are used.

The larger Garage view, five-card layout, Kart outfit, car models and picture assets were not authored by this task. Saved-look or relevant visual revision changes still require a fresh picture; corrupt or unavailable files also remain recoverable misses. This verifies normal restart persistence, not reuse across arbitrary visual builds or cleared app data. No latency or FPS percentage is claimed.

Actual commands:

```powershell
python scripts/verify_car_picture_restart.py gl_compatibility
python scripts/verify_car_picture_restart.py mobile
python scripts/run_shared_car_pictures.py gl_compatibility-restart-cache-recovery res://tests/test_header_equipped_cache.gd --direct
python scripts/run_shared_car_pictures.py headless-restart-cache-parse res://tests/check_model_refinement_parse.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The pinned Godot 4.7.2 binary is version-checked, the backend is disabled, and APPDATA/LOCALAPPDATA plus records/cache directories are private. Full subprocess commands, OS PIDs, file/pixel hashes and UI captures are in the [evidence report](evidence/car-picture-restart-cache-2026-11-15/report.json). Standard build retention was applied without a task pin. The source-only checkpoint is checked forward and backward in a private Git repository, preserving concurrent work and the shared index.

Reload to use the revised cleanup. No physical-device attachment query/test, export, backend/deployment operation, owner-save modification, owner-process restart or main-index staging was performed. Phone persistence/appearance acceptance remains.

Restarted App views: [Compatibility](evidence/car-picture-restart-cache-2026-11-15/gl_compatibility/1ab075fd58/restore/pictures-restore.png), [desktop Mobile](evidence/car-picture-restart-cache-2026-11-15/mobile/bf6576d1e0/restore/pictures-restore.png).
