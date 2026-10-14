# Track loading review, 2026-10-13

Requirements TLR01–TLR05 / Q01 / V04 / V05 / R01 / B07: review actual loading paths, measure cold/repeated costs, identify redundant work/cache opportunities, preserve the recent material preparation fix and canonical contracts, and record reproducible evidence. **Review and diagnostic work only. No production optimization was implemented by this pass.**

The largest opportunities are separating road disk admission from the memory budget, avoiding unused ghost construction, and caching immutable car/particle/audio resources. Prepared scenery restoration itself is already fast. Immediate Race Again already reuses the existing Game node; rebuilding costs below apply to creating/reopening a race scene, not every retry.

## Ranked findings

### 1. Large roads are excluded from disk caching by the memory-admission limit

`game/track/native_track_visual.gd::_remember_road_meshes` estimates resident cost and returns above 32 MiB **before** calling `ROAD_DISK_CACHE.write_entry`. The disk reader/writer also reject `estimated_bytes` above 32 MiB, independently of the compressed file's real size.

On the same Star spline fixture, desert roads estimate **42,442,816 B / 40.5 MiB**, winter **37,675,924 B / 35.9 MiB**. Neither appears in the road memory-cache entries. The same-process full-world cache hides this rejection on an immediate revisit, but process restart or world eviction requires generation again.

A diagnostic generated and saved the identical desert road outside the production cache policy:

| Operation | Observed |
| --- | ---: |
| Generate road | 12,879.084 ms |
| Estimated resident bytes | 42,442,816 |
| Compressed artifact bytes | 3,750,943 (3.6 MiB) |
| Save compressed artifact | 90.527 ms |
| Load artifact | 85.217 ms |

All four meshes round-trip with **exact arrays, transforms, layers, shadow flags, shader source, uniform values and texture bytes**. This is an opportunity demonstrated by a disposable artifact, **not an implemented end-to-end speedup**. First GPU upload/compilation, terrain/scenery and UI/network costs remain additional work.

Recommendation: separate actual serialized-file limits from idle resident-cache admission. Permit bounded, verified, locally generated disk artifacts for roads that are already permitted in an active race, while declining to retain them in the 32 MiB memory LRU. Keep the 96 MiB total disk budget, integrity checks and precise engine/art/content invalidation. Do not simply raise Android RAM budgets. A format/version change and cold/restart corruption/pixel/device checks would be necessary.

### 2. A full ghost mesh is built with Ghost off and zero compatible recordings

`game/core/game.gd::_ready` calls `PersonalGhost.configure(car)` whenever ordinary-race preferences are present. Only later, in `restart`, does it read `ghost_mode` and available local recordings. The measured cases explicitly set **Ghost off** and had **zero recordings**, yet each built a **313,674-vertex** ghost.

The ghost/shadow stage cost **140–162 ms** in the first pine repeat series. Independent `PersonalGhost.mesh_for` calls cost **141–158 ms**, confirming the mesh assembly rather than contact-shadow setup dominates. Other-theme samples were about 123–166 ms.

Recommendation: decide whether a drawable compatible personal ghost exists before constructing its mesh; keep pose capture and PB recording independent. Cache the immutable combined ghost mesh by exact car model/detail/fitted-kit version and configuration. Paint is not geometry. Keep fresh ghost nodes/material state and retain future rewind/rival presentation requirements. This is a clear redundant allocation for the measured Ghost-off/no-recording cases.

### 3. Warm track loading still reconstructs most of the car, particles and audio

On the first three pine repeats, median measured Game setup components were:

| Component | Median |
| --- | ---: |
| Car construction/batching | 226.604 ms |
| Ghost and contact shadow | 154.498 ms |
| Particle/effect creation | 100.090 ms |
| Audio players/source preparation | 47.858 ms |
| Selected-car audio setup | 63.564 ms |
| HUD creation | 18.256 ms |
| Restart/setup | 16.239 ms |
| Trail storage/setup | 8.014 ms |
| Ground setup | 1.953 ms |

