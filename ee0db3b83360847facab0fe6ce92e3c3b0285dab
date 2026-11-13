# Game profiling — 12 November 2026

Measured local debug-engine behavior on the current code snapshot. This is a profiling review; production game code, handling, quality defaults and player saves were not edited.

First-use loading and frame stalls dominate this desktop profile. Final copied-asset results:

| Workload | First use / throughput | Repeat / pacing |
| --- | --- | --- |
| Startup | 5.45 s | 4.59 s after process restart |
| gl / rivalry | 22.83 s first entry | 142 ms repeat |
| gl / garage | 1.74 s first entry | 365 ms repeat |
| gl / create | 17.74 s first entry | 709 ms repeat |
| gl / race loading | 31.8–71.1 s first entry | 0.54–1.00 s repeat |
| mobile / rivalry | 11.86 s first entry | 120 ms repeat |
| mobile / garage | 0.97 s first entry | 361 ms repeat |
| mobile / create | 4.12 s first entry | 575 ms repeat |
| mobile / race loading | 20.0–32.0 s first entry | 1.03–1.30 s repeat |
| Vulkan / matched driving | 188–241 FPS | p95 frame 5.18–6.54 ms |

Requirements: PRF01 startup; PRF02 menu loading and navigation; PRF03 race loading and retry; PRF04 real driving frame times; PRF05 track editor; PRF06 reproducibility and limitations.

## Measurement conditions

Windows build 26300; Intel Core i7-11700K, 16 logical CPUs; NVIDIA RTX 3090. Pinned official Godot 4.7.2 (`ed1daf0bf`), 1280×720 native rendered windows positioned outside the desktop. Compatibility uses OpenGL; desktop Mobile uses Vulkan. Processes run sequentially. Private APPDATA/LOCALAPPDATA, explicit empty backend URL, offline race fixtures, Dummy audio driver and music disabled. Driving uses uncapped frame rate, disabled VSync, normal Auto graphics, stock approved simpler car models, real AI simulation, a complete countdown, two seconds of warmup and ten seconds of sampling per case. FPS is measured frame-loop throughput, not a physical-display presentation trace.

Cold means first use in a fresh profiling process/private application profile, with existing project imports and OS/driver caches. It is not a disk-cache purge or first install. Restart startup reuses its private profile. Warm page entries and race re-entries occur in the same process. Raw timing includes rendered completion where the probe supports it; race loading excludes the three-second countdown and the separately recorded track compilation. Menu ready times include navigation settling, which can exceed first draw.

The drive initially had about 345 MiB free after an unsuccessful full-copy attempt. Exploratory code/native libraries were copied while assets were first shared by junction and then NTFS hardlinks; concurrent in-place asset writes remained visible. Later, free space recovered and all 25,378 asset/import/identity files were copied and checked with zero copy-time changes. Final `-final` / `-qualified` runs use private assets and imports, with before/after SHA-256 receipts. Other workspace work was active and its processes were not stopped. These are local debug-engine diagnostics, not an uncontended release benchmark or Android qualification.

## Startup

| Run | Engine to drawn menu (s) | App graph load (ms) | App initialization (ms) | Offline |
| --- | --- | --- | --- | --- |
| startup-cold | 5.184 | 2016.1 | 173.0 | True |
| startup-isolated-cold | 6.513 | 2497.1 | 205.0 | True |
| startup-isolated-repeat | 5.508 | 2600.7 | 260.2 | True |
| startup-final-cold | 6.826 | 2488.4 | 237.9 | True |
| startup-final-repeat | 5.337 | 2391.7 | 193.5 | True |
| startup-frozen-cold | 5.451 | 2065.0 | 184.2 | True |
| startup-frozen-repeat | 4.592 | 2046.9 | 192.7 | True |

The account menu is the ordinary unsigned-in startup destination. These startup probes deliberately avoid parsing the heavy game graph before loading App. The first live run and initial shared-asset snapshot runs have concurrency changes in their receipts; retain them as observations, not stable-build comparisons.

