# Game performance audit — 30 October 2026

This is a focused improvement and investigation of the current workspace, not a certification that the whole game sustains 60 FPS. No Android device was tested in this pass. The separate historical results linked below apply to their own snapshots and workloads. The new component measurements are not frame-rate measurements.

## Configuration and existing evidence

The pinned engine is Godot 4.7.2. The project selects Compatibility on desktop and mobile, 120 physics ticks/s, 2× 3D MSAA, 1024 directional shadows, ETC2/ASTC import and a 0.667 mobile 3D scale. Runtime settings further constrain Night and the mobile world pixel budget; UI remains at window resolution. The Android preset uses Gradle, min SDK 24 and ARM64/x86-64. These facts alone do not establish a GPU bottleneck or imply that a different renderer would be faster.

Race simulation and presentation are separate: `Game._physics_process` advances the fixed-step simulation; `Game._process` handles presentation. Pause and application focus transitions are handled explicitly. The editor, Garage and networking have their own lifecycle and work gates. Previous work already batches scenery and trails, bounds prepared-world caches, avoids inactive Garage viewport updates and defers optional race work. See [race-work measurements](DEVICE_PERFORMANCE_RACE_WORK_2026_10_27.md), [biome work](BIOME_PERFORMANCE_FOLLOWUP_2026_10_13.md) and [editor findings](TRACK_EDITOR_FIXES_2026_10_28.md).

| Area | Evidence and priority | Status |
| --- | --- | --- |
| Cold shader and race preparation | High priority, confirmed on an earlier desktop snapshot: 5.116 s of a 5.207 s frame overlapped driver compilation/linking. An experimental worker exceeded its memory gate and did not eliminate first-draw stalls. | Open; see [cold shader follow-up](COLD_SHADER_FOLLOWUP_2026_10_30.md). Do not infer Android timing from it. |
| Complex editor preparation | High priority, confirmed on an earlier desktop snapshot: width completion 4.949 s and cold practice 26.968 s; reduced work counts did not establish an end-to-end gain. | Open; see [editor report](TRACK_EDITOR_FIXES_2026_10_28.md). |
| Garage cold loading and car switching | High priority, desktop observations and prior device tests show substantial preparation stalls, even when navigation is covered. | Open; see [Garage navigation](GARAGE_NAVIGATION_PERFORMANCE_2026_10_30.md) and [device report](DEVICE_PERFORMANCE_RACE_WORK_2026_10_27.md). |
| GPU effects and five biomes | Potentially high, workload/device dependent. Existing paired desktop Winter/Desert material tests show savings and near-identical pixels, but neither establishes current phone bottlenecks. Storm transparency, Night lights, vegetation and particles need device GPU attribution. | Profile before adjusting quality; see [biome measurements](BIOME_PERFORMANCE_2026_10_13.md). |
| Race networking and inactive UI | Earlier isolated real-App measurements found optional traffic and background work suppressed in the observed active race; pending recovery paths also need their documented lifecycle guarantees. | Existing gates retained; not a current production traffic measurement. |
| Repeated transitions and memory | Bounded caches and lifecycle checks exist, but sampled memory does not prove a long-session plateau or peak PSS on low-memory devices. | Open: repeated real-device cycles and pressure/foreground tests. |

Historical physical measurements illustrate why device and frame-boundary details matter. The 25 October OnePlus DN2103 Desert experiment measured 59.39–59.41 FPS with engine frame p95 20.969–20.990 ms in two 25-second windows after its changes; the earlier baseline was about 43 FPS. Its separate SurfaceFlinger observations differ in boundary. The 27 October OPD2403 experiment observed a 50 Hz display and p95 approximately 20 ms over sampled presentation intervals. Neither result represents this current tree, sustained thermal behavior, every track or the requested mid-range device population. See [Desert phone report](DESERT_PHONE_PERFORMANCE_2026_10_25.md) and [device report](DEVICE_PERFORMANCE_RACE_WORK_2026_10_27.md).

