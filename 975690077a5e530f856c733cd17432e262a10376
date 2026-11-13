# Fewer cold road shaders — 31 October 2026

This change shares road shader sources in Desert, Storm and Night on **Compatibility/OpenGL**, the project's current renderer. It targets first-use shader compilation during track preparation. Other renderers retain the original specialized sources. It does not eliminate cold driver work or claim an end-to-end startup or Android loading improvement.

On the actual Star surface inventory, Desert uses **5 instead of 6** unique generated sources, Storm **6 instead of 7**, and Night **6 instead of 7**. Pine and Winter each retain all six original source hashes. These are generated source counts, not counts of the additional internal engine pipeline variants.

- **SVC01:** `game/track/surface_shader_variants.gd` keeps `edge_fringe` as a uniform for packed-sand materials. Wet/Night materials retain four road-role uniforms (`asphalt_surface`, `raised_road_edge`, `edge_fringe`, `road_marking`), allowing existing compatible draws to share one source. Their actual values, geometry, draw ordering, artwork, lights, render modes and material bindings remain intact.
- **SVC02:** Biome choices, inactive sampler removal, terrain channel/remap specialization and other material roles still specialize. Existing per-material preparation signatures, include invalidation and both 64-entry cache bounds remain. This introduces no background compiler, exported setting, renderer switch or engine build.
- **SVC03:** Scope the change to the biomes that benefit. The initial kerb/marking candidate passed 30 native image checks but merged no sources and was rejected. The broader four-switch experiment passed another 30 checks but did unnecessary work in Pine/Winter; the final policy leaves their sources exact and retains only the one necessary switch in Desert.
- **R01:** `test_shader_variant_consolidation.gd` checks actual generated Star materials against frozen generators: source populations, every material binding/texture identity, prepared and freshly generated shader agreement, renderer-specific exact source text and cache bounds. **141 checks pass with zero failures each in headless Compatibility and native desktop Mobile.** The earlier unguarded component run passed 108 checks. `review_shader_variant_consolidation.gd` compares three camera views and restored controls in the same frozen actual Game scene, then alternates both material sets for desktop GPU measurements. `profile_variant_first_draw.gd` measures compilation work independently of simulation.
- **Q01:** Task-only source checkpoint and exact forward/reverse verification are recorded alongside the evidence. Concurrent files and the main Git index are preserved.

The frozen generators are `game/tests/fixtures/shader_consolidation_before.gd.txt` (original) and `shader_consolidation_gl_candidate.gd.txt` (measured candidate before the renderer guard). The final regression compares actual generated source text to the measured candidate on Compatibility, and to the original on other renderers. This makes the earlier Compatibility measurements applicable to the final guarded implementation. The inventory/candidate helper is `game/tests/probe_shader_variant_consolidation.gd`. Four generated test UIDs accompany these tests. The only runtime source edited for this shader task is `surface_shader_variants.gd`; the earlier road-support loading optimization is a separate change.

Native image validation retains the existing maximum **2/255** channel allowance and requires the restored original image to be exact. Effects that change over time are hidden in both arms. The benchmark uses the same camera, mesh buffers, textures and lighting; it does not certify arbitrary track content or sustained phone FPS.

The final native Compatibility run passes **18 checks, zero failures** across nine paired views. Desert and Night are pixel-exact; Storm's maximum channel difference is 1/255. All restored controls are exact. At 2560×1440, the mean of the two measured stage GPU medians is 1.280→1.287 ms for Desert, 1.245→1.283 ms for Storm and 1.2525→1.257 ms for Night. These short interleaved desktop measurements show small differences (about +0.4% to +3.1%); they do not establish phone GPU cost. Actual meshes/draw counts remain the same in each pair. Pictures and full per-stage timing distributions are under `final-compatibility/`.

First-use methodology: an offline visible material grid uses the real Star surface materials. Each trial renames the shared sampler consistently in fully expanded source, making new driver input without changing its value. Timing includes material/shader creation, two completed draws and image readback. Final trials prime common textures and engine pipelines first, then run original/candidate/candidate/original. Driver caches are **not erased**, and this is not a full race-loading measurement. An initial probe missed a remaining kerb include when renaming the sampler and failed; `first-draw-unexpanded-include.log` is retained. The corrected initial experiment is `first-draw.json`; the final primed comparison is recorded separately.

Final first-use results on Windows Compatibility/OpenGL, NVIDIA RTX 3090, Godot 4.7.2:

| Biome | Original mean | Shared mean | Reduction |
| --- | ---: | ---: | ---: |
| Desert | 6,201.606 ms | 5,496.457 ms | 11.37% |
| Storm | 10,951.323 ms | 9,930.326 ms | 9.32% |
| Night | 11,141.923 ms | 9,671.323 ms | 13.20% |

Each mean uses two timed trials, excluding that biome's warmup. The full fifteen-row record, including warmups, is `first-draw-final.json`. Both candidate trials are faster than both original trials in each biome. These are controlled fresh-source comparisons on one driver, with the explicitly stated caching and scope limits above.

The unguarded desktop Mobile experiment is **rejected**, with 18 checks and five failures retained in `mobile.log` and `final-mobile/report.json`: Desert/Storm first-view differences reached 3/255, and first-view restored controls were unstable in all three biomes. This does not isolate a shader regression from the settling/control problem. No threshold was relaxed. The final policy excludes Mobile and Forward+, preserving their original generated source text; no Mobile image-equivalence pass is claimed for the rejected experiment.

The existing `test_terrain_sampler_budget.gd` fails its eight-declared-sampler limit on one Desert surface with **nine** samplers. The task-start generator reproduces the same error and exit code 1 (`sampler-before-control.log`); it is not introduced by this change. The original test and its limit remain unchanged. The exact control source is archived as `sampler-before-control.gd.txt`: it duplicates each original dynamic material and invokes the frozen generator immediately before the unchanged sampler count/assertion. It was run as a temporary `res://tests/probe_shader_sampler_before_control.gd` through the same wrapped `dev.ps1 -Action TestScript` and then removed. This broader sampler finding remains open; no full-suite pass is claimed.

Reproduction uses pinned Godot 4.7.2 and the repository entry point, with crash-dialog suppression around the entire noninteractive launch. Profiles are isolated under `build/shader-variant-consolidation-20261031`, with the API disabled. The evidence runner selects the exact script and renderer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode component
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode component-mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode first-draw-final
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/shader-variant-consolidation-2026-10-31/run.ps1 -Mode samplers
```

The initial inventory and candidate runs used the same wrapped `dev.ps1 -Action TestScript` with `BMT_VARIANT_OUTPUT` or `BMT_VARIANT_FOLDER`; candidate switches are listed in each JSON. `BMT_VARIANT_FINAL=1` selects the shipping generator against the frozen original. Native review uses `-Graphical -RenderingMethod gl_compatibility` or `mobile`. Component checks are headless. Logs retain actual failures; future reruns should preserve earlier output before overwriting the selected report.

No device test was performed. Owner reload/appearance acceptance, real cold driver-cache measurements and Android loading/GPU acceptance remain. No owner session/save, device, backend or deployment was changed. Routine generated build identity files from the standard runner are excluded from the task-only checkpoint.
