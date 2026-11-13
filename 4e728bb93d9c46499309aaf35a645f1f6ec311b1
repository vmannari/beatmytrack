# Runtime stall investigation

26 October 2026. RSI01-RSI04 investigate the loading stalls left open by the [runtime fixes](RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md). **The repeat stalls are traced to bulk GPU-particle warm-up and fresh tyre-trail shader creation. A separate cold construction stall is in the Compact's front fittings.** This task changes diagnostic copies and documentation, not shipping runtime code.

## Confirmed causes

1. **Twenty temporary particle emitters start together.** `EffectRenderPreparation.begin` creates all twenty `GPUParticles3D` proxies before the shared covered draw. Native Compatibility traces then spend about **200-250 ms** in a subsequent render interval. Creating the nodes itself takes approximately **0.6-1.3 ms**. The long interval occurs **before** `effects_end`, so cleanup is not the cause.

   Removing only the particle proxies removes that interval. Removing the crash-glass proxy, skipping finish warm-up, retaining the temporary nodes, or setting their `preprocess` to zero does not. This identifies particle startup as a whole; it does not identify a particular native allocation, shader-link or synchronization call.

2. **Each race creates a new copy of identical trail shader code.** `SkidTrails._trail_material` calls `Shader.new()` and assigns the same source on every scene construction. The trail proxy's first use adds approximately **48-63 ms** in the final control sequence. Sharing that immutable shader, while retaining separate `ShaderMaterial` instances, reduces the repeated interval to **3.6 ms**. The first shared use still pays its first-use cost.

3. **Front-fitting construction repeats expensive surface samples.** `CompactDetail._front` takes **106.18 ms**, including **51.63 ms** inside `_nose_band`. `_nose_tile` evaluates four corners of every cell; adjacent cells recalculate the same coordinates. Near the nose corners, `CompactCoachwork.front_skin` performs a twenty-iteration inverse search. The grille clipping and mesh construction also remain in this synchronous block.

   A diagnostic grid cache evaluates each grid coordinate once, retaining double precision and the original vertex/normal/index order. It reduces the measured front block to **57.55 ms**, and the nose band to **33.84 ms**. Full and simple model signatures remain exactly equal. This is a partial improvement; it does not make that block fit a frame budget.

Whole-world packing is approximately **4 ms**, with warm instantiation approximately **1 ms** in these traces. Replacing the world cache would not address the dominant observed pauses.

## Tests of possible changes

The following cases run in one engine process, with ordinary controls interleaved between experiments. Times include the normal App loading path, using an owned offline Star fixture, Compact, 1280x720 and Windows Compatibility. GPU measurement queries are disabled for these comparisons.

| Case | Longest frame | First warm-up render interval | Total entry |
|---|---:|---:|---:|
| Four ordinary warm controls | 202.0-223.6 ms | 47.6-63.2 ms | 1.51-1.57 s |
| Shared trail shader, first use | 252.6 ms | 56.4 ms | 1.65 s |
| Shared trail shader, repeated use | 203.4 ms | 3.6 ms | 1.50 s |
| One particle proxy initialized per covered draw | 72.7 ms | 49.6 ms | 1.96 s |
| Staged particles and shared shader, first combined case | 82.6 ms | 2.9 ms | 1.83 s |
| Same combined case repeated | 91.2 ms | 3.5 ms | 2.00 s |

Staging improves the largest frame at the cost of roughly **0.3-0.5 seconds** of additional loading in this run. It still misses a 16.7 ms frame budget. It is a tested direction, not a finished runtime fix.

The verified sequence retains **all twenty particle proxies and the glass proxy**. Across all ten cases, the observed live emitter settings match, canonical tick and elapsed ticks stay zero, countdown stays 360, the live trail ring remains 16,384 slots with cursor/visible count zero, and temporary weather materials restore. The original GPU ages and every future first-use condition are not certified by these checks.