Thus a world-cache hit does not make the whole race setup a cache hit. These repeat scenes took **612–678 ms ready / 694–758 ms through the two preparation draws**, with preferences present. The smaller historical profiler omits preferences and the personal ghost, so its values should not be treated as complete production loading costs.

Recommendations:

- **Car:** cache immutable assembled mesh data or bounded rest-pose templates for the selected/recent car and fitted configuration. `CarVisual._ready` rebuilds stock coachwork, wheels/detail and static batches on every new scene. Keep paint/livery/washing materials, wheel articulation, impacts and live nodes independently owned. Cache pieces or use a small LRU; do not cache all 256 kit combinations without a byte budget.
- **Particles:** share immutable draw meshes, shader programs, gradients/curves or bounded prepared templates. `SandDust._ready` constructs several effect families each time, including dormant biome effects. Keep particle simulation/emission, bridge bindings, pause/reset and the approved per-biome budgets fresh. Shared mutable process materials must not leak desert settings into another biome.
- **Audio:** retain prepared immutable stream resources instead of releasing and reloading/duplicating the bank every race. `VehicleAudio.streams` is per-instance and cleared on exit. Six selected-car loops are reopened/prepared during configure. The isolated PCM wrapper itself took only **1.15–1.26 ms** per sampled loop, Ogg **0.030 ms**, so avoid attributing all ~100 ms audio setup to that wrapper alone. File/resource loading, player setup and the Windows adapter also contribute. Reusing the native device adapter is an additional lifecycle-sensitive option; stop voices and honor bus/device/focus settings before changing ownership.

### 4. Cold road generation and first render remain expensive and mostly synchronous

First diagnostic process, identical Star geometry in each biome:

| Biome | Road stage | World/ground setup | Ready through prepared draws |
| --- | ---: | ---: | ---: |
| Pine | 2,175.997 ms | 2,686.227 ms | 4,224.190 ms |
| Desert | 17,023.434 ms | 17,336.434 ms | 18,585.716 ms |
| Winter | 12,727.714 ms | 14,352.585 ms | 16,068.518 ms |
| Storm | 1,670.396 ms | 1,855.646 ms | 9,958.351 ms |
| Night | 1,837.749 ms | 2,046.362 ms | 15,376.374 ms |

The second process could reuse pine/storm/night disk roads (about **90–121 ms** road stages). Desert/winter still generated roads (**13,436 / 12,998 ms**) because admission rejected them. Winter low cover also took **1,303–1,416 ms** on a cold world build. Storm/night's first draw exceeded scene construction by several seconds in the first run; this includes first-use rendering/driver work, not a GPU-execution-time measurement.

Current normal race setup calls the builder with slicing disabled. The visual builder can yield for menu work, and recent concurrent editor work introduces CPU road-preparation jobs, but its prepared-packet path is guarded by `editor_preview`; it does not automatically make ordinary race construction a worker job.

Recommendation: use cancellable background CPU geometry preparation or cooperative installation under the existing loading cover, keeping scene/GPU work on the proper thread. Slicing improves responsiveness rather than total work. Reuse existing outline/UV/topology and **already implemented Winter row caches**; do not recommend adding duplicates of them. Desert endpoint profiles still repeat across adjacent sections, and polygon subdivision/coordinate caches deserve finer per-piece attribution before changing algorithms. Preserve exact joins, masks, winding and the settled-bank artwork; lowering detail is not the proposed optimization.

Keep the recent weathering preparation draw. Removing it can put compilation back into driving. A context-aware completion registry may avoid repeated known-safe warm-up work, but its context must include the actual renderer/MSAA/shader/mesh/light requirements and cancellation must not falsely mark completion. It is a lower priority than the hundreds of milliseconds of entity reconstruction.

### 5. Shader-variant caching misses its own preprocessing cost

