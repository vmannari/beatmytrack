# More distinctive go-kart kits, 2026-10-29

The kart now has eight choices in each Parts category: Original plus seven alternatives, for 32 choices and 4,096 possible combinations. Sixteen alternatives are new. Existing saved IDs remain valid, with the earlier nose, side-pod and open-spoke designs revised to have stronger shapes.

| Requirement | Category | Added choices |
| --- | --- | --- |
| KVD01 | Nose | Arrow nose, Channel nose, Shield nose, Rounded nose |
| KVD01 | Rear bumper | Oval bumper, Cross brace bumper, Slotted bumper, Chevron bumper |
| KVD01 | Rims | Turbine wheel, Cross mesh wheel, Deep dish wheel, Five point wheel |
| KVD01 | Side pods | Blade pods, Channel pods, Rounded pods, Box pods |
| KVD02 | Distinctive construction | Explicit panel profiles, recessed channels, rounded/squared/sharp sections, solid bevelled spokes, crossed spokes, deep bowls and different alloy finishes |
| KVD03 / Q01 | Fit and visual review | Actual-mesh depth comparisons, steering-sweep clearance, both detail levels and both desktop renderers |
| KVD04 / R01 | Integration | Existing save/reset/preview/equip/ownership/race/ghost flow, historical IDs, native assets and translations |

The earlier Sprint, Endurance and Wedge noses/pods now use separate authored station profiles. The new sections create a pointed spine, recessed channel, flat shield or rounded capsule. Three spoke and Split six wheels use closed forged solids; other wheels expose a fan, crossed bronze spokes, deep bowl or five-point star. Bumpers have visibly different frames, heights, openings and centre panels. All geometry is original native project code; no downloaded model, generated image or runtime API is used.

Original geometry, tyre meshes, wheel positions, driver, engine and canonical handling are preserved. Current cosmetic save keys and schema remain unchanged. Existing kit item IDs keep the existing 750-coin price convention; the backend catalogue adds exactly sixteen entries. Non-kart catalogue fields remain byte-value equivalent. Changed panel/inlay/hardware keys carry a new visual revision, so old baked meshes cannot alias the new geometry. All 484 prior native mesh files remain SHA256-exact; 422 new immutable meshes were added, for 906 manifest entries. All six prepared Garage templates were refreshed.

## Actual results

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, desktop RTX 3090. Runs use project-local `APPDATA` and `LOCALAPPDATA` below `build/kart-variety/local`, disposable records and an empty `BMT_API_URL`.

| Check | Result |
| --- | --- |
| Actual Garage workflow, Compatibility | 984 checks / 0 failures, 38 screenshots |
| Same workflow, desktop Mobile/Vulkan | 984 checks / 0 failures, 38 screenshots |
| Geometry-only kit regression | 774 checks / 0 failures |
| New shape/fit regression | 336 checks / 0 failures |
| Frozen original stock comparison | 4 checks / 0 failures, exact mesh arrays and transforms |
| Retained kart model | 62 checks / 0 failures; stock 87,136 full / 30,292 simple triangles |
| Retained kart construction | 32 checks / 0 failures |
| Actual-App saved appearance recovery | 70 checks / 0 failures, six cars, disk reload and read-only fake-server recovery |
| Preferred new shape-script dependency check | Passed |
| Backend appearance/economy tests, SQLite | 75 passed, 1 skipped, 1 retained sticker-catalogue failure, 36 deselected |
| Scoped Ruff | Passed |
| New translated copy | 32 messages / 384 nonempty translations across 12 languages |
| Review checkpoint | 26 source files; live reverse check, isolated forward application/content comparison and isolated reverse check passed |

The shape regression samples actual mesh intersections on a 32×20 grid for each category at both detail levels. A pair differs when coverage differs or its depth differs by more than 4 mm. Every pair differs in at least 21.667% of occupied samples, exceeding the fixed 8% test requirement. This measures coverage and depth in the selected views; it is not a claim about every viewing angle. Non-rim kit vertices clear the original tyre cylinder through five front steering angles from −0.60 to +0.60 radians, with a minimum measured gap of 25.921 mm. Rims retain their intended tyre-bead contact.

The workflow exercises all choices through actual touch input, including scrolling, preview/equip, local save/reload, failed-save rollback, cancelled locked purchase, reset, Compact/kart switching and ordinary race/ghost construction. Sampled models remain below the unchanged 120,000-triangle ceiling; the maximum observed is 93,536. All 4,096 combinations were not rendered or device-profiled.

Native examples: [Arrow nose](evidence/kart-variety-2026-10-29/compatibility/hood-arrow.png), [channel nose](evidence/kart-variety-2026-10-29/compatibility/hood-split.png), [turbine wheel](evidence/kart-variety-2026-10-29/compatibility/rims-turbine.png), [cross brace bumper](evidence/kart-variety-2026-10-29/compatibility/aero-cage.png), [rounded pods](evidence/kart-variety-2026-10-29/compatibility/body-rounded.png). Each renderer's folder contains all 28 alternatives, three viewport sizes, category views, Original and Finnish/German views.

## Commands run

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/kart-variety/local/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/kart-variety/local/localappdata'
$env:BMT_API_URL = ''
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -TestArgument '--geometry-only' -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kit_variety.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_kart_kits.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/kart-variety-2026-10-29/compatibility' -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/kart-variety-2026-10-29/mobile' -CommandTimeoutSeconds 600
# Retained tests ran sequentially through the same entry point:
# test_kart_kit_stock_control.gd, test_kart_model.gd,
# test_kart_construction.gd, test_garage_appearance_recovery.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://vehicle/kart_kit_shapes.gd -CommandTimeoutSeconds 180
$env:PYTHONPATH = Join-Path (Get-Location) 'backend'
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_kart_kits.py backend/tests/test_earned_coins.py backend/tests/test_rivalry_appearance.py backend/tests/test_appearance_sync.py -q -k 'not postgres' --basetemp=build/kart-variety/pytest
& .tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/tests/test_kart_kits.py backend/tests/test_earned_coins.py
git apply --reverse --check docs/evidence/kart-variety-2026-10-29/source-only.patch
```

The first sandboxed engine attempt failed to read the Windows certificate store; isolated host-access runs passed. The backend suite retains the existing twelve extra sticker IDs in `test_catalog_matches_native_assets`; those fields match the task-start catalogue and were not changed. The SQLite concurrency skip remains intentional; PostgreSQL was not tested. No full-project parser/localization-completeness pass is claimed. Concurrent sticker, editor, car, Garage and generated identity changes are preserved and excluded from the checkpoint. Source hashes, asset hashes, raw native reports and selected logs are linked from [the evidence report](evidence/kart-variety-2026-10-29/report.json).

Reload/rebuild and matching authorized backend catalogue rollout remain necessary. Owner appearance/input review and physical-device performance/input acceptance remain outstanding. No device attachment query/test, APK export/install, real auth/purchase, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge was performed.