## Changes and current measurements

| Component | Finding and resolution | Priority / expected impact |
| --- | --- | --- |
| Editor object overview | Fallback membership lookup scanned every object for each pose and used linear duplicate checks. A lazily built spatial index selects nearby candidates, preserves the strict distance check and original result order, and uses a set for deduplication. | High for dense fallback groups; additional temporary index memory. No full-editor latency claim. |
| Tyre-mark presentation | Four wheels repeated the same speed, slip, braking and yaw calculations. Shared values now feed the same per-wheel arithmetic; the scalar API remains for other effects. | Moderate for active trail sampling; a small temporary packed array and duplicated scalar/shared formula require maintenance. No simulation or race timing change. |
| Night barrel effects | Each source recomputed the same parent transform inverse. It is now computed once per update. | Low to moderate with many barrels; no lighting, geometry or simulation change. |

Godot 4.7.2 headless desktop measurements below are component timings under shared machine load. None measures whole-game FPS, GPU time, draw calls, peak memory, loading, Android, power or thermal behavior. Those before/after metrics are **not measured in this pass**.

| Controlled workload | Before | After | Interpretation |
| --- | ---: | ---: | --- |
| Editor fallback, 4,096 objects / 1,026 poses, three alternating runs including index construction | 2,171.819 / 1,942.218 / 1,872.144 ms | 8.496 / 8.460 / 9.475 ms | Ordered matches were exact. This synthetic search is not the whole editor preparation path. |
| Four tyre intensities, 120,000 four-wheel evaluations | 2,133,261 µs | 1,119,575 µs | Approximately 47.5% less in the isolated arithmetic workload, not a frame-rate change. |
| Complete ellipse trail sample, 2,000 positions, median of five sequential runs | 50,106 µs | 47,357 µs | Includes route lookup; cache/order and other system activity affect this non-alternating comparison. All 1,068 deposited mark buffers match. |
| Night, 32 unchanged barrel sources, eight alternating 1,000-call stages | median 81.388 µs/call | median 73.367 µs/call | About 9.9% lower in this noisy presentation component; no GPU conclusion. |

The repeatable comparison sources are [editor lookup](../game/tests/test_editor_detail_position_index.gd), [trail arithmetic](../game/tests/test_trail_intensity_performance.gd), [trail sampling](../game/tests/test_trail_intensity_samples.gd) and [barrel sync](../game/tests/profile_barrel_sync_performance.gd). The editor comparison covers duplicates, cell/radius boundaries, unmatched and repeated poses and seeded dense random inputs. The trail comparison covers 9,600 exact intensity results and complete deposited buffers. No image comparison or phone test was performed for these changes; exact trail data and unchanged barrel transform arithmetic reduce but do not eliminate visual regression risk. Editor selection, unusual authoring layouts and dense scenes still warrant interactive acceptance.

## Validation and limitations

Fresh headless checks: driving 72/0, rewind 61/0, personal ghosts 38/0, gameplay runtime lifecycle 79/0, Night props 103/0, barrel spill 27/0 and editor workflow 899/0, including dense overview selection and practice/return. The exportable-source parser reports 504 scripts, zero failures. The whole-tree scan reports 1,550 scripts and one failure in the previously documented frozen `parking_hall_before/garage_page.gd` fixture, which references a removed method; its dependent fixture also emits a compile diagnostic. The offline Windows runs emitted a root-certificate-store error.

The historical optional `test_performance.gd` trail comparison reports 16 checks and one failed old-fixture mark-buffer assertion. An in-memory reconstruction of the task-start scalar implementation reproduces that same failure; the new exact scalar-control sample comparison passes. `test_soil.gd` reports two failures in forklift and hovercraft maximum-speed roll recovery (164 checks total); those assertions exercise the unchanged simulation. `test_burning_barrel.gd` reports one forklift toppling failure among 56 checks in canonical replay before the changed presentation path. These are not reported as passing or fixed. Further regression and Android acceptance are needed, including the editor workflow, real images, touch, collisions, lap timing, ghosts and sustained memory/thermal behavior.