`SurfaceShaderVariants.specialize` duplicates a dynamic material, expands include text, creates/compiles regular expressions, rewrites fixed flags/samplers and hashes the result **before** looking up its 64-entry shader cache. The shader object is cached, but that preprocessing repeats for another material with the same fixed role.

Thirty identical warm role preparations measured **3.711 ms median / 16.884 ms maximum per call**, and the latest default-source rerun measured **4.276 / 17.101 ms**. This can accumulate across many road/terrain/light partitions. The total number of production calls in each build was not separately counted, so multiplying it into a claimed whole-load saving would be speculative.

Recommendation: look up a bounded prepared variant early using source/include revision, all fixed flags, packed terrain slots and relevant branch choices; precompile reusable regexes. Continue creating independent material parameters and preserving the public inspection metadata. Keep Winter's explicitly preserved snow-bank branch and the phone sampler fallback.

### 6. Smaller duplicated work and remaining blocking paths

- `CloudTracks.download` checks/parses/validates a cached document; `compile_entry` does so again; a cold `TrackCompiler.compile` validates again. The warm Star document check cost **4.369–8.027 ms**; cached compilation **20.343–25.979 ms**. Separate snapshot restores measured **23.480–31.477 ms** and are independent calls, not additive stages. Consolidate work within one pinned preparation request while retaining actual file/hash/corruption checks. Do not replace content verification with timestamps alone.
- `_prepare_metadata_race` creates/draws/closes one loading overlay and `_start_race` creates another. A clean metadata start has five bounded presentation-helper calls versus four for direct hydrated start. Reuse one overlay/continuation and coalesce only genuinely redundant stages; initial overlay visibility and material warm/restore draws serve real purposes. Its exact end-to-end UI/network saving was not benchmarked here.
- Hydration updates the selected object and persists compiled metadata, but does not populate `TrackCatalog.remember_track`'s resolved-track LRU. Selecting that cloud tile later can create another metadata-only object and reenter validation/hydration. Keep the completed compiled selection in the bounded catalog cache with the existing version/source fences.
- `_next_result_race` calls `track_catalog.resolve` directly on the main thread before `_start_race` draws its cover. A cold compile can therefore block the results UI. Route it through the existing asynchronous/pinned preparation path.
- `_retain_metadata` rewrites retained and alias files even when unchanged; cached download plus remember-compiled may do this twice. `_start_race` also rewrites `last_track` records on every new scene, including unchanged selection. Deduplicate confirmed identical writes while preserving actual updates, atomic failure behavior and account/origin scope.
- `Game._ready` applies lighting, then `_update_weather` applies it again. Winter can create/replace sky resources twice before first render. This is a small source-confirmed redundancy, without separate measured cost.
- `PreparedWorldCache._resource_bytes` fetches whole mesh arrays to count their lengths. Use the cheap length/count APIs where exact accounting is equivalent. `_isolate_instances` also reads the copied MultiMesh buffer twice; save one fetched buffer locally. World restoration is already sub-few-millisecond in these samples, so these are secondary targets.

## Cache coverage and interpretation

Already present: five compiled snapshots / 32 MiB, up to five full worlds / 64 MiB, roads in memory / 32 MiB and on disk / 96 MiB, a four-track catalog LRU, and cached shader objects. Compiled-cache returns are independent; full-world restores create fresh mutable instance buffers. Preserve these isolation rules and fresh server tickets.

The world limit is bytes as well as entry count. This fixture retained only **one** world after desert (55,362,344 B) and winter (40,669,196 B), and **two** after later themes. Nominal five entries does not mean five large Rivalry tracks stay cached. Road/world accounting can also count shared immutable resources separately; inspect real process/GPU residency before altering budgets.

Immediate `_retry_race` already calls `game.restart()` on the existing scene and obtains a fresh verified ticket when required. It avoids the car/world/ghost mesh creation above. Its remaining ghost-file read/reset/save/network costs are separate; the measured new-scene timings are not claims about every Race Again.

