# Startup and race loading review 17 November 2026

Startup is dominated by loading the App dependency graph. First uncached race entry is dominated by road preparation and checkpoint layout. Cached race entry is dominated by the race and Game dependency graphs, followed by road support and world restoration. Night adds a substantial first-use lighting preparation cost. Further car triangle reduction has a much smaller measured loading opportunity.

Requirements: LRV01 measure startup to a drawn menu; LRV02 separate uncached, disk-restored and same-process race entry; LRV03 identify current contributors; LRV04 preserve runtime behavior and reproducible evidence.

## Current measurements

| Workload | Measured time |
| --- | ---: |
| Engine clock to first drawn unsigned-in menu | 5.479 s |
| App scene load through first drawn menu | 3.359 s |
| Star/Pine/Rally with empty private track caches | 16.200–16.926 s |
| Star/Pine/Rally after process restart with verified disk world | 6.049–6.339 s |
| Star/Night/Kart with empty private track caches | 24.499 s |
| Star/Night/Kart after process restart with retained road/checkpoint caches | 8.023 s |
| Same-process Pine race re-entry | 293–319 ms |
| Same-process Night race re-entry | 608–649 ms |
| Retry within the existing race | 12–20 ms |
| Offline sample Rivalry page with three prepared podium cars | 853 ms first entry; 98 ms repeat |

The Rivalry sample is a separate page-entry test after guest startup, not an authenticated startup measurement. Race entry starts at the actual App request and ends when the loading cover releases with simulation tick zero, all five laps and the complete three-second countdown remaining. Track file reading/compilation and menu entry precede that timer. Retry keeps the existing Game alive.

## Startup contributors

The unmodified baseline spends 3.142 s loading `app.tscn` and its dependency graph, 0.195 s initializing App and 0.021 s waiting for the first drawn menu. About 2.120 s of engine-clock time precedes the scene timer; this includes engine initialization, autoloads and probe setup and was not subdivided.

An independent timestamp-only initialization probe measures 3.158 s for the scene graph and 0.171 s for App initialization. Its 0.294 s diagnostic script reload is excluded from the reported application interval. Within initialization, the built-in fallback track takes 103 ms, final account page construction 42 ms, service setup 9 ms and overlays 8 ms. Offline account restoration takes less than 1 ms. Both probes show zero header captures, zero header disk hits and no deferred feature resource loads before readiness.

The main startup opportunity is reducing App's eagerly resolved script/type/preload graph. It includes account/backend composition, header and menu components, race-loading helpers and editor state helpers even when their full feature pages remain deferred. Individual dependency subtrees were not independently attributed; the 3.15 s belongs to their shared graph and resource loading together. Native car-picture capture is absent from the measured startup path.

## First uncached Pine race

Non-overlapping timestamp intervals from the 16.200 s detailed sample:

| Contributor | Time | Share of race entry |
| --- | ---: | ---: |
| Road preparation and publication | 5.663 s | 35.0% |
| Ground worker, almost entirely checkpoint preparation | 4.050 s | 25.0% |
| Race feature and Game resource graphs | 2.770 s | 17.1% |
| Scenery construction after the verified cache miss | 1.672 s | 10.3% |
| World identity and attempted restoration | 0.426 s | 2.6% |

Road preparation includes synchronous construction-dependency loading, CPU road generation, worker waiting and publication. The instrumentation does not split that interval into those substeps. Checkpoint worker instrumentation separately records 4.045 s. These two stages run sequentially in this offline path. About 60% of this sample is spent in those two preparation stages.

World rendering preparation and covered effects/final finish account for roughly another second. Prepared car setup takes 87 ms, and effects/audio setup 106 ms. World packing takes only 3.7 ms. The car base is accepted, rather than rebuilt procedurally. These subordinate counters are nested in larger intervals and must not be added to the table as independent totals.

## Restart with a disk world

In the 6.339 s detailed Pine restart, race feature loading takes 1.978 s and Game loading 0.872 s: 2.850 s combined, about 45% of entry. The ground worker takes 1.126 s, including 1.058 s building road support contours/bins and 65 ms preparing cached checkpoints. World restoration takes 943 ms, including 508 ms of source identity checking, 422 ms of disk read/validation and 6 ms of scene instantiation. Remaining time includes real render preparation, covered effects and finish draws, car setup and scheduling.

