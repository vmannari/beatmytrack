# Dynamic first-use hitch checks ? 2026-10-14

Owner request: ?check that the tire marks and other similar dynamic items won't cause the hitches?. Requirements DRH01?DRH05 / Q01 / G01 / R01 / V03 / V05. The check found real uncovered first-use paths and prepares them during loading. It does **not** establish that every driver/OS stall is impossible.

## Findings and changes

The [previous phone trace](DESERT_HITCH_INVESTIGATION_2026_10_13.md) records a separate 974.903 ms Mali compiler event near tick86/route3. The tire cursor changes4?12 and the following context identifies its first MultiMesh draw. This is a first-visible shader/driver lead; it does not show that the approved ribbon geometry, pressure, sampling or 16,384-slot budget is defective.

Concurrent tire work now adds `TrailRenderPreparation`: one temporary MultiMesh slot uses the **actual original mesh, live Shader RID and the parallel renderer's existing encoder** under the cover. This task preserves that work, independently verifies its exact ring/mesh/shader/pixel invariants, and adds a validity guard at the common teardown call. `skid_trails.gd` and `trail_visibility.gd` are byte-identical to this task's initial snapshots. The tire helper and its own test are excluded from this task's checkpoint as concurrent work.

| ID | Uncovered path | Implemented or verified measure |
| --- | --- | --- |
| DRH01 | Tire ring starts with zero visible instances; loading a material does not submit an actual instanced draw. | Verify the concurrent covered tire draw. Retain original full ring, one racing batch, four-wheel/.32 m sampling, geometry, pressure and all artwork. |
| DRH02 | `_ensure_water`, `_ensure_snow`, `_ensure_deck_clouds` allocate GPU nodes/materials/geometry on the first relevant driving sample. Desert profile also changes cloud/spray geometry and process resources at first sample. | `SandDust.prepare_track` calls the same approved resource routines during Game construction, before the cover is released. Storm water and Winter snow resources are ready; bridge dust is ready for creator and legacy native bridges. No fake vehicle sample, emission, bank impact or race-clock advance is used. |
| DRH03 | Dormant dust/smoke/clippings/mud/spray/water/snow materials and their particle process shaders can remain undrawn until driving. | Temporary one-particle emitters reuse each original process material and draw mesh. They run while Game is disabled, with bounded .05 s maximum pre-process, in the actual camera/world/render context. Live emitters, particle ages, positions, settings and materials are untouched. Temporary nodes are freed before the clean reveal. |
| DRH04 | Empty wood/hay MultiMeshes, inactive Winter batches and hidden damage-phase meshes have latent instancing/shadow/material paths. | One temporary instanced draw per existing debris/weather batch preserves its actual mesh/material/instance format. Original damage phases borrow visibility/cull margins only during the covered draw, then restore exactly. No real fragment/population/buffer or prop integrity changes. |
| DRH05 | Crash-glass shader is attached but its TextureRect remains hidden until the first heavy contact. | One temporary TextureRect uses its actual texture/material under the same cover, without setting damage. Existing glass visibility, side damage, strength and material ownership stay exact. The hitch logger records effect preparation/counts alongside the existing tire/bridge/hazard context. |

All preparation uses the existing covered draw and clean reveal, with the full 360-tick countdown intact. It adds no new visible player UI, renderer/shader source, retained material cache or racing draw budget. Temporary counts are bounded by the actual existing effect population: 20 ordinary emitters; plus4 Storm water,12 Winter snow, and8 deck emitters when a bridge exists. Each temporary emitter has one particle. The temporary batch/canvas/phase resources are released on normal completion and cancellation, including already-deleted nodes.

Resource creation and driver preparation move into loading. This can increase cold loading work, because previously some of that work occurred during driving. It does not eliminate the work. Dormant track-specific GPU resources also exist earlier in the scene; their eventual original emission amounts/lifetimes and the existing prepared-emitter cache bounds stay unchanged. Exact baseline comparisons use the pre-change resource routines, including original nine-second Desert dust.

