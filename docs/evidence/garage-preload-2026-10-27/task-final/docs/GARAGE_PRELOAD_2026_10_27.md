# Preload the original live Garage (2026-10-27)

The owner asks to preload beforehand while retaining the restored live Garage. The App now starts bounded asset reads after menu startup and prepares one selected-car studio after two seconds without deliberate input. Opening Garage transfers that same studio into the existing page. Its saved paint, pattern, stickers, parts, wear, original lights, glass, shadows, camera and both reflections remain; there is no stock-photo cover or substitute rendering.

| Requirement | Behavior |
| --- | --- |
| GP01 | Decode the selected native car, workshop and applicable livery/sticker assets before entry; at most four pending requests and one studio. Startup does not await native construction or rendering. |
| GP02 | Warm original geometry/material groups offscreen while idle, pausing between batches for deliberate input, held touches/buttons, menu transitions, text entry and backgrounding. Race loading/active gameplay retire the optional world. |
| GP03 | Adopt the exact world without rebuilding. A partially warmed but constructed studio releases every held mesh/margin before becoming interactive. An unfinished constructor or stale account/car/paint/parts/wear falls back to normal live entry. Decoded public assets remain held through that constructor. |
| GP04 | Records identity, profile, selected car and saved appearance fence publication. No preload appearance/condition save or screenshot is written. Include estimates in the existing 96 MiB optional-Garage budget; pressure evicts and suppresses optional preloading for that controller. |
| R01 / Q01 | Actual App, saved-wear bytes, viewport input, original reflection pixels, lifecycle guards, native captures and a scoped review patch. |

## Implementation

Runtime sources are `game/core/app.gd`, `game/ui/garage_page.gd`, `game/ui/garage_preloader.gd` and `game/ui/garage_preloaded_studio.gd`. The App schedules the helper after startup, supplies a matching studio at Garage creation and includes it in memory/appearance invalidation. The page accepts the supplied original showroom. The helper reads assets, checks the saved specification and owns one offscreen world. The studio inherits the existing renderer; its temporary preparation changes visibility/culling only and restores both before handoff.

All nodes, material configuration and scene-tree changes stay on the main thread. Native asset requests use ResourceLoader's existing threaded API. Headless dummy rendering uses serial asset reads: an earlier threaded run raised invalid mesh RID errors. The pinned [dummy mesh storage](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/servers/rendering/dummy/storage/mesh_storage.h) uses a RID owner whose [template default is not thread-safe](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/core/templates/rid_owner.h). The native path remains asynchronous; no engine thread-mode setting or test invariant is weakened. Godot's [thread-safety guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) describes the constraints around resource loading and active scene trees.

Preloading does not run the showroom's normal frame processing, so snow, washing and the record-player animation do not advance or save while it is offscreen. The same normal processing and input resume after adoption. Idle is measured from deliberate events; passive hover cannot starve completion. In-flight reads finish and are consumed even after invalidation/destruction. Existing shared engine/catalogue caches may remain after the owned world is evicted; residency figures are estimates, not RSS/PSS.

The original `car_showroom.gd`, reflection helper, shaders, geometry, car caches, simulation, input mappings, economy and save formats are unmodified by this task. Concurrent header/model/purchase/race work is preserved. Existing photo-first helpers stay unselected in production.

## Results and limits

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, RTX 3090 desktop, isolated profiles, empty API URL. The native suite uses the production two-second idle delay, deliberately pauses input, and opens Garage after preparation finishes:

| Fresh isolated renderer | Startup | Garage callback after preload | First live Garage page | Longest warm-draw interval |
| --- | ---: | ---: | ---: | ---: |
| Compatibility | 167 ms | 68 ms | 610 ms | 2.64 s |
| Desktop Mobile | 153 ms | 78 ms | 481 ms | 3.72 s |

The measured remaining warm phase was approximately 29.7 s Compatibility / 2.83 s desktop Mobile after the test's held-input pause, including the subsequent two-second idle wait. There were 101 explicit warm draws. The ready Compact estimate was about 49.8 MiB, including targets and an allowance for asset state. A cached Compatibility run reached the live page in 366 ms with a 71 ms callback.

Preloading moves work earlier; it cannot cancel a synchronous driver compilation already underway. Warm-draw intervals include other App rendering, and a fresh cache can still stall a menu during preparation. These are not phone measurements or a zero-stall/instant-entry guarantee. If the player opens Garage before sufficient preparation, normal original live construction remains available.

## Verification and evidence

Use `python docs/evidence/garage-preload-2026-10-27/run_checks.py LABEL SCRIPT MODE`. Full commands, environments, results, hashes, native captures, source snapshots and the reverse-checked scoped patch are in [report.json](evidence/garage-preload-2026-10-27/report.json).

- Task-start App replay only in isolated memory: two checks / one expected missing-preloader failure.
- Final focused checks: 381 headless / 382 Compatibility / 382 desktop Mobile pass. They cover normal startup, saved livery/wear, unchanged condition-file bytes, held-input suspension, passive hover, exact world transfer, original culling restoration, viewport touch, stale paint/account rejection, race-loading cancellation, backgrounding, pressure, asset-only fallback, partial warming and interrupted cooperative construction.
- Retained actual App: 141 checks pass. Retained live-entry regression: 46 headless checks pass. The unchanged reflection assertions, with readiness/adoption setup added in an evidence-only fixture, pass 28 Compatibility checks and preserve the original pixel thresholds. All 1,330 scripts parse.
- The preferred `scripts/dev.ps1 -Action CheckScript` succeeds through process-local execution-policy bypass; its generated identity/version receipt is recorded separately.

Initial parse placement, an invalid fixture that manually retired a Settings-suspended page, early dummy texture shutdown and the dummy mesh RID run remain in raw evidence. The fixture uses ordinary primary-menu navigation and lets the pre-existing catalogue reads retire before shutdown. No original appearance, visibility, input, reflection or save assertion was relaxed. Native screenshots show the adopted saved car in the original reflective workshop.

Reload/relaunch and owner acceptance of menu behavior, saved appearance, first-entry latency and device memory/performance remain. No device attachment check/test, APK/AAB, real authentication/purchase, owner-save/live backend mutation, deployment, main-index staging/commit/merge or owner-process restart was performed.
