# Cloud card selection latency, 2026-10-10

Owner: selecting tracks farther along Free Race still takes seconds to populate very small card/histogram data. Earlier requirements include Compact on Slippery, startup/restored selection and exceptional-only loading text.

## Requirements and implementation

- CSEL01: cloud browsing uses only public route/identity metadata plus cached comparison packets. Selecting a published card does **not** download, validate or compile its race document. Local/legacy selections retain their existing path.
- CSEL02: the selected metadata object carries the actual version/car identity. Race hydrates that same object with integrity-checked, prepared native geometry before the existing ticket/manifest/world path. Navigation, account, car, selection and cancelled-overlay fences reject stale preparation; late old completion cannot clear a newer loading operation.
- CSEL03: retain a presentation-only compiled PB hash hint, bound to the original document SHA-256, compiler and engine. Metadata refresh preserves a matching hint and discards changed-document hints. Existing candidate percentile/retained-frame reads remain available without preparing geometry. Hints cannot authorize races or scores.
- CSEL04: decode responses up to32KiB inline rather than creating a thread and waiting for a frame for a few histogram bins. Large decoding stays threaded. Continue speculative comparison jobs on a subsequent frame; preserve the bounded queue, selected-track priority, shared board reads and account/car fences.

Changed runtime files: `game/backend/backend_client.gd`, `game/backend/cloud_tracks.gd`, `game/backend/comparison_preloader.gd`, `game/core/app.gd`, `game/ui/track_browser.gd`. Updated meaningful carousel/continuity tests and added `game/tests/test_metadata_race_preparation.gd` and opt-in `game/tests/profile_live_card_selection.gd`. No backend/schema/physics/reward/competitive population change. Five ordinary laps, pinned tickets, trajectory acceptance, normal results first and optional ghosts remain.

## Actual live desktop evidence

Pinned4.7.2 native app,1280x720/RTX3090, existing artificial diagnostic account, isolated client records/cache. The helper obtains the existing development key into the child environment without printing it. Diagnostic runs create authentication sessions and read catalog/comparison/leaderboard data; they start no races/tickets and submit no scores. Credential/session files under ignored `build/` are excluded from evidence/checkpoints.

| Track / selection | Initial chart ms | Initial geometry ms | Final run1 chart ms | Final run2 chart ms |
|---|---:|---:|---:|---:|
| Curvy, immediate cold click |1005.374|1718.962|340.850|392.898|
| Slippery, Compact cold click |575.446|1951.295|404.647|313.262|
| Knit, immediate cold click |683.685|1055.325|448.768|403.044|
| Curvy, revisit |70.770|70.770|47.043|335.068|
| Narrow night,600ms scroll dwell |not measured|not measured|35.358|257.073|

All final rows remain metadata-only, with no race geometry preparation during browsing. Cold chart observations improved to313?449ms; warmed/revisit observations varied35?335ms. These are observational runs, not controlled percentages or a guarantee of instant UI/device behavior. Frame stalls remain: final cold worst-frame samples reached449ms. The small-response decode itself commonly measured0.04?0.24ms, but HTTP/TLS, callback scheduling, other client work and host load still contribute. Some earlier intermediate attempts were worse, up to1.69s for cards; removing geometry alone was not sufficient. A trial of nonthreaded small HTTP reads made cold charts557?749ms and was removed. A connection-reuse experiment, both frame-polled and worker-polled, also failed to improve the actual card path (one cold selection1.38s); it was removed in full. No transport rewrite or dependency was retained.

Evidence: `docs/evidence/card-selection-latency-2026-10-10/{initial-baseline,final-run-1,final-run-2,timings}.json`; settled `live-warmed-selection.png` visually inspected: correct Narrow night route/title/Race target, actual unified race/lap fields and score list, no ordinary loading caption or source classification. The screenshot was captured with the identical final presentation logic during the transport experiments; those experiments were removed because timings were worse.

## Actual commands and results

All native commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned engine.

