# Winter and desert performance pass

2026-10-13, owner-requested BPERF01–BPERF04 / V02 / V04 / V05 / G01 / R01 / Q01. Preserve the approved winter ice, reflections, banks, blowing/pushed snow, golden desert road and bank blend, original nine-second dust, tire-mark colour, camera, local car condition, five ordinary laps and canonical driving/scoring. Presentation kit 182 → 183 invalidates prepared worlds and disposable road caches.

Runtime changes:

- `game/track/native_track_visual.gd`: draw opaque terrain after roads/banks/props, then the kilometre-wide backdrop. Hidden fragments can fail depth before evaluating their surface detail. Winter/desert maps containing at most four surface kinds pack the original eight mask channels into one RGBA sheet; richer painted maps retain both original sheets. No cells, geometry, palette or artwork change.
- `game/track/surface_shader_variants.gd`: compile fixed material-role reads and the exact packed-mask remap. Retain role uniforms for inspection and cache serialization, plus the existing dynamic material for diagnostics. Keep Winter's original snow-bank branch form to preserve its Mobile edge shading.
- `game/track/terrain.gdshaderinc`: skip an empty second mask; unpack packed channels before the unchanged nine-tap filtering/fringe semantics; share identical snow/dune detail between the two loose-terrain channels while retaining the original accumulation order and weights.
- `game/track/creator_road.gdshaderinc` and `bridge_road.gdshaderinc`: skip immediately overwritten base shading; snow/dune skirts do not evaluate an identical second artwork or its irrelevant nine-sample blend mask.
- `game/track/winter_ice.gdshaderinc`: skip the reflected cloud field only where its seam contribution is exactly zero.

Opaque ordering follows Godot's documented [queue and render-priority order](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html#render-priority). The improvement is established by the local measurements below, not inferred from that documentation.

## Evidence and method

`game/tests/profile_biome_shaders.gd` runs an explicit unscored diagnostic without records/account/upload adapters. Original pre-task shader generation and includes are retained in `game/tests/fixtures/biome_performance_before/`. A single frozen scene alternates baseline/optimized/baseline/optimized, with one-second warmup before each measured five-second stage. Camera, meshes, artwork, lighting, resolution, render scale and 2× MSAA are identical within each pair; only shaders, equivalent mask packing and opaque order differ. Both fixture maps use the packed path.

Three 1600×900 views per biome compare baseline/optimized/restored baseline after settling the Mobile sky. Snow/dust/trails are hidden only in this exact material proof. Required baseline stability is zero changed pixels; the unchanged tolerance is at most 2/255 per RGB channel. Performance uses 3840×2160, 100% render scale, uncapped/VSync-off diagnostics on an RTX 3090 and pinned Godot 4.7.2. These are GPU throughput measurements of frozen desktop scenes, not physical-phone FPS, thermal acceptance or complete five-lap races.

Final paired results and exact pixel counts are recorded in `docs/evidence/biome-performance-2026-10-13/accepted-paired/{gl_compatibility,mobile}/report.json`. Their before/after PNGs are the visual evidence. Actual moving scenes, original dust and snow/reflection checks are recorded separately. A hash ledger proves the canonical simulation, original dust and camera source unchanged. `skid_trails.gd` changed concurrently outside this task; those changes are retained and excluded from the task-only checkpoint. Tire marks are hidden in the paired material proof, so they do not affect its comparisons. This task does not edit tire colours or trail code.

Mean of the two stage GPU medians, with all draw/primitive counts identical within each renderer's pair:

| Renderer / biome | Before | After | GPU-time reduction |
| --- | ---: | ---: | ---: |
| Compatibility / Winter | 2.1615 ms | 2.0425 ms | 5.51% |
| Compatibility / Desert | 2.2715 ms | 2.1505 ms | 5.33% |
| Mobile/Vulkan / Winter | 2.0585 ms | 1.3245 ms | 35.66% |
| Mobile/Vulkan / Desert | 2.0365 ms | 1.4670 ms | 27.96% |

Both renderers pass 17 paired checks each. Desert has zero changed pixels in every view. Winter has 11–12 changed pixels/view in Compatibility and 25–34 in Mobile out of 1,440,000 pixels; maximum channel change is 2/255 and restored-baseline instability is zero. No texture/detail/particle reduction, resolution scaling or camera change accounts for these savings. Frame intervals in these frozen scenes also improve, but they are not claimed as driving/phone FPS. Desktop GPU results cannot be transferred numerically to the attached Mali-G77/GLES phone.

