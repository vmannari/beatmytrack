# Go-kart customisation kits, 2026-10-28

Garage → Parts now supports the Go-kart with four independently saved cosmetic categories. Each offers Original and three fitted alternatives, allowing 256 combinations.

| Requirement | Category | Alternatives |
| --- | --- | --- |
| KKC01 | Nose | Sprint nose, Endurance nose, Wedge nose |
| KKC02 | Rear bumper | Wraparound bumper, Wide rear bumper, Twin rear bumper |
| KKC03 | Rims | Three spoke, Split six, Disc wheel |
| KKC04 | Side pods | Sprint pods, Endurance pods, Wedge pods |
| KKC05 | Workflow | Touch preview, compare, equip, independent saved choices, cancellation, failed-save rollback, reset and car switching |
| KKC06 / R01 | Integration | Existing ownership/coin flow, private/shared appearances, actual racing, fitted ghosts, full/simple geometry, wash mapping and cache identities |
| Q01 | Review | Both desktop renderers, three viewport sizes, native captures, translations and a checked source patch |

The existing internal keys `hood/aero/rims/body` and version-one save shape remain stable. `vehicle_customisation.kart` stores the kart's own IDs; Compact IDs and choices remain available independently. Validation admits only the correct vehicle's catalogue. Cosmetic item IDs use `kit/kart/<category>/<option>` and the existing 750-coin price convention; Original remains free. The backend enforces permanent ownership for private appearance sync and public appearance publication. No account purchases or online writes were performed.

The kart retains its original chassis, driver, engine, tyres, wheel positions and articulation. Nose/fairing and pod variants use the kart's formed-panel construction, fitted stripes and actual shell-mounted hardware. Rear bumpers attach to the original chassis rails. Rims roll beneath the existing steering pivots. Garage replacements keep the current car, viewport and other part frames. Full/simple snapshots include the exact kit identity; customized simple models retain their own shadow silhouette. Saved stock wash coordinates remain stable when a fitted bumper changes the bounds.

All geometry is original project code for the unbranded kart. No downloaded model, generated image, runtime API or dependency was added. The existing native asset baker added 192 immutable full/simple part meshes, bringing the kart manifest to 484 entries, and retained existing stock mesh resources. All six prepared Garage templates were refreshed successfully. The source-only checkpoint excludes generated assets, identities and concurrent work; those assets remain in the workspace and their hashes are recorded separately.

## Actual validation

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Tests use project-local `APPDATA`/`LOCALAPPDATA` under `build/kart-kits/local`, disposable records and an empty `BMT_API_URL`.

| Check | Actual result |
| --- | --- |
| New actual-Garage regression, Compatibility | 507 checks, 0 failures; 22 native captures |
| Same regression, desktop Mobile/Vulkan | 507 checks, 0 failures; 22 native captures |
| Frozen task-start stock arrays/transforms | 4 checks, 0 failures across both detail levels and editable/non-editable assembly |
| Existing kart model | 62 checks, 0 failures; stock 87,136 full / 30,292 simple triangles |
| Existing kart construction | 32 checks, 0 failures |
| Existing kart bodywork, unbaked | 16 checks, 0 failures |
| Backend kart/appearance/coins suite, SQLite selection | 59 passed, 1 intentional concurrency skip, 37 deselected |
| Scoped translations | 27 authored messages; 324 nonempty translations across 12 languages; native Finnish/German captures |
| Scoped Ruff | All checks passed |
| Preferred Garage dependency check | Passed |
| Source checkpoint | 47 files; live reverse check, isolated forward application, source comparison and isolated reverse check passed |

The new regression checks every category/option at both detail levels, distinct native geometry, exact tyre and wheel retention, unchanged part frames, stock reset, fresh assembly equivalence, wash coordinates, atomic reload, failed-save rollback, locked purchase cancellation, Compact/kart switching and actual race/ghost loading. Measured sampled choices span 29,844–90,976 triangles, below the existing 120,000 bound. This is not an exhaustive performance measurement of all 256 combinations or an Android frame-rate claim.

Representative captures: [Nose](evidence/kart-kits-2026-10-28/compatibility/tuning-hood.png), [bumper](evidence/kart-kits-2026-10-28/mobile/aero-loop.png), [rims](evidence/kart-kits-2026-10-28/mobile/rims-six.png), [960×540 layout](evidence/kart-kits-2026-10-28/compatibility/tuning-960.png), [Finnish](evidence/kart-kits-2026-10-28/compatibility/tuning-fi.png). Each renderer's folder contains all twelve alternative selections and the final report.

Commands actually run, with repeated diagnostic attempts retained in the logs:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/kart-kits/local/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/kart-kits/local/localappdata'
$env:BMT_API_URL = ''
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_kart_kits.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/kart-kits-2026-10-28/compatibility' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/kart-kits-2026-10-28/mobile' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kit_stock_control.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_model.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_construction.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_bodywork.gd -TestArgument '--unbaked'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_appearance_sync.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
$env:PYTHONPATH = Join-Path (Get-Location) 'backend'
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_kart_kits.py backend/tests/test_rivalry_appearance.py backend/tests/test_appearance_sync.py backend/tests/test_earned_coins.py -q -k 'not postgres and not test_catalog_matches_native_assets' --basetemp=build/kart-kits/pytest-final
& .tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/vehicle_appearance.py backend/bmt_backend/economy.py backend/bmt_backend/appearance_authorization.py backend/tests/test_kart_kits.py backend/tests/test_earned_coins.py
git apply --reverse --check docs/evidence/kart-kits-2026-10-28/source-only.patch
```

## Retained findings and limits

Initial engine startup was denied access to the Windows certificate store; the same isolated offline runs passed with the required host access. A typed-array initialization error and the simple-model primitive replacement mismatch were corrected. The first schema test incorrectly rejected the shared `six` rim ID; it now checks the actual per-car catalogues. The first stock comparison attempted live script reload and hit a class-identity parse error; the final comparison uses frozen source fixtures, with only the old detail preload redirected to its paired fixture. A transient concurrent Electric `theta` parse error cleared without edits from this task. The checkpoint helper initially inherited the parent Git worktree and skipped application; an isolated repository now verifies actual patched file contents.

The original full backend selection encountered unavailable PostgreSQL connections and was interrupted; final database coverage is SQLite only. An original catalogue test still finds twelve extra backend sticker IDs, already present in the task-start catalogue. It was retained unchanged and explicitly excluded from the final selected run. The expected coin catalogue assertion was extended to verify the original 87 items plus exactly twelve kart entries, including each price.

The retained native appearance-sync fixture aborts at its retired Formula expectation (`fake.saved.formula`, line 114); the current sync loop uses the six active cars. Full script parsing hits the previously recorded `tests/fixtures/parking_hall_before/garage_page.gd` missing `_build_wash_requirement()` method. Neither fixture was altered. The preferred current Garage dependency check passes. No clean full-project regression or localization-completeness claim is made.

The original task-start sources remain under `build/kart-kits/before`. The review baseline adds the concurrent Super Wash button/handler to its Garage context, so the task patch preserves and excludes that work. Native templates can include concurrent model authorship; no whole-tree freeze is claimed. Source hashes, selected logs, native reports and checkpoint receipts are in [the evidence report](evidence/kart-kits-2026-10-28/report.json).

Reload/rebuild is required. Matching backend rollout is still required before signed-in users can purchase or sync the new kart items against the running service. No physical-device query/test, APK export/install, live backend/account/owner-save mutation, owner-process restart, deployment, main-index staging, commit or merge was performed. Owner review of appearance/input and actual-device performance remains outstanding.
