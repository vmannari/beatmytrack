# GLES surface sampler budget fixed — 31 October 2026

The previous failing test stopped at its first Desert material. A complete inventory of the current task-start source found **42 over-budget materials among 96 sampled surfaces**, across default, Star and mixed-surface bridge fixtures in all five biomes. The final Compatibility/OpenGL check now finds **zero over-budget surfaces**, retaining the existing maximum of eight declared texture samplers. Both desktop and Android are configured to use this renderer. Mobile/Vulkan and Forward+ retain their original shaders.

| Biome | Highest original declaration count | Highest final count |
| --- | ---: | ---: |
| Pine | 10 | 8 |
| Winter | 17 | 8 |
| Desert | 10 | 8 |
| Storm | 9 | 8 |
| Night | 8 | 8 |

These are Compatibility declarations in recursively expanded shader source, including nested meshes and active surface materials, not measurements of a particular driver's active texture-unit usage. The 96 entries are fixture/material observations, not 96 distinct GPU programs. The original 17-sampler Winter bridge had bypassed specialization. The inventory's `after` field records the actual task-start material; its `before` field regenerates through the frozen generator and differs for previously raw bridges.

- **SBF01:** Inventory every relevant material before selecting removals. `inventory.json` records paths, original shader resources, declared sampler names and whether the material was specialized. The original eight-sampler assertion remains unchanged.
- **SBF02:** Extend the existing inactive-sampler aliases in `game/track/surface_shader_variants.gd` only on Compatibility. Remove the unreachable `painted_grass_texture` fallback for Desert, Winter and Pine's hybrid grass shoulder. Remove `snow_road_sources` outside snowy/icy and Night materials. Remove `road_mask` only in Winter's creator-road shader when `piece_materials` is disabled. Winter banks use that name for an active mask and keep it. Night already fits eight and its complete shader sources remain byte-identical, avoiding unnecessary shader-cache invalidation. Active artwork, UVs, filtering, shading operations and geometry are retained.
- **SBF03:** On Compatibility, `game/track/creator_bridge_visual.gd` and `game/track/bridge_presentation.gd` prune previously unspecialized bridge materials with `fold_flags=false`. Their original uniform branches remain. This mode is part of the preparation key and survives material duplication through metadata, preventing reuse of a shader with different branch specialization. Existing fully specialized paths retain their mode.
- **R01:** Final `test_sampler_pruning.gd` passes **444 checks, zero failures**: all 15 fixture/biome combinations, budget limits, surviving parameter/texture identities, cache reuse, unchanged Night sources and no additional shader source variants. Explicit retention cases require fallback grass, mixed-road masks and winter snow sources to retain their exact textures where needed; Winter bank masks and bridge branch/cache separation also pass. The unchanged original sampler regression passes **63 checks, zero failures**. The shader-consolidation regression passes **141 checks, zero failures**, retaining the previous source-count reductions. Native desktop Mobile passes **289 source/binding/cache checks**, verifying original source text for all 96 sampled materials.
- **Q01:** A task-only patch is checked forward and backward in an owned build directory. It excludes concurrent work and generated build identities and does not write the main Git index.

`game/tests/test_shader_variant_consolidation.gd` now normalizes only the three intentionally changed sampler declarations when comparing the previous independently captured shader bodies. All other text, renderer policy, source populations and retained bindings remain checked. The new sampler regression independently checks the conditions and retained active bindings; the budget and pixel tolerances are not weakened. `game/tests/fixtures/sampler_budget_before.gd.txt` freezes the generator from the start of this task.

`review_sampler_pruning.gd` uses one frozen actual Game scene per biome, with a mixed-surface bridge track. It copies current live shader parameters, including late-bound weather textures, to both arms. The original raw Winter bridge remains raw in the control. Both arms are warmed before each camera view; the comparison still requires an exact restored control and maximum RGB channel change of 2/255. `profile_sampler_first_draw.gd` uses the existing primed, fresh-sampler-name material-grid benchmark against the task-start generator. Driver caches are not erased, so its results are not full startup/race-load or phone measurements.

