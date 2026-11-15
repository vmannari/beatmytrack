# Faster first Garage entry — 2026-11-14

GFS01–GFS03/GFSQ01 implement the owner's request for a substantial further reduction after the earlier 12% pass. The final matched Compatibility median falls from **3.098 s to 1.894 s, 38.85% faster**, through to the fully interactive native Garage. All six fitted cars pass first-reveal checks in both desktop renderers. Client restart and owner/device acceptance remain.

## Changes

`garage_opening_showroom.gd` now draws the receiving studio and its two real reflections under the existing loading picture. It removes the extra warm viewport, proxy geometry submissions and cloned lighting. Four actual settle draws remain before reveal. Reflection targets start at their final 4× sampling, avoiding their previous 2×→4× transition. Final lighting, geometry, camera, finish, resolution and reflection quality remain the same.

The opening waits for a 100 ms quiet interval instead of 750 ms, while retaining navigation, visibility and foreground gates. Held input and focused text entry also pause construction/capture. Covered car, paint and parts changes coalesce into the first built car; actual reduced bases and equipped modules read through the existing worker loader. Success, failure and destruction relinquish threaded request tokens.

`garage_page.gd` loads optional paint/sticker, parts, record, news, achievements, ranking and purchase controllers when opened. Its selection/news behavior is otherwise unchanged. `garage_preview_cache.gd` computes the Volt picture's extra revision from complete source hashes without importing three construction scripts; packaged resources fall back to the generated build fingerprint. The prior identity fixture now explicitly checks full and reduced keys and the new complete-source revision.

## Matched measurements

Each sample starts a fresh process with disposable offline App storage. The lightweight probe has no Garage/vehicle class references before navigation; all three monitored scripts are uncached. The selected fitted Compact, successful prepared-base hits, complete runtime source comparison, current geometry key and retained studio are checked after timing. The endpoint is the interactive main 3D studio; carousel thumbnails can continue loading independently. No driver-cache reset is performed. Round zero fills each project's caches and is excluded from the table.

Two private source shadows use the same fixed current model snapshot. Only the four production UI sources above differ: **838 watched inputs are shared**, with no watched changes during the reported runs. The final four source hashes match the live checkout. These are script-cold/process-fresh measurements with filled per-project renderer caches, not a cold-driver guarantee.

| Renderer | Previous path | Final path | Reduction |
| --- | ---: | ---: | ---: |
| Compatibility, three alternating pairs, median | 3,097.928 ms | 1,894.457 ms | 38.85% |
| Desktop Mobile, one pair | 3,536.219 ms | 2,969.610 ms | 16.02% |
| Compatibility synchronous navigation/import median | 1,525.497 ms | 769.760 ms | 49.54% |

Compatibility total samples are 3,097.928/3,158.749/3,050.620 ms before and 2,219.634/1,894.457/1,863.407 ms after. Final retained re-entry is 2.308–2.615 ms. Large first-use slices remain: the final Compatibility asynchronous samples peak at 593–765 ms, and the desktop Mobile sample at 1,085 ms. There is no smooth-frame, FPS, Android or universal latency claim.

The earlier typed probe imported Garage classes before navigation and is excluded. Moving-source/fallback runs and the first snapshot's timings are also excluded from the final comparison. An earlier desktop Mobile cache-fill control took 75.5 s versus 8.5 s for the direct path, but order/global-driver-cache effects make that a diagnostic rather than the performance claim.

## Verification

| Actual check | Result |
| --- | --- |
| Current six fitted cars, first reveal, held input, saved paint/wear, targets/lights | 90/0 per desktop renderer |
| Existing native reflection switch/pixel checks | 18/0 per desktop renderer |
| Existing paint/parts animation, covered requests and cancellation | 16/0 per desktop renderer |
| Shared graphics receipts/context/mutation checks | 168/0 per desktop renderer |
| Retained Garage lifecycle/input/owner/pressure/cancellation | 439/0 native Compatibility |
| Actual App entry, saved paint, orbit, all six cars, re-entry and owner replacement | 45/0 per desktop renderer |
| Actual paint/sticker tools | 187/0 native Compatibility |
| Current actual-App record playlist/input/transport | 63/0 native Compatibility |
| Optional news finish | 17/0 headless |
| Lazy-controller imports / Volt dependencies / exact identity fixture | 9/0, 9/0, 6/0 headless |
| Reduced asset paths / worker success/failure/destruction | 122/0, 29/0 headless |
| Final production parser | 570 scripts, 0 failures |
| Final full prepared preflight after publication | 551 resources, 2,267 checks, 0 failures |
| Catalogue / native imports / workshop | Six images, 171 current sources; six MD5-verified imports; 27 workshop sources |