## Menu loading

### gl — 39 checks, 0 failures

| Page | First ready (s) | Repeat ready (ms) | First worst frame (ms) | Repeat worst frame (ms) |
| --- | --- | --- | --- | --- |
| rivalry | 22.830 | 142.2 | 13080.6 | 56.8 |
| daily | 0.611 | 90.9 | 592.6 | 80.6 |
| tracks | 0.946 | 82.7 | 905.1 | 76.3 |
| challenges | 1.222 | 124.2 | 716.0 | 118.3 |
| biome | 0.310 | 396.7 | 48.6 | 41.1 |
| drafts | 1.410 | 51.8 | 1316.6 | 42.2 |
| profile | 2.836 | 57.6 | 2295.3 | 48.1 |
| settings | 3.470 | 74.2 | 1452.2 | 62.3 |
| store | 0.308 | 456.4 | 56.7 | 87.8 |
| garage | 1.745 | 365.0 | 953.9 | 59.4 |
| create | 17.742 | 709.3 | 8757.4 | 106.7 |

First feature resource loads (ms): challenges.gd 567.4; creator.gd 64.4; daily.gd 460.7; editor.gd 1184.0; garage.gd 836.4; rivalry.gd 2365.7; settings.gd 473.0; tracks.gd 763.4.

### mobile — 39 checks, 0 failures

| Page | First ready (s) | Repeat ready (ms) | First worst frame (ms) | Repeat worst frame (ms) |
| --- | --- | --- | --- | --- |
| rivalry | 11.856 | 120.3 | 4076.3 | 50.2 |
| daily | 0.325 | 69.5 | 314.2 | 64.5 |
| tracks | 0.588 | 62.8 | 519.9 | 60.2 |
| challenges | 0.559 | 108.9 | 537.9 | 106.4 |
| biome | 0.309 | 392.1 | 40.3 | 39.0 |
| drafts | 1.140 | 63.4 | 1056.6 | 52.3 |
| profile | 0.212 | 38.1 | 176.7 | 35.1 |
| settings | 0.391 | 56.8 | 370.6 | 53.8 |
| store | 0.273 | 423.2 | 39.8 | 88.4 |
| garage | 0.968 | 361.1 | 746.8 | 46.5 |
| create | 4.123 | 575.4 | 2627.9 | 93.1 |

First feature resource loads (ms): challenges.gd 408.4; creator.gd 66.0; daily.gd 254.7; editor.gd 955.2; garage.gd 652.4; rivalry.gd 2387.1; settings.gd 303.5; tracks.gd 427.7.

### Actual navigation with saved custom liveries

This separate scenario invokes `_navigate_menu_page`, including neighbor promotion and background preparation, and samples 80 frames per action. Its preloaded App graph means it is not another startup benchmark.

| Destination | Handler (ms) | p95 frame (ms) | Worst frame (ms) | Frames >50 ms |
| --- | --- | --- | --- | --- |
| tracks | 477.92 | 1295.76 | 3656.95 | 17 |
| biome | 1.41 | 8.48 | 10.67 | 0 |
| garage | 3355.04 | 20.11 | 47.02 | 0 |
| tracks | 1.40 | 25.10 | 2691.59 | 3 |
| store | 23.01 | 30.76 | 2892.92 | 3 |
| biome | 1.04 | 26.04 | 327.71 | 2 |
| garage | 5.37 | 1139.14 | 1237.93 | 25 |
| settings | 407.18 | 21.53 | 137.99 | 2 |
| tracks | 3.96 | 8.41 | 33.84 | 0 |
| garage | 1.65 | 8.41 | 13.47 | 0 |

## Race loading

The Star spline circuit is the larger loading workload; Grass, Desert and Winter each have a first load and same-process re-entry. The original installation, full countdown, five-lap rules, cover-release and retry-reuse assertions remain in the probe. This is offline preparation; network tickets, downloads and verification latency are excluded.

### gl — 53 checks, 0 failures

