# Race loading: current costs and alternatives — 2026-11-04

Investigation only. RRA01 measures current entry/re-entry/retry; RRA02 attributes remaining work; RRA03 evaluates implementations preserving appearance; RRA04 retains reproducible evidence and a task-only checkpoint. No shipping source, visual, quality setting, physics rule or memory budget was changed.

## Findings

The remaining problem has two substantial parts: native first-use graphics work and CPU preparation of the exact race. Repeated entry is much faster, but cache eviction and Night's local-light preparation still matter. Reducing object detail is not necessary for the proposed work.

This review accounts for changes already present: the deferred App shell, rebuilt prepared cars, shared graphics receipts/adaptive batches, selected Daily/Rivalry preparation, and retention of Winter scenery/sky. It does not recommend implementing those features again. Some of the latter changes are concurrent work, not changes made or certified by this review.

## Current measurements

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows RTX 3090, 1280×720, detailed stock Compact, Dummy audio, explicit offline backend configuration and private profiles. The same Star spline document is compiled separately for Pine, Winter, Desert, Storm and Night, in that order. Each theme gets two entries and two actual App retries. The complete-world cache is explicitly cleared between themes, but other caches are not. These are per-theme first-use observations in a sequence, not five independent cold starts.

Mutable runtime code, prepared scenes and relevant pictures were copied into an owned snapshot. Static content/imports are shared by junction. Every accepted run records unchanged code/scene hashes before and after. OS/driver caches were not erased. Native renderer runs are serial, and neither renderer is a phone measurement.

| Theme | Compatibility first entry | Immediate re-entry | Desktop Mobile first entry | Immediate re-entry |
| --- | ---: | ---: | ---: | ---: |
| Pine | 43.005 s | 0.533 s | 22.813 s | 0.769 s |
| Winter | 22.853 s | 1.326 s | 13.916 s | 2.289 s |
| Desert | 21.776 s | 1.327 s | 18.693 s | 1.176 s |
| Storm | 19.155 s | 0.543 s | 13.579 s | 0.497 s |
| Night | 30.488 s | 1.480 s | 14.768 s | 0.767 s |

Compatibility retries of the existing Game take **11.2–18.0 ms**. They already reuse the prepared race; a new reset architecture is not the priority. Compatibility's largest first-entry frame intervals range from **1.650 to 5.153 seconds**, and immediate re-entry still has **156–176 ms** maxima. Loading completion is not evidence of smooth frames.

The phase probe injects timestamps into in-memory copies of the current App/race controller, preserving its operations and readiness checks. The controller/dependency compilation needed by that instrumentation happens before the entry timer. Track compilation, menu selection dwell, real network requests and process startup are also outside the table. `game.tscn` first resource loading remains inside the entry timer (742 ms in the Compatibility run). The table is therefore a loading-path measurement, not a complete user-tap/launch benchmark. Individual phase durations include scheduling, rendering and yields; they are not pure CPU or GPU samples.

A separate fresh-process resource probe, with no App dependencies in its test script, loads App in **2.114 seconds**, then the race controller in **3.224 seconds**, then `game.tscn` in **0.905 seconds**. The controller is loaded synchronously by App before its own loading-cover logic can run. This is another potential first-action delay: the shell has deferred work, not eliminated it. Actual menu navigation may already have loaded overlapping dependencies, so do not simply add 3.224 seconds to the stage table. A small dependency-free cover entry point and carefully scheduled feature loading would improve first feedback; binary resource staging and further dependency separation can target the cost itself.

### Compatibility phase breakdown

| First entry | Road preparation/wait | Game installation | Staged world graphics | Effects/final preparation |
| --- | ---: | ---: | ---: | ---: |
| Pine | 3.718 s | 7.084 s | 24.144 s | 7.137 s |
| Winter | 2.778 s | 6.497 s | 9.718 s | 3.792 s |
| Desert | 7.207 s | 6.604 s | 7.811 s | 0.099 s |
| Storm | 2.955 s | 6.155 s | 8.666 s | 1.325 s |
| Night | 3.080 s | 6.239 s | 12.958 s | 7.802 s |

The remaining time includes resource loading, overlay draws, transitions between marks and final settling. Desert's cheap first effects phase benefits from earlier themes; its slower repeated effects phase below is not contradictory.