All six final Mobile first textures are byte-exact against eight further frozen draws. Compatibility stays within the unchanged new test's maximum-two-byte/mean-0.1 budget; exactness and actual differences are recorded per car. The initial private snapshot had a maximum-seven-byte first-Compact difference in Mobile; the old loader reproduces that same comparison failure, along with its expected input/extra-viewport failures. An experimental six-settle version still failed and was removed. The final current models pass without relaxing that assertion. The older player-polish suite stops at its removed `records_menu.crate` API; it is retained as a historical fixture finding, and the current playlist suite passes unchanged. Earlier raw bit-exact assumptions, fixture errors, stopped probes and unsuccessful controls remain in the receipts; this is not a whole-repository clean-suite claim.

## Assets, concurrent work and publication

Shared model source and raw recipes changed repeatedly during rebuilding. Private source snapshots and source/output fences reject those attempts. A concurrent optimizer also superseded the narrow ImmediateMesh fallback correction; no task-owned vehicle source change remains. Its stricter ring matcher invalidates an exploratory synthetic-ring fixture, which was removed rather than changing that model code.

The final model snapshot closes **24,118 consumed inputs**. The concurrent producer's qualified base/module bytes are copied into the private candidate and preserved. Strict private checks qualify the combined set. Final publication changes the stock header template, five catalogue PNGs, catalogue provenance and generated identity/project version; the Hover picture remains exact. Full current 551-resource validation passes afterward. No source metadata was restamped to bypass a mismatch.

A later concurrent generated identity/version refresh is preserved. Final geometry keys still match the qualified publication, its header/photo bytes remain exact, and the live 24,118-input source fence plus catalogue/workshop validators pass. The receipt records those two superseded generated metadata files explicitly.

The generic runner's `--output` initially sent preview bakes to the run directory. The catalogue validator exposed that gap; the producer now receives an explicit candidate asset destination. Active IDs also filter the importer so the three retired photographs remain untouched. Source-bound catalogue checks and six native import checks pass after correction. The refresh tool now validates catalogue provenance as well as car sources before publishing.

Offscreen actual-App checks use a task-owned foreground adapter; it changes only the owned fixture's foreground flag and leaves production guards intact. Performance samples run sequentially without other task-owned native work. No owner process is focused, stopped or restarted.

## Commands and evidence

```powershell
python scripts/run_garage_fast_entry.py example --script res://tests/profile_garage_fast_entry.gd --fitted
python scripts/run_garage_fast_entry.py reveal --script res://tests/test_garage_first_capture.gd --renderer mobile
python scripts/run_garage_fast_entry.py retained --script res://tests/test_garage_preload.gd
python scripts/run_garage_fast_entry.py prepared --headless --script res://tests/check_prepared_assets.gd
python scripts/run_garage_fast_entry.py parse --headless --script res://tests/check_model_refinement_parse.gd
python scripts/refresh_garage_fast_entry.py --candidate=build/garage-fast-entry-2026-11-14/bake-live --rebase-qualified
python scripts/import_garage_fast_entry_images.py
python scripts/check_garage_previews.py
python scripts/check_garage_workshop.py
```

Every launched Godot process uses pinned 4.7.2 through `run_no_crash_dialog.py`. Exact commands, outcomes, changed-input receipts, measurements and relevant captures are in the [machine report](evidence/garage-fast-entry-2026-11-14/report.json), [comparison inputs](evidence/garage-fast-entry-2026-11-14/comparison-inputs.json) and [native views](evidence/garage-fast-entry-2026-11-14/native). The [source checkpoint](evidence/garage-fast-entry-2026-11-14/task.patch) excludes concurrent vehicle/UI authorship and derived binary data.

Production source changes are limited to `game/ui/garage_opening_showroom.gd`, `garage_reflections.gd`, `garage_page.gd` and `garage_preview_cache.gd`. Supporting changes include four new probes/UIDs, the exact identity fixture, the extended isolated runner and three new task runners/refresh/import tools. Disposable project copies, caches and profiles stay under `build/`; concise receipts and relevant comparisons remain here. No task retention pin is created.

The 19-file normalized source checkpoint applies and reverses exactly in a private fixture. The prescribed `clean_build.ps1 -Apply` ran: 27.56 GiB remained, no entries were eligible and no failures occurred. Recent/protected output exceeds the 20 GiB target; the [cleanup receipt](evidence/garage-fast-entry-2026-11-14/retention.json) is retained under the repository's 24-hour active-work grace.

No physical-device query/test, export, backend request/deployment, owner-save edit, owner-process action or main-index staging/commit was performed. Restart/rebuild the client to use the changes; phone timing, appearance and interaction acceptance remain.