- `-Action TestScript -ScriptPath res://tests/test_carousel_histograms.gd -Graphical`:21checks/0fail; distant paging, foreground priority, coalescing and zero browsing downloads/compilation, latest metadata Race target. Inspection of its pre-geometry capture retained.
- `-Action TestScript -ScriptPath res://tests/test_histogram_continuity.gd -Graphical`:15/0. Explicit diagnostic native handoff replaces the obsolete expectation that browsing automatically compiles; every handoff frame, local PB and late standings still preserve charts.
- `-Action TestScript -ScriptPath res://tests/test_instant_comparisons.gd -Graphical`:28/0, actual Slippery Compact packet/empty Kart field, persistence, exceptional notice and scope isolation.
- `-Action TestScript -ScriptPath res://tests/test_metadata_race_preparation.gd`:24/0. Real pinned compile/hydration, matching refreshed hints, changed source invalidation, navigation/car/account/selection/cancel gates and preservation of a newer overlay. Initial24/1 exposed a reused metadata object's stale hint after changing its source hash; added explicit source-hash binding, retained the assertion, reran24/0.
- `-Action TestApp`:99/0, including actual Race hydration/world, five-lap result/restart and restored local PB. Repeated after the final retained-hint restore lookup:99/0.
- `-Action TestScript -ScriptPath res://tests/test_unified_histograms.gd`:127/0.
- `-Action TestScript -ScriptPath res://tests/test_startup_histogram.gd`:22/0.
- `-Action TestMenuLoading`:40/0.
- `-Action TestScript -ScriptPath res://tests/test_menu_loading_speed.gd`:27/0.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd`:initial479scripts/0fail; final482scripts/0fail after transport experiments were removed.
- `-Action ExportAndroid -QuickValidation`: pinned template/import/startup and driving72/catalog21/menus48 all passed; Android debug export succeeded. Driving fixture reported32 shutdown ObjectDB references, retained as a diagnostic limitation. Saved build270079253bytes/SHA-256 `b2fbe05e939d2059c47e9c3b521107aa42ae120455275b8b665a49668d37a71b`, at `build/card-selection-latency/card-loading-debug.apk`; source shared with concurrent approved work, no device install.
- `.tools/backend-venv/Scripts/python.exe build/card-selection-latency/run_live.py`: completed live before/intermediate/final native graphical/headless traces; helper and secret resolution remain ignored local diagnostics. Profile script itself is committed without keys/identities.

A parallel native continuity command's approval review timed out; one permitted retry passed. A combined restore-edit/snapshot command was rejected because automatic review interpreted the in-memory baseline reconstruction as a removal of live code. The intended one-line edit was applied separately; read-only source reconstruction writes only verified destinations under `build/`, preserving live preparation code. An initial `CheckScript` invocation omitted `ScriptPath`, opening the main app instead of checking scripts. That owned process was stopped; the explicit isolated parser command above passed. The unintended app launch may have refreshed an existing session; no race was started, and its logs/session contents are excluded from evidence. No parser/app launch is reported as a passed parser test.

## Remaining acceptance and checkpoint

Source fixes are implemented and locally verified. This is **not** acceptance of zero-delay behavior: residual frame/HTTP latency needs the exact installed owner/platform trace. Old offline-only PBs without a retained compiled hint cannot be matched to a rules key using route metadata alone; their files remain intact and the actual race preparation restores the pinned contract. Verified own times remain supplied by the server. Cached metadata is presentation only; a cold Race still needs its immutable document and canonical preparation.

TabletOPD2403 (`f0ba474a`) was attached during the earlier read-only ADB check; no phone was observed. No tablet timing test, APK install, fullValidate, backend deployment, live PB reset or race/score submission was performed for this task. A concurrent task may build/install shared workspace changes; that is not this task's device evidence. Desktop source needs an app restart; The rebuilt Android debug client is ready; its installation/device timing remains outstanding. Public deployment still requires explicit owner authorization.

Review-only task checkpoint: `refs/codex/card-selection-latency-20261010`; receipt/patch under the evidence directory. Parent context preserves unrelated shared-workspace edits, while the child contains only this task's edits and evidence. HEAD and the user's index remain unchanged. Owner review remains required for actual perceived carousel latency and new-race/device timing.
