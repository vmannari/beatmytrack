# Deferred Garage views and neutral loading cars — 2 November 2026

Garage previews no longer hold startup or Garage navigation. An early visit opens the normal Garage page with subtly pulsing matte-grey silhouettes made from the existing actual-car masks. The main silhouette remains until the original saved live studio has finished preparation; missing carousel photographs replace their own silhouettes independently. Fully prepared background studios still transfer directly.

Requirements: GDF01 remove Garage work from the startup gate while retaining the correct equipped header; GDF02 open Garage with car-specific abstract loading art; GDF03 preserve original live appearance, controls, ownership and cancellation; GDF04 record actual validation and a task-only checkpoint.

## Behavior and implementation

- `App._ready` retains `header_car_cache.prepare_selected()`, then presents its destination without awaiting Garage pictures. Catalogue prefetch and the preloader's picture/native work begin after startup completes. The preloader checks startup before creating its picture service, so removing an `await` does not simply leave the same captures running behind the startup cover.
- Top-tab navigation, swipe preview/commit, direct screen navigation, profile achievements and the Cars section no longer wait for every picture. Explicit readiness/preparation helpers remain available to callers that deliberately require a complete snapshot; navigation does not use them as a gate.
- An unprepared main studio uses the existing staged `garage_opening_showroom.gd` path with the new neutral cover. It retains the actual detailed car, saved paint/parts/condition, original room, floor/pedestal reflections and final full covered draws. Achievement-wall contents are installed before staging the scene. Orbit controls appear when interaction is ready; early workshop requests retain their destination, and a subsequent Cars request cancels it.
- Only a completely prepared, matching preloader studio can transfer directly. Partially built/warmed or stale studios fall back to the neutral loading path; decoded resources remain available for reuse. This may repeat some scene assembly after an early visit, but avoids exposing unfinished graphics preparation as a ready view.
- Both main and thumbnail placeholders reuse the five current offline model masks from `rivalry_loading_cars_v1.png`. The grey finish and low-amplitude pulse run in one simple canvas shader. There are no added 3D worlds, per-frame script animation callbacks, substitute factory liveries or additional ordinary UI labels.
- Picture services share account-bound ready-picture ownership. Missing disk images use the existing worker-read path rather than synchronous decoding at entry. Captures still yield to the existing idle/input/foreground and menu-motion gates. Background pictures do not compete with the preparing main studio. Race loading, pressure, hidden pages, owner changes, stale keys and destruction retain their fences.

The existing simulation, scoring, car geometry, equipped-header implementation and final materials are unchanged. This slice does not reduce App's eager resource graph or solve indivisible cold graphics compilation.

## Actual checks

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows, RTX 3090, Dummy audio, private APPDATA/records/library/cloud directories and `BMT_API_URL=""`. No real account or owner data is used. The focused native fixture saves custom paint for all five current cars, keeps the main studio paused to inspect early entry, then exercises actual preparation and picture delivery.

| Run label / script | Result |
| --- | --- |
| `accepted-headless` / `test_garage_deferred_views.gd` | **44 / 0** |
| `accepted-compat` / same, native Compatibility | **61 / 0** |
| `accepted-mobile` / same, native desktop Mobile | **61 / 0** |
| `accepted-preload-headless` / `test_garage_preload.gd` | **443 / 0** |
| `retained-carousel-headless` / `test_garage_entry_carousel.gd` | **46 / 0** |
| `retained-live-headless` / `test_garage_live_entry.gd` | **36 / 0** |
| `retained-live-compat` / same, native Compatibility | **40 / 0** |
| `retained-reflections-compat` / `test_garage_opening_reflections.gd`, native Compatibility | **18 / 0** |
| `final-tools-headless` / `test_garage_opening_tools.gd` | **15 / 0** |

Accepted runs total **764 checks / 0 failures**, with **15 native captures**. They cover deferred startup, required equipped-header readiness, immediate top-tab entry, all current loading identities, rapid preview without equipping, queued/cancelled workshop destinations, hiding/reopening, race preparation, full saved-paint reveal, carousel scrolling/delivery, optional eviction, owner replacement and destruction. Retained live tests exercise actual viewport-dispatched dragging, paint changes and every current car. Compatibility reflection checks measure visible floor and pedestal differences and verify moving reflections; this is not a new exact pixel-equivalence claim.

The final focused native runs have unchanged hashes for all recorded sources across each run. Their measured entry dispatch is approximately **110 ms Compatibility / 103 ms desktop Mobile**. The full studio still takes roughly **22.3 / 15.1 seconds** after the fixture permits it to prepare. These are isolated development observations, not controlled before/after speedups, release results or Android predictions. App resource loading and the existing customized-header wait remain outside the optimization; the prior review's 15.5-second Garage phase is not a demonstrated saving to subtract from these different workloads. Some supporting validation ran alongside other owned tests; no benchmark isolation is claimed.

