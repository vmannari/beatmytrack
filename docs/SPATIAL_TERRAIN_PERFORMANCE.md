# Racing render audit rows 3 and 4

2026-10-13. Requirements SPT01 (spatial static geometry), SPT02 (uniform terrain regions), V03/V05/G01/R01/Q01. The owner requests the next two racing-render improvements after the optional simpler car models. This slice preserves the existing artwork, triangle populations, source normals/UVs/pigments, camera, dust, tire ribbon/ring, local condition and canonical driving/scoring.

## Implementation

`SpatialMeshChunks` prepares immutable 32 m groups of whole triangles from eligible large scenery/low-cover and Winter/Desert bank aggregates. Triangles are assigned by centroid, never clipped or regenerated. Groups copy original indexed vertex attributes and share the original material. There are at most 256 groups; very large fields increase tile size. Small meshes retain their original single draw. Existing Winter scenery groups, flat terrain/backdrop, moving props, editor retained batches and the tire MultiMesh keep their established paths.

The original named mesh remains intact, including its transform, visibility API and geometry used by snow-height readers. `StaticMeshDrawView` chooses between that full colour draw and the prepared spatial children. It chooses children only when the camera frustum contains under 65% of the triangles and saves at least 4,096 triangles per additional visible group submission. Godot performs the actual conservative AABB culling; every child stays available during camera motion. Selection runs at most every 150 ms and skips unchanged camera poses/projections. No camera, broad views and double-sided casters use the original draw. There are no racing-time mesh uploads or rebuilds.

In spatial mode, the original full mesh remains **one complete shadow caster**, and children cast no shadows. This preserves offscreen shadows without creating one shadow submission per group. In direct mode, the original casting mode/layers are restored and all children are hidden. Prepared-world duplication retains the selector script and its original draw settings.

Preparing chunks retains both original and partitioned geometry. A conservative extra-byte estimate must fit the existing 64 MiB prepared-world limit before splitting; otherwise the source stays direct. Actual original/chunk resources count toward the same limit. The five-entry world and eight-entry/32 MiB road limits are unchanged. Road caches keep original aggregates; complete non-editor worlds retain the prepared view. This adds cold geometry preparation and memory where admitted; it does not claim to accelerate cold loading.

`TerrainUniformRegions` computes an exact homogeneous 5×5 footprint from the final presentation surface kinds in linear time. The radius includes the original nine-tap ±0.65-texel filter and bilinear support, including clamped map edges. A completely unused channel in the existing high or low weight mask stores the predicate. All active weight bytes, image dimensions and filtering coordinates remain identical. It adds neither a texture sampler nor a persistent texture image.

Uniform interiors use a nearest predicate lookup plus one original filtered read per active mask: **2 reads instead of 9**, or **3 instead of 18**. Original boundary feathering remains unchanged and costs one additional predicate lookup there. After sampling, the spare channel is cleared before the existing packed-kind remap and shading. Materials occupying all eight channels retain the original path without the predicate lookup. Immutable role/channel choices are specialized with the existing material compiler; public parameters remain available for inspection/cache serialization.

The normal prepared-world key keeps its existing seven fields and current kit fence (track-kit-191, shared with concurrent editor/Winter work). Diagnostic disabled variants get separate keys. Concurrent editor road preparation, Winter surface powder, desert mineral lighting and fitted-car work are preserved.

## Measured work and pixels

Pinned Godot **4.7.2-stable**, NVIDIA RTX 3090, Windows desktop; these are component work/timings, not physical Android FPS. `test_spatial_terrain_racing.gd` builds the same real native scene/materials with an archived pre-change terrain include, uses three views in each of Pine/Desert/Winter/Storm/Night, and separately enables masks, spatial draws and both. Both final renderer runs pass **72 checks**; all 45 before/after comparisons per renderer have **zero changed pixels**, with exact baseline restoration. The fixture has no account, records, race submission or artificial-race adapters. Sky warmup is held before captures.

The fixture has 35,304 eligible cells of 44,608 (79.1%). It is a compact track: the adaptive selector retains the full view at the measured poses, so spatial mode adds no submissions. This demonstrates why unconditional splitting was rejected; spatial gains depend on larger offscreen populations.

| Five-biome GPU component, ms | Mobile/Vulkan before → both changes | Compatibility before → both changes |
|---|---:|---:|
| Pine | 0.275/0.273 → 0.262/0.262 | 0.484/0.484 → 0.485/0.485 |
| Desert | 0.227/0.232 → 0.228/0.228 | 0.447/0.448 → 0.447/0.447 |
| Winter | 0.289/0.291 → 0.287/0.286 | 0.450/0.451 → 0.452/0.453 |
| Storm | 0.244/0.242 → 0.238/0.238 | 0.455/0.450 → 0.449/0.449 |
| Night | 0.189/0.188 → 0.177/0.177 | 0.425/0.429 → 0.432/0.433 |

Stages alternate original, individual changes, combined, original, combined; each value is the median of a 0.6 s sample after settling at 1600×900. Desktop Vulkan shows roughly 0–6% component improvement; Compatibility is effectively flat, with small regressions in some samples. Sub-millisecond shared-host results are load-sensitive and do not establish a whole-game FPS gain. Raw CPU/GPU/draw/primitive samples and every pixel proof are in [Mobile report](evidence/spatial-terrain-2026-10-13/mobile-report.json) and [Compatibility report](evidence/spatial-terrain-2026-10-13/compatibility-report.json).