## Specific remaining costs

### 1. First-use graphics remain dominant

Pine spends **31.281 seconds**, approximately **73%** of its measured entry, in world graphics plus effects/final preparation. The shared queue reduces warm scheduling overhead, but cannot interrupt a slow driver call or make a previously unseen program free. Existing October native attribution measured compile/link spans covering 98.264% of one 5.207-second Star stall; that is historical native evidence, not a new attribution of every phase in this review. See [the native investigation](NATIVE_SHADER_PREPARATION_2026_10_28.md).

Current `SurfaceShaderVariants` already interns source-equivalent shaders and shares selected Compatibility road roles. Further work should identify the remaining expensive programs and redundant feature combinations, then compare original rendered pixels and driving cost. Replacing all variants with a large generic shader can trade loading time for worse ongoing GPU work; it is not automatically an improvement.

Compatibility requires real in-frustum preparation draws. Godot's ubershader/pipeline-precompilation mechanism applies to Mobile/Forward+, not Compatibility. [Godot 4.7 pipeline documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).

The desktop Mobile rows make a renderer experiment plausible, especially for Night, but Winter re-entry is worse in this sample. They do not establish equal appearance, device compatibility, power use or a universal faster renderer. Retain the present renderer until those are measured.

### 2. Checkpoint-layout construction is a large, precisely identified CPU cost

A separate headless component probe measures **4.956–5.099 seconds** for the initial `TrackSession._configure()` on each of the five themed Star documents. Reuse of its exact cached layout takes **33–51 microseconds**. Pine's first bridge/support preparation adds 0.968 seconds; Desert's relief still takes 0.164 seconds on its repeat. These are component observations, not extra time to add to the native table.

Timestamp-only in-memory instrumentation further measures **4.555 of 5.217 seconds** inside `SplineGateCorridor.select()`:

| Corridor phase | Time |
| --- | ---: |
| Initial lane generation/crossings and corner preparation | 1.127 s |
| Paved/recovery lane and crossing passes | 2.618 s |
| Selecting the ordered gate chain | 0.031 s |
| Notice preparation | 0.779 s |

The instrumented result matches all **159,200 serialized bytes** of the original layout, with 105 gates. The original uninstrumented calculation takes 5.083 seconds in that control. This validates attribution, not a faster implementation.

The best CPU investigation is therefore lane/crossing preparation, rather than the much cheaper final chain selection. Reuse identical intermediate lane geometry and crossings where their exact inputs/widths match, or move the same ordered packed-array arithmetic into the existing native library. Preserve every lane sample, road/kerb coverage, hairpin rule, tie break and floating-point result. An optimization here needs the complete gate-coverage, shortcut rejection and canonical replay controls; reducing samples or widening acceptance would change correctness.

The small result also makes a versioned local compiled-layout artifact attractive. Key it by the complete track/compiler/rules/checkpoint-layout/notice schema and build dependencies, validate it and fall back to the original calculation. Persisting one exact layout can avoid rebuilding it after a process restart. The observed 159 KB is for this one track, not a universal bound or a measured disk-load saving.

### 3. Cache arbitration discards useful effects before freeing larger idle resources

The frozen trace retains Winter's complete world: **41,266,156 estimated bytes**, with a 0.9–1 ms warm scene instantiation in the earlier supporting sample. The old conclusion that every Winter entry loses its world no longer describes this snapshot.

However, ordinary trimming removes all **32** prepared Winter particle proxies before freeing unrelated road resources. The trace falls from **85.41 MiB** retained to **42.31 MiB**. Re-creating the effects brings it to **53.96 MiB**, still under the unchanged 64 MiB allowance. Winter's repeated effects/final phase is **993 ms**; its retained world graphics stage is only **23 ms**. The memory values are policy estimates, not physical RAM/GPU measurements.

In `editor_memory.gd`, effects are trimmed before CPU road data and private road GPU entries. A cost-aware eviction plan should first choose a set of disposable entries that reaches the allowance, then apply it. In this observed Winter state, evicting the large independent road allocation can leave room for the effects as well as the world. Avoid evicting effects and then discovering that a later large eviction leaves enough spare space to have kept them.

