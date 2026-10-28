# Reusable paint-icon renderer and persistent images — 2026-10-26

GIP01–GIP04/R01/Q01 address the owner's performance report while preserving the accepted paint-row appearance.

The preceding worker did retain 2D textures, but every cache miss constructed a complete profile studio/car and destroyed it after one icon. A native full-catalogue reproduction creates **49 models**, takes **12.317 s**, and records a **682 ms** longest sampled frame interval. Its original **16 checks / 2 expected failures** and exact source snapshots are retained.

The worker now retains **one model for the current vehicle/fitted parts while the paint list is visible**. Each subsequent icon updates paint/sticker uniforms and the existing podium finish; it reuses geometry, camera, lights and radiance. Camera fitting is reused too. The viewport stops drawing and processing when the queue is idle. Changing vehicle/parts replaces that one model; hiding or freeing the menu cancels work, disconnects callbacks and releases it. This supersedes releasing the studio after every icon, while retaining the original one-attached-world, hidden cleanup and stale-row guards.

Completed icons are persisted as 224×152 PNGs. Later visits can decode 2D images with no icon model or readback. Cache identity includes renderer, client build, exact vehicle, full paint/sticker data, fitted parts and presentation version. A changed appearance or build cannot reuse a different icon. Reads, PNG encoding/writes and eviction use the existing tree-owned background-job helper; threads never access scene nodes or GPU objects. Weak row references, exact keys and generation checks fence publication. Missing/corrupt/unusable cache entries fall back to rendering.

GPU images retain the **24-entry** bound. Disk storage retains **196 owned image files**, with a **256 KiB compressed input limit per file** and PNG extent validation before decoding. Eviction operates only on 64-hex PNG names in this cache directory. Cancelled jobs cannot publish into an outgoing row. The renderer retains one simple model while visible, trading bounded idle memory for avoiding repeated construction; no claim is made that initial model construction is free.

Final native full-catalogue diagnostic results:

| Run | Model constructions | Time for 49 icons | Longest sampled frame interval |
| --- | ---: | ---: | ---: |
| Original Compatibility | 49 | 12.317 s | 682 ms |
| New Compatibility, empty cache | 1 | 3.383 s | 1048 ms |
| New Compatibility, disk cache / empty RAM cache | 0 | 0.625 s | 8.57 ms |
| New desktop Mobile, empty cache | 1 | 5.515 s | 2370 ms |
| New desktop Mobile, disk cache / empty RAM cache | 0 | 0.625 s | 9.03 ms |

The model counts and cache hits are directly observed. Timings include native rendering, shader/driver state and scheduling; final renderer diagnostics ran concurrently, and these are Windows measurements rather than phone results or FPS guarantees. The original run was separate. Cold construction/shader work still creates a substantial first-use hitch. This change removes its repetition across icons and across cached revisits; it does not fix the separate Garage entry/world-construction cost. Initial reuse measurements are also retained under `initial/first-reuse/`.

The new focused regression passes **89 Compatibility / 89 desktop Mobile**. It traverses all 49 cold designs with one model, clears the RAM cache/replaces the worker, then gets 49 disk hits with zero models/renders. Independent fresh profile renders cover three custom-paint cases on all seven cars, including a fitted Compact body kit and a panel sticker: maximum sampled RGBA mean difference is **0.002074 Compatibility / 0.002111 desktop Mobile**, below the unchanged **0.02** appearance threshold. It also checks cache identities, corrupt/wrong-size/oversized files, cancellation, bounded eviction without removing unrelated files, replacement workers and hidden studio cleanup. Retained paint-menu checks pass **151 headless / 192 Compatibility / 192 desktop Mobile**, preserving actual App mouse/touch, selection, comparison, purchase confirmation, save/account and teardown assertions. Parser **1277** and pinned import pass.

Runtime scope is `game/ui/garage_paint_icons.gd` and a static repaint helper in `game/ui/profile_car.gd`. This task does not change the profile-button refresh/transition logic; concurrent work there is retained and excluded. The shared studio factory and lighting stay unchanged. The sole adapted retained assertion permits the reusable studio to remain stopped while visible, and still requires release when hidden. All accepted layout dimensions, 49 options, seven vehicles, prices, main Garage camera and authoritative cosmetic/account/economy behavior remain. Geometry, racing and simulation are unchanged by this task.

Actual isolated commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Before -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icon-performance-2026-10-26/run.ps1 -Import
python docs/evidence/garage-paint-icon-performance-2026-10-26/record.py
```

Tests use isolated APPDATA, unique cold-cache directories and offline fixtures. The warm test clears textures and destroys the cold renderer before reopening the saved images; no owner process is restarted. [Native view and performance review](evidence/garage-paint-icon-performance-2026-10-26/review.html), [exact metrics/commands/hashes](evidence/garage-paint-icon-performance-2026-10-26/report.json), original failures and the reverse-checked `task-only.patch` form the scoped checkpoint. Review bases retain concurrent tracker and profile-button additions, so only this task's status/helper changes appear in the patch; original captured sources remain under `before/`. No staging or commit is performed.

Reload and owner scrolling/appearance acceptance remain. Physical-device cold/warm frame-time and memory acceptance remain. No attachment check or physical-device test, APK, real authentication/purchase, owner-save/live mutation, deployment, merge or owner-process restart was performed. Concurrent kit/paint animation, Garage entry/camera, Rivalry, vehicle, handling and track work are preserved and excluded.