| Biome | Entry | Load (s) | Worst frame (ms) | Retry (ms) | Compile before entry (ms) |
| --- | --- | --- | --- | --- | --- |
| pine | first | 71.060 | 8939.6 | 18.3 | 361.8 |
| pine | repeat | 0.541 | 163.3 | 19.4 | 361.8 |
| desert | first | 31.817 | 2338.0 | 17.1 | 380.5 |
| desert | repeat | 0.998 | 172.3 | 18.7 | 380.5 |
| winter | first | 38.545 | 4991.2 | 18.8 | 782.8 |
| winter | repeat | 0.810 | 217.7 | 16.7 | 782.8 |

| Biome | Cycle | Road preparation (ms) | Game construction (ms) | Covered world graphics (ms) | Effects/final finish (ms) |
| --- | --- | --- | --- | --- | --- |
| pine | 0 | 6371.9 | 9609.4 | 41601.7 | 11815.6 |
| pine | 1 | 0.0 | 172.2 | 62.9 | 241.3 |
| desert | 0 | 10688.9 | 9218.3 | 11740.7 | 103.9 |
| desert | 1 | 0.0 | 592.2 | 86.2 | 255.6 |
| winter | 0 | 4690.3 | 9932.6 | 17039.6 | 6807.2 |
| winter | 1 | 0.0 | 322.9 | 71.5 | 350.6 |

Phase hooks are timestamps in an in-memory copy of the shipping controller. They do not modify the production source. Covered graphics and final effects include rendering waits and possible compilation; they are not pure CPU timings.

### mobile — 53 checks, 0 failures

| Biome | Entry | Load (s) | Worst frame (ms) | Retry (ms) | Compile before entry (ms) |
| --- | --- | --- | --- | --- | --- |
| pine | first | 32.004 | 4247.2 | 18.6 | 387.6 |
| pine | repeat | 1.037 | 382.5 | 22.7 | 387.6 |
| desert | first | 27.975 | 3524.9 | 21.7 | 398.4 |
| desert | repeat | 1.300 | 245.5 | 20.6 | 398.4 |
| winter | first | 20.032 | 3111.7 | 22.5 | 842.8 |
| winter | repeat | 1.030 | 178.1 | 20.2 | 842.8 |

| Biome | Cycle | Road preparation (ms) | Game construction (ms) | Covered world graphics (ms) | Effects/final finish (ms) |
| --- | --- | --- | --- | --- | --- |
| pine | 0 | 7032.6 | 17510.8 | 1734.1 | 4056.7 |
| pine | 1 | 0.0 | 773.6 | 53.2 | 148.8 |
| desert | 0 | 12194.1 | 11715.4 | 3854.1 | 150.5 |
| desert | 1 | 0.0 | 1003.9 | 80.8 | 144.4 |
| winter | 0 | 5042.7 | 11053.7 | 3552.8 | 311.2 |
| winter | 1 | 0.0 | 737.7 | 66.1 | 172.8 |

Phase hooks are timestamps in an in-memory copy of the shipping controller. They do not modify the production source. Covered graphics and final effects include rendering waits and possible compilation; they are not pure CPU timings.

## Driving FPS and frame pacing

The verified oval is a separate, smaller gameplay workload. Every biome uses Rally; the other five cars are sampled on Grass. These broad matrices are exploratory runs that overlapped asset writes and disk housekeeping; the three final cache-matched driving checks appear below. Renderer ranges are observations, not a controlled renderer speedup comparison. The short samples cover opening driving segments, not full laps or all high-speed/contact/effect cases. Per-frame script counter costs are averages across rendered frames and include AI driving; CPU, render and GPU times overlap and must not be added together. The existing broad car/presentation timer spans several nested audio/weathering/contact tasks, so those counter values also overlap. A tick-progress guard requires at least 90% of elapsed-time simulation progress; rows with failures are not qualified as real-time driving. No FPS is inferred from headless execution.

### gl — 0 progress failures