Desert is more constrained: after trimming, other retained content is already **61.44 MiB**, and its full effect pool would exceed 64 MiB. Its repeated effects phase is **673 ms**, with zero reused proxies. Prefer a useful subset selected by preparation cost and actual shared-resource footprint; do not assume all effects fit or raise the budget from desktop evidence. Existing pressure handling must still release optional retention.

Immediate re-entry can precede the once-per-second memory sample. Consequently, warm measurements must include a settled menu interval as well as rapid loops. Pool-byte decreases during an active load also include taking leases out of the pool; they are not all evictions. Only trim-counter changes and policy inspection support the eviction finding.

A separate frozen Compatibility run waits **1.5 seconds in the menu** between three entries per theme, retaining ordinary optional-Garage scheduling:

| Theme | First entry | Second entry / reused particles | Third entry / reused particles |
| --- | ---: | ---: | ---: |
| Pine | 45.598 s | 1.011 s / 6 of 20 | 0.862 s / 6 of 20 |
| Winter | 26.804 s | 1.472 s / 0 of 32 | 0.798 s / 32 of 32 |

Pine's trim repeats after every entry. Winter's third entry benefits from the previous eviction of unrelated roads and can keep its effects. These observations confirm sensitivity to cache state; differences between first-entry runs are not an implementation speedup or an isolated measure of Garage contention. The menu wait itself is outside each entry timer.

### 4. CPU work and network readiness are still partly serialized

`selected_track.gd` and `selected_event.gd` now prepare the visible exact Free Race/Daily/Rivalry selection. `selected_track_preparation.run()` builds roads, support and gates in its worker. This is already useful and should be retained.

But `race.gd:run_start_race()` awaits the selected worker before starting the Daily limits read. The same wait also precedes the ordinary ticket/road-overlap section. An unfinished selected job can therefore delay an otherwise independent request. The existing road/ticket overlap is valuable, but does not resolve every selected-job case.

A better structure is one App-owned prepared-race transaction with separate milestones: validated document/identity, CPU layout/road arrays, immutable presentation resources, native graphics readiness, and server authorization. Start independent work as soon as its exact prerequisites exist; join those milestones only before installing/enabling the race. A metadata-only track must first have a trustworthy identity, and every late result must revalidate account, navigation, car, day/week and revision. Never speculate a limited-attempt ticket while browsing. Daily read overlap is a scheduling proposal; no live latency saving was measured here.

### 5. Night needs a distinct optimization strategy

Night re-entry still spends **481 ms** in world staging and **586 ms** in effects/final preparation, with 13 world batches; Pine uses one batch and 34 ms. The shared registry deliberately requires exact mesh/pose/bounds and normal full captures for local lights. Its representative staging cannot safely certify arbitrary point/spot-light combinations.

Investigate retaining exact Night presentation resources and light influence sets, then preparing the actual remaining contexts. Broadening receipts just to reduce batch counts risks first-use stalls later in the lap and incorrect light coverage. Keep clean/weathered finishes, headlamps, actual spatial light combinations and final complete draws.

## Recommended implementation order and alternatives

| Work | What it can improve | Appearance/correctness condition |
| --- | --- | --- |
| Plan cache eviction by cost and shared bytes | Re-entry, particularly the reproduced Winter effect churn | Keep the 64 MiB allowance and existing pressure/lifetime rules; no change to live effects |
| Optimize/cache exact checkpoint-layout preparation | Roughly five seconds of currently measured CPU work when no ready layout exists | Byte-identical layout, complete gate/shortcut/replay controls; unchanged competitive identities |
| Expose preparation milestones and overlap independent reads | Tap-to-ready time when selection preparation is incomplete | Existing identity, expiry, cancellation and attempt boundaries |
| Extend local prepared content to final scenery chunks | Repeated CPU generation, spatial partitioning, decode/upload work | Exact geometry, encoded normals, materials, transforms and LOD behavior; bounded artifacts and fallback |
| Target expensive graphics variants or a supported native preparation service | The largest remaining first-use render stalls | Native exact-image/first-lap proof and bounded workspace; driver first draw remains a separate gate |