Inspected actual [Winter driving](evidence/biome-performance-2026-10-13/gameplay/winter-motion-mobile/driving.png), [Winter motion](evidence/biome-performance-2026-10-13/gameplay/winter-motion-mobile/driving-motion.html), [Desert gameplay](evidence/biome-performance-2026-10-13/gameplay/desert-mobile/after/route-35.png) and [Desert bridge mouth](evidence/biome-performance-2026-10-13/gameplay/bridge-mobile/entry.png). Compatibility equivalents and all paired views are retained in the same evidence tree.

## Actual verification

Commands use `powershell -NoProfile -ExecutionPolicy Bypass` and `scripts/dev.ps1`, which selects the pinned engine rather than the older PATH alias. Engine calls required sandbox escalation for normal `user://` logs/caches; the first restricted run could not write those logs. Doctor's restricted ADB check also failed; the permitted retry found matching templates and the OnePlus DN2103 (`PRQKU4U4PREQNRWG`). Device availability is not a device test.

- `TestScript -ScriptPath res://tests/test_biome_terrain_packing.gd`: 3,885 checks, zero failures across five biomes, including every source-channel byte in two four-kind layouts, all eight kinds/fallback, canonical cells and scoped opaque priority.
- `TestDesert`: 87 checks, zero failures, including original dust and five-car packed/loose behavior.
- `TestRoadCache`: 70 checks, zero failures.
- `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd`: 60 checks, zero failures across five biomes.
- `TestDriving`: 72 checks, zero failures, including exact replay at multiple presentation rates and production camera/input behavior.
- `TestScript -ScriptPath res://tests/test_script_parse.gd`: 609 scripts, zero failures.
- `TestShoulders`: union, 71 joins and 18 contours, zero failures.
- Final paired diagnostic: `TestScript -Graphical -ScriptPath res://tests/profile_biome_shaders.gd -TestArgument @('--seconds=5','--folder=res://../docs/evidence/biome-performance-2026-10-13/accepted-paired')`; Mobile adds `-RenderingMethod mobile -RenderingDriver vulkan`: 17 checks per renderer, zero failures.
- `TestScript -Graphical -ScriptPath res://tests/test_winter_environment.gd -TestArgument @('--capture','--fresh-roads','--output-dir=<task gameplay folder>')`: 100 checks per renderer, zero failures, actual gameplay/material/rotated/compact captures.
- `TestScript -Graphical -ScriptPath res://tests/capture_desert_refinement.gd -TestArgument @('--stage=after','--evidence-root=<task gameplay folder>')`: six views on each renderer; 60,799 bank vertices/184 clods, canonical cells/hash unchanged, actual original-dust captures.
- `TestScript -Graphical -ScriptPath res://tests/test_desert_bank_bridge_blend.gd -TestArgument '--folder=<task bridge folder>/'`: 656 checks per renderer, zero failures. Compatibility entry/exit RGB delta 0.029607/0.014673; Mobile 0.031859/0.016169, both below the original 0.035 tolerance.
- Graphical all-biome sampler check: 60 checks, zero failures. New captures copied into this task; historical captures restored from the pre-run copies.
- Final `Import`: exit zero; stable IDs generated for the new diagnostics and archived includes.
- `TestScript -Graphical -ScriptPath res://tests/test_winter_environment.gd -TestArgument @('--capture','--reflection-proof','--seam-proof','--video','--output-dir=<task motion folder>')`: final 109 checks per renderer, zero failures, including 150 actual motion frames each. Compatibility broad/seam contributions 28,334/46,296 pixels, Mobile 83,914/33,357; zero unstable pixels. The cached-material discovery fix in this test reads original biome flags from `surface_dynamic_material`, with all existing pixel and stability assertions retained.

Intermediate failures are retained: the initial diagnostic inherited a conflicting `capture` method and attempted to hide absent desert wind; these were fixed in the diagnostic. Mobile's first unsettled sky produced an unstable baseline; timed settling fixed the comparison. Constant vector indexing caused a Mobile compiler error, so packed slots now generate direct named-channel assignments. Folding `smooth_road_bank` changed one Winter MSAA edge pixel by 3/255; retaining its original branch resolves this with the original 2/255 tolerance. Mobile seam checks initially selected only fresh terrain after loading specialized road materials from disk, reporting zero contribution; reading their original material metadata correctly includes all three ice materials and restores the existing proof. A shell-escaped exit guard failed between the final paired renderer commands; both engine diagnostics still ran independently and report their own outcomes. A nested PowerShell array command also failed parsing before engine launch; file-based runners produced the actual visual results. No acceptance threshold or failing invariant was weakened.

No Android export/install/physical-device rendering or performance test, full Validate, physics merge, backend changes, live score writes or production deployment performed. Remaining acceptance: owner driving/frame-pacing review, representative phone/thermal measurements, broader track/camera coverage and low-end hardware. The task-only patch and isolated Git checkpoint preserve the shared index/HEAD and unrelated existing workspace changes.