| Car / biome | FPS | p50 / p95 / p99 (ms) | Worst (ms) | Frames >33.3 ms | GPU p95 (ms) | Simulated ticks |
| --- | --- | --- | --- | --- | --- | --- |
| compact / pine | 160.1 | 6.32 / 7.75 / 8.72 | 10.02 | 0 | 2.43 | 1201 |
| compact / desert | 171.9 | 5.53 / 8.93 / 11.21 | 16.77 | 0 | 1.95 | 1200 |
| compact / winter | 176.0 | 5.63 / 7.55 / 8.30 | 10.27 | 0 | 2.21 | 1201 |
| compact / storm | 126.5 | 7.90 / 9.75 / 10.66 | 12.74 | 0 | 2.90 | 1199 |
| compact / night_city | 171.0 | 5.81 / 7.53 / 8.30 | 9.41 | 0 | 2.36 | 1200 |
| kart / pine | 227.2 | 4.29 / 6.04 / 7.15 | 8.89 | 0 | 1.78 | 1201 |
| super_rally / pine | 200.0 | 4.91 / 6.72 / 7.36 | 8.96 | 0 | 1.93 | 1200 |
| electric / pine | 167.1 | 6.01 / 7.86 / 9.07 | 11.51 | 0 | 2.24 | 1200 |
| forklift / pine | 191.2 | 5.17 / 7.26 / 8.30 | 10.48 | 0 | 2.04 | 1201 |
| hovercraft / pine | 263.4 | 3.67 / 5.42 / 6.00 | 8.14 | 0 | 1.75 | 1200 |

| Car / biome | Physics callback ms/frame | Presentation callback ms/frame | Simulation ms/frame | AI ms/frame | Godot static MiB | Reported video MiB |
| --- | --- | --- | --- | --- | --- | --- |
| compact / pine | 0.792 | 1.069 | 0.423 | 0.037 | 216.9 | 282.7 |
| compact / desert | 0.693 | 1.009 | 0.353 | 0.031 | 213.3 | 289.8 |
| compact / winter | 0.722 | 1.084 | 0.376 | 0.028 | 235.1 | 293.2 |
| compact / storm | 0.958 | 1.352 | 0.493 | 0.045 | 233.9 | 295.8 |
| compact / night_city | 0.648 | 0.901 | 0.343 | 0.032 | 214.2 | 300.9 |
| kart / pine | 0.425 | 0.816 | 0.223 | 0.020 | 216.6 | 301.7 |
| super_rally / pine | 0.542 | 0.874 | 0.288 | 0.026 | 217.6 | 303.5 |
| electric / pine | 0.751 | 1.342 | 0.419 | 0.036 | 219.2 | 303.9 |
| forklift / pine | 0.574 | 0.922 | 0.296 | 0.028 | 222.7 | 305.7 |
| hovercraft / pine | 0.265 | 0.756 | 0.152 | 0.017 | 222.8 | 305.4 |

Static allocation and video-memory monitors are not process RSS or Android PSS. Ten-second samples do not measure long-run memory drift, battery use, thermal throttling or all track/effect combinations. Native gameplay screenshots accompany the rows.

### mobile — 0 progress failures

| Car / biome | FPS | p50 / p95 / p99 (ms) | Worst (ms) | Frames >33.3 ms | GPU p95 (ms) | Simulated ticks |
| --- | --- | --- | --- | --- | --- | --- |
| compact / pine | 454.1 | 2.11 / 3.30 / 3.91 | 5.14 | 0 | 0.38 | 1201 |
| compact / desert | 480.0 | 2.00 / 3.13 / 3.75 | 5.09 | 0 | 0.37 | 1200 |
| compact / winter | 369.4 | 2.59 / 4.04 / 4.82 | 17.98 | 0 | 0.42 | 1200 |
| compact / storm | 301.2 | 3.19 / 4.80 / 5.61 | 8.91 | 0 | 1.08 | 1200 |
| compact / night_city | 439.3 | 2.15 / 3.55 / 4.26 | 20.86 | 0 | 0.40 | 1200 |
| kart / pine | 555.1 | 1.70 / 2.68 / 3.27 | 4.71 | 0 | 0.33 | 1199 |
| super_rally / pine | 436.7 | 2.16 / 3.69 / 4.46 | 8.33 | 0 | 0.42 | 1200 |
| electric / pine | 381.0 | 2.49 / 4.04 / 4.73 | 5.84 | 0 | 0.44 | 1201 |
| forklift / pine | 485.9 | 1.94 / 3.14 / 3.80 | 6.15 | 0 | 0.33 | 1200 |
| hovercraft / pine | 416.9 | 2.29 / 3.64 / 4.22 | 5.79 | 0 | 0.42 | 1202 |