In a separate desktop Vulkan Mobile sequence, ordinary warm peaks are **63-74 ms**, principally before the draw interval; the large Compatibility particle/trail intervals do not recur. Cold Vulkan first use still includes a **4.66-second** frame. This does not justify switching the shipping renderer and is not an Android measurement.

## What the trace can establish

The recorder timestamps frame entry, pre-draw, post-draw and the next frame, retaining the context at both entry and draw. It also times seventeen App calls and individual front-construction operations. This avoids assigning a slow frame to whichever status label appears after it finishes.

Per-viewport CPU/GPU counters are auxiliary snapshots. In the first trace, one returned CPU viewport value is 67.4 ms while its surrounding frame interval is only 8.2 ms, demonstrating that these readouts are not aligned to the same callback interval. They cannot identify the exact native blocking function or establish whole-GPU saturation. The API's scope is described in the [official RenderingServer documentation](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

Compatibility first-use behavior is consistent with the engine's [pipeline preparation limitations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). The particle pre-processing experiment specifically rules out treating the configured 0.05 seconds as the complete explanation; [pre-processing](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html#class-gpuparticles3d-property-preprocess) is only one part of startup. The exact engine/driver split remains unmeasured without native sampling or a GPU capture.

The old 503-569 ms “before world” result comes from an earlier working tree, before subsequent header/menu changes. Current cover setup takes around 1.5-1.8 ms in the detailed controls. It would be incorrect to continue blaming that older broad stage label or the world pack. Current first renderer use remains variable: later no-timer cold controls include roughly 390-573 ms frames, while the initial instrumented process has a 7.76-second draw interval under concurrent load.

## Concrete implementation work supported by the experiments

- Reuse one immutable trail `Shader` across attempts; retain separate materials and bridge/surface uniforms. Test bridge clipping, all trail surfaces and the first actual mark after loading.
- Replace bulk particle warm-up with bounded initialization and a bounded cache of initialized resources where reuse is valid. One-at-a-time staging alone still leaves 70-90 ms frames. Preserve the existing Game readiness/account/navigation fences, cancellation cleanup, source-material identity and pressure release. Verify every theme and first actual emission; skipping warm-up is not an implementation.
- Reuse exact nose-grid samples, then yield between bounded construction strips or bake/cache the immutable fitting meshes. Preserve vertex order, clipping, normals, full/simple variants and current geometry. The grid change alone leaves a 58 ms front block.
- Re-profile the remaining CPU preparation and cold renderer first use after those changes in a controlled session and on the target Android renderer. Do not claim a hard frame-time limit from these desktop experiments.

## Evidence and scope

**Eleven trace runs contain 63 completed App loads**, including intentional ablations; every recorded readiness check passes. The final ten-case sequence additionally passes the state/ownership observations above. Full/simple grid parity passes both modes. Exact commands, raw logs, source hashes, source snapshots and all case values are in [report.json](evidence/runtime-stalls-2026-10-26/report.json) and [cases.csv](evidence/runtime-stalls-2026-10-26/cases.csv).

The [Perfetto/Chrome trace artifact](evidence/runtime-stalls-2026-10-26/timeline.perfetto.json) provides separate lanes for update/render intervals and App elapsed calls; awaited calls are explicitly wall-time spans. No trace was uploaded to an external service.

Several other Godot processes were active and were left running. Driver caches were not cleared, and “cold” means first fixture load in that process. The root-certificate-store sandbox error is retained in the logs. One early skip-effects run reports four leaked ObjectDB instances and one resource at exit; subsequent sequenced runs with a bounded teardown delay do not report this. The early finding is retained, not counted as a clean exit.

No physics/configuration/camera/asset changes, owner-save edits, device attachment check/test, APK, real authentication/purchase, backend mutation, deployment, staging/commit/merge or owner-process restart were performed. Production integration and device acceptance remain separate from this investigation. The task-scoped checkpoint contains only the investigation artifacts and documentation.