The runtime restores into `prepared_race_world.gd`, and the first disk-hit entry never loads `NativeTrackVisual`. Road preparation falls to about 147 ms. Car setup is 115 ms. Re-entry reuses in-memory support, checkpoint and world data and takes 317 ms. The independent unmodified restart is 6.049 s and passes the same disk-hit assertions.

The support cost remains because `road_surface_height.gd` retains numeric support only in the bounded RAM cache. A fresh process reconstructs the offset contours and spatial bins even when the rendered world exists on disk. World source hashing is a source-project development cost: exported builds use their packaged build identity instead of traversing the editable source tree.

## Night first use

The 24.499 s Star/Night/Kart entry spends 5.471 s in road preparation, 4.507 s in checkpoint work and 3.025 s loading race/Game resources. After the effects draw, the night-lighting, restored-finish and clean-draw interval takes 7.717 s. This is an aggregate presentation interval, not a separately measured shader compiler duration. `run_prepare_night_lighting` renders the prepared scene through the required lighting contexts and repeats preparation for clean/weathered material variants when required.

After process restart with retained road/checkpoint and existing shader caches, the same final interval is 150 ms and total entry is 8.023 s. Night world disk caching remains deliberately disabled by its existing qualification gate, so scenery is rebuilt on restart: 1.596 s, plus about 739 ms resolving the construction fallback before building. Same-process RAM restoration still works. Kart setup is 72 ms on the first entry. Comparing Kart/Night with Rally/Pine does not isolate the effect of changing car alone.

## Priorities

1. For first-ever races, prepare or ship version-fenced road packets and checkpoint layouts, preserving the existing geometry and canonical validation. Those stages are the largest measured uncached Pine cost.
2. For every fresh process, reduce the race/Game dependency graph and App startup graph. Source inspection retains the existing main-thread script initialization constraint; moving these loads to a worker needs separate correctness work.
3. Persist or prepare exact road support data alongside existing prepared worlds. The current disk-hit path still reconstructs about one second of support data in this Star sample.
4. Address Night separately: qualify persistent Night world restoration and investigate its first-use lighting/material contexts. Preserve the existing appearance and completion gates.
5. Keep car simplification below those loading priorities. Prepared setup is tens to roughly one hundred milliseconds in these samples; geometry/rendering quality changes need their own evidence.

## Evidence and limits

Nine stable native probes pass with zero measured snapshot source changes and no logged engine warnings/errors. Race/page fixtures pass 108 checks in total; both startup probes also complete their assertions. The fresh prepared-world assertions pass in both unmodified and instrumented disk-hit runs. This is an audit; no shipping runtime, model, handling, save schema, service or renderer setting is changed.

Pinned official Godot 4.7.2 `ed1daf0bf`, Windows, RTX 3090, OpenGL Compatibility, 1280×720, Dummy audio and music disabled. Each native probe runs sequentially with private APPDATA/LOCALAPPDATA and an explicitly disabled backend. Empty application caches do not mean a purged OS/driver shader cache or a first-install release build. Other workspace work continued; these are individual local debug-engine observations, not an uncontended statistical benchmark. No Android/device test, export, deployment, owner-save edit or owner-process action was performed. Live sign-in, downloads, tickets and Daily/Rivalry service latency are outside these offline timings. Desert, Winter, fitted and premium-livery matrices were not profiled in this review.

The first two live-tree attempts are retained as rejected controls: concurrent App/editor changes occurred, and the requested disk-hit run failed three cache-hit assertions. The independent 36,929-file copy initially detected concurrent files; changed files were recopied and byte checked before stable measurements. Instrumentation only adds timestamp markers to private runtime copies and captures existing counters. An ambiguous original instrumentation anchor was rejected before writes; it was corrected to a unique anchor.

Raw metrics, source fences, commands, private-copy instrumentation originals and the machine-readable summary are under [the evidence directory](evidence/loading-review-2026-11-17/). `scripts/review_loading_2026_11_17.py` prepares/reconciles the private project and runs existing probes. `scripts/instrument_loading_review_2026_11_17.py` installs the private timestamp observers. `game/tests/review_startup_2026_11_17.gd` measures the current startup path without preloading game classes. Executed commands are retained in individual process and receipt files. The exact measured script sources are archived separately from the disposable snapshot.

Automatic approval review rejected the task-folder deletion command as blocked by policy. The standard `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply` run succeeded: 27.97 GiB before/after, zero entries removed. Recent/protected/locked output, including this review's independent snapshot and private profiles, remains under standard retention. No new permanent build pin was created. The four-file task-source checkpoint is bundled and byte verified without changing the shared index.