| Car / biome | Physics callback ms/frame | Presentation callback ms/frame | Simulation ms/frame | AI ms/frame | Godot static MiB | Reported video MiB |
| --- | --- | --- | --- | --- | --- | --- |
| compact / pine | 0.194 | 0.666 | 0.104 | 0.010 | 245.5 | 260.0 |
| compact / desert | 0.179 | 0.637 | 0.090 | 0.009 | 259.5 | 268.4 |
| compact / winter | 0.283 | 0.809 | 0.147 | 0.012 | 286.0 | 278.3 |
| compact / storm | 0.300 | 0.888 | 0.156 | 0.015 | 300.0 | 281.7 |
| compact / night_city | 0.200 | 0.651 | 0.106 | 0.010 | 284.2 | 285.6 |
| kart / pine | 0.137 | 0.579 | 0.071 | 0.007 | 287.1 | 286.3 |
| super_rally / pine | 0.209 | 0.675 | 0.111 | 0.010 | 288.1 | 288.3 |
| electric / pine | 0.257 | 0.973 | 0.142 | 0.013 | 290.3 | 290.0 |
| forklift / pine | 0.168 | 0.634 | 0.085 | 0.009 | 294.0 | 290.5 |
| hovercraft / pine | 0.174 | 0.749 | 0.100 | 0.012 | 294.4 | 291.7 |

Static allocation and video-memory monitors are not process RSS or Android PSS. Ten-second samples do not measure long-run memory drift, battery use, thermal throttling or all track/effect combinations. Native gameplay screenshots accompany the rows.

## Track editor

### gl — 60 checks, 0 failures

| Operation | Time (ms) | Worst observed frame/event-to-frame (ms) |
| --- | --- | --- |
| open pine 96 roads / 0 objects | 25124.2 | 6867.6 |
| 96_width_settle | 4562.6 | — |
| drag_width_preview_120 handler p95 | 0.83 | 41.1 |
| practice_enter_0 | 37589.6 | — |
| practice_return_0 | 20.2 | — |
| practice_enter_1 | 3939.2 | — |
| practice_return_1 | 21.2 | — |
| open pine 96 roads / 95 objects | 8229.2 | 1611.8 |
| open winter 2 roads / 0 objects | 15458.1 | 8338.0 |

### mobile — 60 checks, 0 failures

| Operation | Time (ms) | Worst observed frame/event-to-frame (ms) |
| --- | --- | --- |
| open pine 96 roads / 0 objects | 14244.7 | 3779.6 |
| 96_width_settle | 5864.7 | — |
| drag_width_preview_120 handler p95 | 0.86 | 42.8 |
| practice_enter_0 | 14887.2 | — |
| practice_return_0 | 17.9 | — |
| practice_enter_1 | 3310.1 | — |
| practice_return_1 | 20.2 | — |
| open pine 96 roads / 95 objects | 7633.8 | 329.1 |
| open winter 2 roads / 0 objects | 5423.7 | 3124.2 |

The editor workload includes a 96-road circuit, width editing, 120 synthetic drag updates, undo/redo, two practice entries/returns, 95 authored sheds, overview/detail rendering and Winter surface changes. It retains the original scene-identity, authored-data, history, ownership and cancellation assertions. Synthetic event-to-frame time is not physical touch latency. This refers to the game's track editor; the Godot IDE was not profiled.