For a repeatable headless run, set `APPDATA` to a separate directory under `build`, set `BMT_API_URL` to an empty string, then execute `python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/<test>.gd`. Use fresh task-specific directories for independent runs. The crash-dialog wrapper preserves the process exit status; it does not turn a crash into a pass.

## Ranked follow-up

| Rank | Investigation | Expected benefit / complexity |
| --- | --- | --- |
| 1 | Attribute cold shader compilation and first real draw on target Android hardware; assess an isolated engine experiment against the existing memory and first-use gates. | Potentially large loading and hitch improvement; high complexity and renderer/driver risk. |
| 2 | Profile editor width update and cold practice by stage on the current tree, then bound or reuse the dominant exact work. | Potentially large creator latency improvement; high complexity, with cancellation and track compatibility requirements. |
| 3 | Measure all five biomes and dense custom tracks on representative phones, with CPU/GPU attribution and matched visual controls. Investigate only measured hot effects and overdraw. | Potentially large sustained frame benefit; medium/high complexity and art-fidelity risk. |
| 4 | Measure repeated races, track swaps and Garage navigation through pressure, background and foreground, including PSS, peak memory and long-session thermal state. | Potentially large stability benefit; medium/high measurement effort; no leak established by current checks. |
| 5 | Measure menu and background callbacks, including result-save retry polling, before replacing periodic work with event-driven wakeups. | Possible small CPU/battery savings; low/medium complexity, but retries must remain reliable. |

## Repeatable measurement plan

Use a private, offline probe build and isolated records, never the owner's account or save. Pin source revision, engine/templates, device model, Android version, renderer/driver, resolution, refresh mode, graphics settings, car, track content hash, input stream, thermal state and cold/warm cache state. Alternate before and after runs under comparable conditions; preserve raw samples and failed runs. Do not clear the owner's data. Device testing and installation were not performed in this pass.

1. Run a simple one-car track and a dense user-created track using a reproducible input stream, then repeat with a ghost; verify movement, lap state and exact replay separately.
2. Exercise all five biomes with matched camera and route. Identify the worst GPU case from device timings rather than assuming Storm is always worst. Record draw calls and GPU time with a supported device profiler, plus screenshots and first-use hitches.
3. Record cold launch, first track, repeated restarts, alternating tracks, Garage/menu navigation and editor return. Distinguish callback time, first drawn frame and actual presentation. Collect memory over repeated cycles and after teardown/pressure, including Android PSS; samples alone may miss peaks.
4. Run a complex editing workload with fixed document and gestures, including width, objects, undo/redo and practice. Measure handler, preparation, first draw and cancellation separately.
5. Repeat on representative low/mid/high Android hardware, both debug and release as appropriate, including refresh-rate changes, touch, background/foreground and a long unplugged thermal/battery session. Record thermal throttling and energy independently; USB battery temperature is not an energy measurement.

For each steady-state window retain all frame intervals, sample count, duration, average FPS, p50/p95/p99 and maximum frame time, 1% low FPS (state the calculation), and counts above frame-budget thresholds. A 60 Hz budget is 16.67 ms per presented frame; a 50 Hz screen has a 20 ms presentation interval. CPU stage timings, GPU timings, draw counts and memory must identify their measurement boundaries and unavailable values rather than being inferred from FPS. Capture cold and warm cases separately. `game/diagnostics/race_hitch_monitor.gd`, the archived [device probe](evidence/device-performance-race-work-2026-10-27/sources/device_performance_probe.gd), `game/tests/profile_repeat_race_load.gd`, and the editor and biome profiles provide starting points; the archived device probe is tied to its original isolated package and needs deliberate adaptation for a new build. The current tools do not by themselves cover the complete matrix or prove thermal and memory acceptance.