[Godot's documented Compatibility approach](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) requires drawing first-use materials/particles in view during loading; preloading a resource alone is insufficient. Modern renderer pipeline counters complement this check. [GPUParticles3D documentation](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html) also distinguishes particle creation/process behavior; `emit_particle` is unavailable in Compatibility, so this implementation uses bounded temporary emitters with the real resources.

## Actual verification and measurements

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, Windows, NVIDIA RTX3090. Desktop Compatibility/OpenGL and Mobile/Vulkan are tested; neither is a physical-phone performance measurement. The shared host and already-warm OS/driver caches limit timing interpretation. No driver cache was deleted.

Final `test_dynamic_render_preparation.gd` checks all five themes, with/without legacy bridge availability, then inactive wood/hay/weather/damage/canvas paths and an actual offline Storm App launch. It compares original emitter geometry/process/material/budgets exactly, checks no first-sample emitter allocation, observes real additional draw calls while the enclosing world is disabled, and requires byte-exact restored pixels, camera and tire-ring data. The actual App reveal requires tick0/full countdown/five laps, an empty original tire ring, no artificial live emissions, no temporary nodes, prepared water resources and unchanged existing saved car condition.

| Completed check | Actual final result |
| --- | --- |
| Dynamic preparation, Compatibility | **471 checks, zero failures**, normal exit |
| Dynamic preparation, desktop Mobile/Vulkan | **481 checks, zero failures**, normal exit |
| Dynamic preparation, headless | **148 checks, zero failures**, normal exit; no graphical preparation claimed |
| Existing tire-preparation fixture, headless | 26 checks, zero failures |
| Bridge dust/masks/layer lifecycle, Compatibility | 121 checks, zero failures |
| Snow-bank behavior/impact profiles | 51,852 checks, zero failures |
| Breakable props/debris/replay | 46 checks, zero failures |
| Local condition/washing | 1,383 checks, zero failures |
| Hitch logger | 45 checks, zero failures; deliberately delayed persistence remains diagnosed |
| Over/under loading/deadlines | 26 checks, zero failures; intentional timeout warnings |
| Driving / rewind | 72 /61 checks, zero failures |
| App integration | 99 checks, zero failures |
| Full project script compilation | 714 scripts, zero failures |

Final raw results: [Compatibility](evidence/dynamic-first-use-2026-10-14/gl_compatibility/resources.json), [desktop Mobile/Vulkan](evidence/dynamic-first-use-2026-10-14/mobile/resources.json), [headless](evidence/dynamic-first-use-2026-10-14/headless/resources.json). Final desktop first-live particle draws after covered preparation take **0.995?1.256 ms** in Compatibility and **0.789?1.774 ms** in Mobile/Vulkan across the ten isolated cases. The first CPU driving sample stays below **.213/.304 ms** respectively and creates no emitters. These are fixture frame intervals, not whole-race FPS or a cleared-driver-cache benchmark.

Every Mobile/Vulkan case reports **zero new on-demand draw pipelines** at first live particle emission. Compatibility's counters cannot establish the absence of driver shader compilation; actual visible draw coverage, exact restore and the historical native stack evidence support the preparation approach. Changing lighting/features later can still expose variants beyond the starting render context.

The unchanged tire visibility/append probe checks counts511,1023,1024,4096,16384 and the first ring wrap. The synthetic layout puts successive512-slot pages far apart to force conservative compaction:

| Operation | Compatibility | Desktop Mobile/Vulkan |
| --- | ---: | ---: |
| First1024-slot visibility activation/packing | 1.175 ms | .816 ms |
| View at4096 retained slots | .025 ms | .027 ms |
| View at16384 retained slots | .030 ms | .054 ms |
| Single append at first ring wrap | .011 ms | .019 ms |
| Slowest individual append observed | .164 ms | .190 ms |

All stages retain one batch,16,384 capacity and the exact retained logical count. [Raw ring measurements](evidence/dynamic-first-use-2026-10-14/gl_compatibility/ring-costs.json) distinguish individual append cost from bulk synthetic setup: filling12,288 more marks in one artificial block takes38.420 ms in Compatibility. Gameplay does not append that entire block at once. No new incremental geometry/pressure/sampling algorithm or broad CPU tire optimization was introduced.

Covered three-frame intervals span32?74 ms in final Compatibility and approximately8?16 ms in the earlier final-full Vulkan pass. Creating bridge/snow resource families took up to25.449 ms Compatibility and122.972 ms Vulkan in the final shared-host fixtures. That is the work moved before racing; timings include existing constructors and graphics-resource/API work. No universal upper bound on phone loading or GPU-driver compilation time is claimed.

## Failures retained and resolved

The first diagnostic assigned a legacy script instance to the shipping class type; the fixture now uses its actual Node3D type. Headless Texture2D readback can return null, so curve/gradient source data and available texture dimensions are resolved directly there; graphical tests compare actual pixels. Deleted-node cleanup exposed a real typed Node iterator assigning an already-freed instance: the shipping helper uses Variant plus validity checks, and cancellation fixtures remain strict.

One intermediate full Vulkan fixture printed466 passing checks, then engine shutdown exceeded its240-second wrapper deadline. No crash or failing gameplay invariant was suppressed. A components-only diagnostic completed460 checks and exited normally; subsequent complete final runs completed469 and481 checks with normal exit. The original exit-timeout remains recorded, and its cause is not established. Initial nonexistent `test_winter_spray.gd` invocation was replaced by the actual snow-bank behavior test. No assertion was removed or relaxed.

## Actual commands and checkpoint

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Principal executed commands:

```powershell
scripts/dev.ps1 -Action CheckScript -ScriptPath res://vehicle/effect_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dynamic_render_preparation.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dynamic_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dynamic_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--components-only' -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dynamic_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_dust.gd -Graphical -RenderingMethod gl_compatibility
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_trail_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_breakable_props.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action TestDriving
scripts/dev.ps1 -Action TestRewind
scripts/dev.ps1 -Action TestApp
```

The [command index](evidence/dynamic-first-use-2026-10-14/commands.json) retains actual logs/build identities and known failure/timeout notes. The [task-only patch](evidence/dynamic-first-use-2026-10-14/task-only.patch), isolated Git bundle, base/final snapshots, checkpoint metadata and SHA-256 manifest provide a reviewable scoped checkpoint. Changed runtime files are `game/vehicle/sand_dust.gd`, new `effect_render_preparation.gd` (+UID), `game/core/game.gd`, `game/core/app.gd`, and the single observational field in `game/diagnostics/race_hitch_monitor.gd`. New `test_dynamic_render_preparation.gd` (+UID), this report and status/plan notes complete the slice. Concurrent tire/bridge/hazard/wind work is preserved and excluded as changes. The shared Git index/HEAD are untouched.

The renderer can still stall for driver/OS scheduling, first-use variants outside this starting lighting context, GPU load, deferred allocation or persistence. The logger retains first-use effect masks/counts, preparation context and CPU/render-boundary timings for the next event. A fresh cold/primed **physical-phone trace with this build** is the remaining acceptance check; historical phone measurements do not validate this new fix. No phone commands, export/APK/install/deployment, live backend writes or full Validate were performed by this task. Canonical physics, scoring, normal five laps, artwork/camera, source tire ring/sampling, local condition and original gameplay emission/drawing budgets remain unchanged.