The broader first candidate passed all 30 Compatibility image checks, with all 15 before/after PNG files byte-identical. Its Mobile run retained stable controls but failed two Winter views (3/255 and 8/255); that candidate is rejected on Mobile. After the renderer guard, the Winter rerun passes all six checks with exact pixels. The final minimal policy keeps the validated Winter Compatibility output and restores Night's original source. Its separate Pine, Desert and Storm rerun passes all 18 checks, with all nine before/after PNG pairs byte-identical and exact restored controls. No image threshold is relaxed.

Broader-pruning GPU and first-use timings varied substantially. `broad-pruning-first-draw.json` is retained, including slower samples; it does not establish a loading improvement. The final policy avoids unnecessary Night changes and limits the other removals to the over-budget families. Steady-GPU timing blocks are retained as diagnostics, not a throughput claim.

The final first-use probe completes with the following samples (milliseconds, two measurements per arm in baseline/candidate/candidate/baseline order):

| Biome | Baseline samples | Final samples | Mean change |
| --- | --- | --- | ---: |
| Desert | 7575.950, 7229.996 | 6987.236, 7010.028 | -5.46% |
| Storm | 11401.567, 9147.314 | 9322.250, 9412.882 | -8.83% |

These small samples favor the final fix but show substantial baseline variation, especially Storm. They do not establish a reliable cold-start speedup. The verified result is removal of the declaration-budget failure, with exact tested pixels and the earlier shader-source consolidation retained. All five jobs in `suite-minimal.log` complete with exit zero, expected completion markers and no detected engine/script/shader errors.

The [machine-readable report](evidence/sampler-budget-fix-2026-10-31/report.json) records results and evidence hashes. The [task-only patch](evidence/sampler-budget-fix-2026-10-31/task.patch) and [checkpoint result](evidence/sampler-budget-fix-2026-10-31/checkpoint.json) capture source changes relative to this task's starting files.

All tests use pinned Godot 4.7.2, isolated profiles under `build/sampler-budget-fix-20261031`, and a disabled API. The initial inventory sets `BMT_SAMPLER_AUDIT=1`, `BMT_SAMPLER_OUTPUT` to the inventory JSON and invokes:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_sampler_pruning.gd -CommandTimeoutSeconds 300
```

The component run uses the same command with audit disabled and a separate output/profile. The remaining suite enters through `dev.ps1` once to avoid repeated shipping-asset identity scans:

```powershell
$env:BMT_SAMPLER_EVIDENCE = Join-Path (Get-Location) 'docs/evidence/sampler-budget-fix-2026-10-31'
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/run_sampler_validation.gd -CommandTimeoutSeconds 1800
```

The suite launches children sequentially with that validated executable and explicit crash-dialog suppression. `BMT_SAMPLER_JOBS` selects comma-separated job names. The first suite ran `samplers,consolidation,compatibility,mobile` and stopped at the rejected Mobile result. The guarded suite ran `component-final,component-mobile,mobile-final,first-draw`. The final narrower suite runs `component-final,samplers,consolidation,compatibility-final,first-draw`, with `BMT_SAMPLER_TIMING_THEMES=desert,storm`. Standalone reproductions are also available through the evidence `run.ps1`. The initial suite's Windows GUI executable left captured stdout empty; actual completion markers and errors were recovered from each isolated Godot log. The runner now supplies an explicit engine log and requires the expected completion marker. Preserve previous outputs when rerunning evidence jobs.

No device test was performed. Client reload, owner appearance acceptance and actual Android loading/GPU acceptance remain. No owner session/save, device, backend or deployment was changed. The fix changes rendering resource declarations and bridge material preparation only; canonical driving and scoring are untouched.