## Prepared-asset qualification and corrected measurements

Preliminary runs overlapped in-place asset rebuilds. A live-versus-snapshot source comparison found only the generated build identity and an offline baking test had changed. The old generated cache revisions could reject newly rebuilt prepared scenes even though authored runtime geometry sources matched. Thus the early Vulkan repeat-car/practice times are observations of a stale development cache, not evidence of a general renderer regression. The initial identity and the snapshot-only refresh receipt are preserved. Once space became available, all runtime assets were detached from hardlinks into private copies, imported resources were copied and their verified junction was removed, and snapshot identity/project version were refreshed together. The final loading/menu/editor passes use that complete private copy. No live source or asset was changed by these adaptations.

| Car | Prepared key matches | Authored source hashes match | Different source paths |
| --- | --- | --- | --- |
| compact | True | True |  |
| kart | True | True |  |
| forklift | True | True |  |
| electric | True | True |  |
| hovercraft | True | True |  |
| super_rally | True | True |  |

Cache-matched driving cross-check (same uncapped 720p workload):

| Car / biome | FPS | p95 frame (ms) | Modular base cache hits during load | Progress failures |
| --- | --- | --- | --- | --- |
| compact / pine | 240.9 | 5.18 | 1 | 0 |
| compact / winter | 188.0 | 6.54 | 1 | 0 |
| kart / pine | 225.1 | 5.70 | 1 | 0 |

## Findings and next work

First-use work and frame stalls should be investigated before assuming steady driving FPS is the primary problem. The measurements separate script/dependency loading, construction, covered rendering and final effects. Rivalry's feature graph alone takes seconds, while its much longer first frame indicates additional first-render cost. Garage spends many seconds reaching a prepared showroom even after its feature script has loaded. Race re-entry and retry already benefit strongly from retained state. Warm navigation still has isolated frames above a 60 Hz budget; the actual-navigation scenario distinguishes retained-neighbor behavior from direct page construction. These are measured priorities and source-based hypotheses, not implemented optimizations.

## Validation, retained failures and limits

The initial full snapshot failed with no disk space; only that task-owned incomplete copy was removed. Hardware WMI reads were denied; CPU identification came from the read-only Windows processor registry and the renderer identified the GPU. The initial gameplay fixture omitted the offline fixture's required published-track marker, so no game was installed and that run exited 1. The initial editor fixture inherited a synchronous page-open helper that no longer waited for lazy feature loading; it logged script errors and was rejected. The dedicated probe adapters were corrected without changing runtime code or weakening the original assertions. Initial failed receipts remain alongside corrected runs.

All native runs retain the sandbox's root-certificate-store diagnostic. Online configuration was explicitly disabled, so the report does not claim TLS or online-path validation. Other shutdown/resource diagnostics are listed verbatim in each receipt and must not be read as clean exits merely because a measurement file exists. Source/asset guard changes cause a nonzero runner status even when functional assertions pass. Initial menu/race runs overlap external asset writes; the full receipts identify every changed path. The report does not claim one immutable binary build or a whole-tree release gate.

The first frozen Vulkan menu pass exposed another stale profiler assumption: an adopted `garage_preloaded_studio.gd` has `prepared`/`warming` fields, rather than the cooperative showroom's `preparing` field. That pass logged script errors and was rejected. The dedicated menu adapter retains the original cover/readiness checks for both studio types. Sandboxed termination of that owned failed test was denied; automatic approval review allowed termination of only its recorded process tree, and cleanup succeeded. Later runner code stops the sequence if owned-process cleanup is denied.