Native views:

- [Compatibility loading, 1280×720](evidence/garage-deferred-views-2026-11-02/accepted-compat/loading-1280x720.png), [960×540](evidence/garage-deferred-views-2026-11-02/accepted-compat/loading-960x540.png), [1600×900](evidence/garage-deferred-views-2026-11-02/accepted-compat/loading-1600x900.png).
- [Compatibility live saved car](evidence/garage-deferred-views-2026-11-02/accepted-compat/live-1280x720.png), [completed carousel](evidence/garage-deferred-views-2026-11-02/accepted-compat/pictures-ready-1280x720.png).
- [Desktop Mobile loading](evidence/garage-deferred-views-2026-11-02/accepted-mobile/loading-1280x720.png), [live car and completed carousel](evidence/garage-deferred-views-2026-11-02/accepted-mobile/pictures-ready-1280x720.png).

### Retained failures and environment limits

The first focused headless run rejected remaining references to the removed navigation gate; those references were corrected, and explicit opt-in preparation helpers were retained for existing callers. Two early native probes waited for an offscreen fifth thumbnail without scrolling; their logs are retained, and only their verified owned process trees were stopped. The corrected fixture browses the carousel so the fifth view becomes eligible. A preload assertion initially required a synchronous fallback; its adapted check retains complete-car/culling validation after the newly requested loading state. The tools cancellation fixture originally reached an already-warmed second studio after its preparation had finished; it now explicitly clears its test-local warm receipts before requiring an unfinished batch.

A **separate standalone desktop Mobile reflection probe is not counted as a pass**. It completed 18 assertions with zero assertion failures, then remained in renderer shutdown beyond the 300-second process timeout. The original runner's restricted process-tree cleanup also failed and raised another timeout; an explicitly verified, normal-access cleanup recorded and stopped only that owned tree. Its [failure record](evidence/garage-deferred-views-2026-11-02/mobile-shutdown-failure.json), process details, views and log are preserved. The runner now retains timeout receipts even if cleanup fails. This hang is not attributed to a specific change or claimed fixed. The final **actual-App Mobile run exits zero** after loading, picture delivery, owner replacement and teardown.

All accepted logs retain the sandbox's Windows root-certificate-store error. No accepted run reports a script error. A clean environment-log claim is not made. Per-run receipts record concurrent build-identity changes in some supporting runs; there is no whole-tree source freeze claim. Initial failures, stopped probes and the standalone shutdown failure are excluded from the accepted total rather than erased.

## Reproduction and checkpoint

From the workspace root:

```powershell
python docs/evidence/garage-deferred-views-2026-11-02/run_check.py accepted-headless res://tests/test_garage_deferred_views.gd --headless
python docs/evidence/garage-deferred-views-2026-11-02/run_check.py accepted-compat res://tests/test_garage_deferred_views.gd
python docs/evidence/garage-deferred-views-2026-11-02/run_check.py accepted-mobile res://tests/test_garage_deferred_views.gd --renderer mobile
python docs/evidence/garage-deferred-views-2026-11-02/run_check.py accepted-preload-headless res://tests/test_garage_preload.gd --headless
python docs/evidence/garage-deferred-views-2026-11-02/summarize.py
python docs/evidence/garage-deferred-views-2026-11-02/checkpoint.py
```

Choose new labels to preserve existing evidence. The other actual commands and private profiles are recorded in their `*-receipt.json` files. Every Godot launch uses `scripts/run_no_crash_dialog.py`; the runner's deadline is 300 seconds. [Summary and capture hashes](evidence/garage-deferred-views-2026-11-02/summary.json), raw logs and source receipts remain in the evidence directory.

Runtime changes: `game/core/app.gd`; `garage_page.gd`, `garage_preloader.gd`, `garage_preview_cache.gd`, `garage_cached_thumbnail.gd`, `garage_opening_showroom.gd`; new `garage_loading_car.gd` and its shader. New focused test; five retained Garage fixtures adapt their old synchronous/stock-picture assumptions while retaining final quality, input and lifecycle assertions. This report, scoped helpers and short AGENTS/DEVELOPMENT_STATUS entries complete the task records. No new production bitmap or baked model assets are generated.

The task-only source patch is checked forward/reverse with normalized content equality in an owned workspace directory. Concurrent status notes are preserved by including only this task's marked block. The main Git index is not written. Concurrent music, playlist, car, Garage and other changes remain intact.

Reload is required. Owner appearance/input acceptance and Android performance remain. No physical-device query/test, APK/export, backend/live access, real authentication/purchase, deployment, owner-save change or owner-process restart/termination was performed. Only owned diagnostic process trees were stopped. No fixed FPS, zero-stall or quantified launch-speedup claim is made.