The strongest longer-term alternative is an **exact compiled-content pipeline**: prepare immutable track presentation chunks and CPU layout artifacts during authoring/build or a local cache fill; runtime decodes/uploads those artifacts, attaches fresh mutable state, and completes device-specific graphics preparation. Extend the existing road-array, prepared-car and world-cache mechanisms rather than introduce another unrelated cache. Official bundled tracks can be prepared during a build; downloaded tracks need validated numeric artifacts, bounded local storage and the existing procedural fallback. This will not remove shader compilation on a new device.

A full retained Game is less attractive as the first change: retries already do it, while cross-event reuse adds reset/isolation complexity for damage, ghosts, weather, audio and authorization. Streaming scenery after the countdown risks visible pop-in and first-lap stalls. Replacing the loading screen with an image only changes perceived readiness. Neither is a demonstrated solution to the measured work.

A custom native background compiler remains research. The earlier exact-image prototype imported 192 programs, yet retained 221–235 ms first draws and required 162 MiB compiler memory. It did not meet the existing responsiveness/memory gates. Ordinary worker threads also cannot safely own arbitrary active scene/GPU operations. [Godot threading constraints](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html). Threaded resource reads can help prepared binary content, but fetching before completion still blocks; the project's earlier threaded GDScript experiment already had lifecycle failures. [Godot background loading](https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html).

## Reproduction, scope and acceptance

Raw logs, source receipts, the frozen-project manifest and derived tables are in [the evidence directory](evidence/race-loading-reaudit-2026-11-04/) and [summary.json](evidence/race-loading-reaudit-2026-11-04/summary.json). Run serially with new labels to preserve receipts:

```powershell
python docs/evidence/race-loading-reaudit-2026-11-04/prepare_probe.py
python docs/evidence/race-loading-reaudit-2026-11-04/freeze_project.py
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-compat-1 res://tests/review_race_loading_2026_11_04.gd --frozen --themes=pine,winter,desert,storm,night_city --cycles=2 --timeout 600
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-cpu res://tests/review_race_cpu_2026_11_04.gd --frozen --headless --timeout 150
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-mobile-1 res://tests/review_race_loading_2026_11_04.gd --frozen --renderer mobile --themes=pine,winter,desert,storm,night_city --cycles=2 --timeout 600
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-gate-stages res://tests/review_gate_stages_2026_11_04.gd --frozen --headless --timeout 90
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-compat-dwell res://tests/review_race_loading_2026_11_04.gd --frozen --themes=pine,winter --cycles=3 --dwell-ms=1500 --timeout 360
python docs/evidence/race-loading-reaudit-2026-11-04/run_review.py frozen-feature-resources res://tests/review_app_resources_2026_11_02.gd --frozen res://core/app.tscn res://core/features/race.gd res://core/game.tscn --timeout 90
python docs/evidence/race-loading-reaudit-2026-11-04/summarize.py
python docs/evidence/race-loading-reaudit-2026-11-04/checkpoint.py
```

The initial live-workspace Compatibility run has 36/0 checks, but two files changed during it (`prepared_world_cache.gd` and a concurrent Winter test); it is supporting evidence only. Frozen native runs preserve completed preparation, tick zero, all 360 countdown ticks, five laps, cover release and actual retry identity/state. This investigation does not drive a first lap or establish new image equivalence. The existing first-lap and exact-pixel controls remain requirements for implementations, not newly claimed passes.

The three frozen native race runs complete **26 entries and 26 retries**, with **226 checks / 0 failures**. The CPU probe adds **10/0** and the exact-layout instrumentation control **1/0**, for **237/0**. The resource-only observation adds no assertion count. Diagnostic additions to the frozen project between completed runs are recorded in its manifest; each run has no source/scene changes during execution. No performance threshold or production invariant was relaxed.

All engine logs retain the Windows root-certificate-store environment error; no backend URL is configured. Diagnostic-only additions and repository tracking/report updates form this task. The task-only checkpoint excludes concurrent runtime work and does not write the main index. No physical-device query/test, APK/export, owner-save/process change, real authentication, live/backend request, deployment or quality reduction was performed.

Before shipping any proposed optimization: matched first-use and warm controls, identical final visuals across cars/themes/finishes and all lights, real opening laps/countdown, cancellation/account/revision races, memory pressure, packaged loading and representative Android memory/thermal/input measurements remain necessary. No proposed saving is claimed as implemented.