| Run | Engine exit | Changed files | Distinct diagnostics | Wall seconds |
| --- | --- | --- | --- | --- |
| assets-final | 0 | 1 | 1 | 14.906 |
| assets-qualified | 0 | 0 | 1 | 12.359 |
| driving-gl | 1 | 1 | 3 | 14.922 |
| driving-gl-fixed | 0 | 598 | 1 | 324.39 |
| driving-mobile | 0 | 322 | 1 | 220.86 |
| driving-mobile-qualified | 0 | 0 | 1 | 112.015 |
| editor-gl | 125 | 2 | 4 | 18.203 |
| editor-gl-fixed | 0 | 5 | 1 | 138.141 |
| editor-mobile | 0 | 38 | 1 | 103.453 |
| editor-mobile-final | 0 | 0 | 1 | 94.875 |
| menus-gl | 0 | 114 | 1 | 70.344 |
| menus-gl-final | 0 | 0 | 1 | 98.062 |
| menus-mobile | 0 | 5 | 1 | 56.625 |
| menus-mobile-final | 125 | 0 | 3 | 225.922 |
| menus-mobile-final-fixed | 0 | 0 | 1 | 39.859 |
| navigation-gl | 0 | 14 | 1 | 70.485 |
| races-gl | 0 | 27 | 1 | 111.25 |
| races-gl-final | 0 | 0 | 1 | 175.75 |
| races-mobile | 0 | 26 | 1 | 155.343 |
| races-mobile-final | 0 | 0 | 1 | 133.032 |
| startup-cold | 0 | 2 | 1 | 12.203 |
| startup-final-cold | 0 | 1 | 1 | 17.172 |
| startup-final-repeat | 0 | 1 | 1 | 14.515 |
| startup-frozen-cold | 0 | 0 | 1 | 12.687 |
| startup-frozen-repeat | 0 | 0 | 1 | 12.0 |
| startup-isolated-cold | 0 | 49 | 1 | 17.156 |
| startup-isolated-repeat | 0 | 45 | 1 | 15.406 |

No physical device was queried or tested. No APK/export, deployment, backend request, owner save/process change, main-index write or physics change was performed. Remaining qualification: uncontended stable-asset repetitions with more free disk space, packed release measurements, signed-in data/network cases, representative saved/fitted cars and large tracks, physical-device frame-time/thermal/memory runs and owner interaction review.

## Files and reproduction

New source: `scripts/prepare_game_profile.py`, `scripts/profile_game_overview.py`, `scripts/profile_game_suite.py`, `scripts/summarize_game_profile.py`, `game/tests/profile_overview_driving.gd`, and `game/tests/profile_overview_editor.gd`. The runner invokes `scripts/run_no_crash_dialog.py` for automated Godot process trees, pins `godot-version.txt`, bounds each process, retains raw logs/commands/hashes, and cleans only its completed private shader cache. Existing production scripts and existing regression fixtures were not edited.

Additional source: `scripts/freeze_game_profile_assets.py`, `scripts/profile_game_final_suite.py`, `game/tests/profile_overview_assets.gd` and `game/tests/profile_overview_menus.gd`. Disk-pressure housekeeping is recorded in `maintenance.json`; only task-owned copied files, evidence and private shader caches were compressed/cleaned. That housekeeping and external writers overlapped exploratory samples and are additional reasons not to treat the exploratory renderer comparison as uncontended. Final cache-matched passes are labeled with `-final` or `-qualified`; earlier raw results remain available.

Raw results and exact commands: [evidence directory](evidence/game-profile-2026-11-12/), especially `*-receipt.json`, `*-process.json`, `*-sources.json`, `*-metrics.json`, native capture folders, `environment.json`, `snapshot-manifest.json` and `frozen-assets.json`. The combined machine-readable result is [summary.json](evidence/game-profile-2026-11-12/summary.json). The task's new source/report delta is reviewable in [source-only.patch](evidence/game-profile-2026-11-12/source-only.patch), with hashes and reverse-apply validation in `source-checkpoint.json`. Commands actually executed are listed in the receipts, including any `--themes`, `--cycles`, `--renderer`, profile reuse and navigation-output arguments. Re-run one probe through `python scripts/profile_game_overview.py NAME res://tests/PROBE.gd --renderer gl_compatibility`; use `mobile` for desktop Vulkan. Startup pairs must share `--profile NAME`. Prepare a fresh verified snapshot before reproduction; the retained snapshot contains the measured runtime sources.