`TrackShowroom` has an eight-image preview cache but no current construction call was found in the searched ordinary Race UI. Treat legacy preview optimizations as low priority until an active caller is demonstrated.

Threading guidance: [Godot's active-tree/GPU limitations](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) apply to proposed workers. The [MultiMesh buffer API](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) returns copied data; it is not an immutable zero-copy view. These facts do not by themselves prove an observed GPU readback stall in this review.

## Concurrent source changes and new regression

Measurements completed before concurrent native-kit-190/editor changes added prepared editor road packets, uniform terrain regions and static spatial mesh partitioning. Reviewed-source snapshots and command-specific build identities are retained. The memory/disk gate still exists in the latest source, and the new prepared-road job path remains editor-only. Earlier timers must not be presented as a completed benchmark of the new default flags.

A default component run during that concurrent change failed with `Condition "p_name.is_empty()" is true` in `set_name`: `SpatialMeshChunks.add` assigned an empty `source.name` to its first chunk. The failure and then-current source are retained. Concurrent work subsequently added a non-empty fallback; a fresh default-source component rerun completed successfully at build **0.3.0-creator.a394cc9ff52f3ca8e93d6092de3c9f5d**. The rerun still built the unused ghost (111.987 ms independently), spent 234.155 ms constructing the car and 66.752 ms on particles. This review did not patch production code or suppress the error. No full twelve-scene post-change benchmark is claimed.

That new chunk builder also duplicates each full source attribute array for every chunk before resizing/filling the subset. Fresh correctly typed per-chunk arrays avoid that repeated full-buffer copy. Its separate cost was not isolated in the successful component rerun. The probe was adapted to the optional geometry-key argument and block-style world-cache return, preserving the new paths rather than overwriting them.

## Actual work, commands and limits

Changed by this review: `game/tests/review_track_loading_2026_10_13.gd` (+ UID), this report, status/plan entries and `docs/evidence/track-load-review-2026-10-13/`. Instrumented methods are transient script copies/subclasses. Disposable document/road/records paths stay in `build`; no player source document, PB, account, live game or backend state was altered. The normal launcher regenerated its usual build identity. No shipping feature edit, export/install or deployment occurred.

All engine commands used pinned Godot **4.7.2.stable.official.ed1daf0bf** via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_repeat_race_load.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_track_loading_2026_10_13.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_track_loading_2026_10_13.gd -Graphical -TestArgument '--components-only'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_track_loading_2026_10_13.gd -Graphical -TestArgument '--artifact-only'
scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/review_track_loading_2026_10_13.gd
scripts/dev.ps1 -Action Doctor
```

Completed: existing profiler **nine** scenes; detailed probes **12 + 12** scenes with zero-tick/full-360-countdown/five-lap assertions; component measurements and latest-default rerun; artifact save/load and exact resource assertions; final diagnostic compiler check. Initial whole-file visual instrumentation failed typed `emit` self checks and was corrected to inherit NativeTrackVisual. The naming failure is retained alongside the successful rerun after the concurrent fix. No failing shipping invariant was weakened.

Windows/Compatibility/RTX 3090, 1280×720, shared host. Raw stage JSON, logs, command build identities, inspected-source snapshots and a scoped review patch/hash manifest accompany this report. The artifact experiment does not include HTTP, whole-world setup, new-scene entity creation or GPU first-use completion; no implementation speedup is claimed. A phone **was attached**, but no phone loading/memory/thermal test was performed. No full replay/regression suite was needed for a review-only diagnostic; no full Validate or Android export was run. No visible shipping UI change required screenshots.

Recommended implementation sequence: retain and validate the concurrent chunk-name correction; split disk/resident admission; skip/cache ghost geometry; bounded immutable car/particle/audio preparation; early shader-variant lookup; then consolidate hydration/metadata/overlay work and refine cold CPU geometry using existing caches/jobs. Each implementation should have its own measured before/after checkpoint, exact resource/pixel/state isolation checks and physical-device acceptance.