The separate 512 m, 65,536-triangle opaque field tests the beneficial spatial case with an actual directional shadow:

| Work at narrow camera | Original | Spatial view |
|---|---:|---:|
| Colour triangles | 65,536 | 1,024 |
| Shadow triangles | 65,536 | 65,536 |
| Submitted total primitives | 131,072 | 66,560 (49.2% fewer) |
| Total submissions | 2 | 5 |
| Vulkan GPU ms, two alternating samples | 0.054 / 0.048 | 0.041 / 0.041 |
| Compatibility GPU ms | 0.214 / 0.163 | 0.186 / 0.172 |

Both renderers pass the 12-check graphical selector/cache/pixel test. CPU timings are mixed; additional submissions have a cost. Full overview returns to two submissions. Expected benefit is less vertex/depth work on large tracks at close racing views; overview/small scenes retain the direct path. The original whole shadow caster deliberately bounds submission overhead while preserving appearance.

Selected paired captures: [Winter before](evidence/spatial-terrain-2026-10-13/winter-before.png), [Winter after](evidence/spatial-terrain-2026-10-13/winter-after.png), [Desert before](evidence/spatial-terrain-2026-10-13/desert-before.png), [Desert after](evidence/spatial-terrain-2026-10-13/desert-after.png). These freeze current native lighting and geometry; they do not claim a new visual design.

## Actual validation

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' ..."` and the pinned engine; no older PATH alias. Logs are under `build/logs/` and copied into this slice's evidence receipt.

| Action / script | Actual final outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_terrain_uniform_regions.gd` | 17,152 checks, zero failures; exhaustive/clamped footprints, packed codes, unused-high/unused-low and all-eight fallback |
| `TestScript -ScriptPath res://tests/test_spatial_mesh_chunks.gd` | 34 checks, zero failures; all 8,192 triangle/normal/UV/UV2/pigment tuples conserved |
| `TestScript -ScriptPath res://tests/test_static_mesh_draw_view.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3` | 12 checks, zero failures |
| Same selector test, `-RenderingMethod mobile -RenderingDriver vulkan` | 12 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_spatial_terrain_racing.gd -Graphical`, with each renderer above | 72 + 72 checks, zero failures; exact paired pixels |
| `TestScript -ScriptPath res://tests/test_biome_terrain_packing.gd` | 3,885 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd` | 60 checks, zero failures; existing phone sampler limit retained |
| `TestScript -ScriptPath res://tests/test_prepared_race_load.gd` | 85 checks, zero failures; representative admission, budgets and replay-isolated mutable instances |
| `TestRoadCache` | 70 checks, zero failures after concurrent editor fixture/API updates |
| `TestScript -ScriptPath res://tests/test_biome_followup.gd` | 133 checks, zero failures; weathering uploads, full tire ring parity and preview reuse |
| `TestScript -ScriptPath res://tests/test_winter_snow_wind.gd` | 33 checks, zero failures |
| `TestDriving` / `TestRewind` | 72 / 61 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_car_wash.gd` | 1,383 checks, zero failures |
| `TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -TestArgument @('--folder=res://../build/spatial-terrain-2026-10-13/bridge')` | 8 checks, zero failures; actual roof/deck pixels and independent trail layers |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 678 scripts, zero failures |
| `Import` | Exit zero; new helper/fixture UIDs registered |

Initial trials and corrections: fixed 32/64 m-only chunking increased submissions with no compact-scene triangle savings, so the adaptive full view was added. Splitting shadow casters into every chunk produced 39 submissions in the large fixture; the retained one-caster strategy reduces that to five. Keeping original plus chunks initially rejected a representative Desert cache entry; conservative admission restored the existing assertion without increasing the budget. A doubled-height predicate atlas passed Compatibility but changed a sparse Mobile road-edge channel by 3/255; the atlas was removed and unused-channel metadata preserves the original texture coordinates exactly. Predicate one-hot reconstruction was also rejected in favour of original filtered mask values. A shared Night material was deduplicated during diagnostic preparation; sky settling and inherited fixture API errors were corrected without weakening pixel thresholds. Concurrent car API/editor await interruptions were resolved by their owners and final checks rerun. The bridge pixel fixture was first launched headless and waited for a rendered frame; only that owned helper was stopped and its graphical rerun passed.

Changed runtime files: `native_track_visual.gd`, `terrain.gdshaderinc`, `surface_shader_variants.gd`, `prepared_world_cache.gd`, plus the three new spatial/region helpers. New tests and the archived original terrain fixture are export-excluded. The task-only [Git patch](evidence/spatial-terrain-2026-10-13/implementation.patch) and [hash checkpoint](evidence/spatial-terrain-2026-10-13/checkpoint.json) preserve other sessions' changes; the shared Git branch/index is untouched.

Physical-device tests, phone FPS/thermal/memory and owner acceptance remain outstanding. No phone test, APK export/install, full `Validate`, backend writes or deployment was performed by this slice. No physics/contracts changed. The immutable prepared geometry can increase cold preparation and memory within existing budgets; the runtime cost gate is conservative, not a guarantee for every GPU.
