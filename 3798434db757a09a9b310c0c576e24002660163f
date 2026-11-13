# Further Garage icon latency improvements — 2026-10-26

GIL01–GIL04/R01/Q01 improve the already shared/cached paint icons further, preserving their accepted look and exact customisation identities.

Three remaining costs are addressed. Visible cache reads now share one background job, with at most eight keys per batch. Completed PNGs are encoded/written in batches, trimming the disk cache once per batch, while the renderer can progress independently of that I/O. The stopped-when-idle single renderer, 24 GPU images, 196 owned disk files, 256 KiB input bound, key/generation fencing and hidden cleanup remain. The write queue is capped at eight images before construction/drawing waits for a flush; an in-flight batch can retain another eight. Scene/GPU publication remains on the main thread.

Icons also stop creating unused `PreparedCarCache` snapshots: that cache explicitly does not restore simplified models. A `cache_rest_pose` opt-out is passed only by the icon studio. All other callers default to the preceding snapshot behavior. The initial isolated no-snapshot diagnostic reduced Compact construction from 445 ms to 383 ms while retaining all original appearance checks.

Finally, icon construction uses the model's existing cooperative checkpoints, with a soft 16 ms work interval and explicit presentation readiness. The preview does not render partial geometry; lighting/framing and the first image begin after the car is ready. Other model callers retain their original 4 ms interval and synchronous/default flags. Individual unsliced operations and shader/driver work can exceed these intervals, so this is not a 16 ms frame-time guarantee. The first icon may take additional elapsed time while construction yields, in exchange for avoiding one large UI stall.

The initial 4 ms icon proposal preserved appearance but took 15.384 s for the Vulkan cold catalogue under concurrent load. It is retained under `initial/four-ms-slices/`; the final icon-only 16 ms interval avoids that excessive yielding overhead. The final recorded Windows diagnostics are:

| Compatibility, 49 icons | Cold pass | Longest sampled cold interval | Disk-cached pass |
| --- | ---: | ---: | ---: |
| Task-start worker reloaded with current assets | 3.183 s | 822 ms | 0.625 s |
| Final worker | 2.200 s | 132 ms | 0.325 s |

The first unmodified task-start baseline was 2.983 s / 665 ms / 0.624 s; both baselines are retained. Final desktop Vulkan is 3.733 s cold, 143 ms longest sampled interval and 0.325 s cached. Cold construction still builds one model; the cached pass has 49 disk hits, zero models and zero icon renders. The four-row diagnostic now needs 13 read batches and 13 write batches instead of one job per icon. Timings vary with shader/driver state and other running processes; these are Compact catalogue diagnostics, not physical-device or whole-Garage-startup measurements. Some non-Compact construction functions still contain unsliced work.

Focused tests pass **94 Compatibility / 94 desktop Mobile**, including all 21 fresh-reference customisation comparisons in each renderer, unchanged 0.02 pixel tolerance, cache identities/corruption/eviction, old-work cancellation, and hiding during an actual unfinished cooperative build. An isolated task-start-worker control passes **90 checks** with current assets. The control's one additional check validates its in-memory script reload. The previous fixture initially attempted to exercise an asynchronous phase in the synchronous old worker; that failure is preserved and the new-only phase guard is now conditional on the new worker API. No production invariant is relaxed.

Retained paint-menu checks pass **151 headless / 192 Compatibility / 192 desktop Mobile**; parser **1308** and pinned import pass. Actual exits/counts are recorded in [report.json](evidence/garage-icon-latency-2026-10-26/report.json). The retained fixture now waits for the concurrent progressive Garage's `preparing` state before accessing its livery tools; all input/save/account/compare assertions remain. Initial concurrent Electric reveal assertions, a header texture signature mismatch and the early progressive-readiness fixture error are retained under `initial/`; the geometry/header source work is excluded from this task.

The broader racing-model suite has **101 checks / four failures** concerning Forklift shadow/wheel frames and Electric shadow/brake fixtures. Reloading the exact task-start `CarVisual` only in isolated memory reproduces the same four messages and identical model counts (**102 / four**, including its reload assertion). These are not reported as passes or fixed by this task. The original assertions remain.

Runtime scope is `garage_paint_icons.gd`, the optional studio-construction/readiness fields in `rivalry_victory_car.gd`, and default-preserving snapshot/budget fields in `car_visual.gd`. The profile studio factory, car geometry, shaders, main Garage camera, prices, saves/accounts and canonical simulation are unchanged by this task. Concurrent Garage model-template integration in `CarVisual` is retained and excluded through a task-only review base.

Actual isolated commands use pinned Godot 4.7.2:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Before -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Before -Mode gl_compatibility -NoRestCache
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Before -Mode gl_compatibility -LegacyWorker
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_racing_car_models -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_icon_latency_model_control -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-icon-latency-2026-10-26/run.ps1 -Import
python docs/evidence/garage-icon-latency-2026-10-26/record.py
```

The runs use isolated APPDATA, unique cold directories and offline fixtures. [Native views and timing review](evidence/garage-icon-latency-2026-10-26/review.html), raw metrics, original failures, source hashes and the reverse-checked scoped patch form the checkpoint. Original task-start sources remain under `before/`; tracker and shared-constructor review bases include later concurrent changes. No staging or commit is performed.

Reload and owner appearance/scrolling acceptance remain. Physical-device cold/warm frame-time and memory acceptance remain. No attachment check or device test, APK, real authentication/purchase, owner-save/live mutation, deployment, merge or owner-process restart was performed. Concurrent geometry, Garage entry/model caching, header, Rivalry, handling and track work are preserved.
