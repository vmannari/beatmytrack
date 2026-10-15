# Current Winter rendering cost audit

2026-10-14. Owner request: investigate what makes Winter slower now. WRA01 identifies current rendering costs, WRA02 compares the same circuit in other biomes, WRA03 retains a repeatable diagnostic and honest measurement limits; G01/R01/Q01/V05 remain unchanged.

The desktop fixture did **not reproduce Winter being slower overall than Grass or Desert**. The strongest measured optimisation targets are terrain/ice surface shading and render submissions. Blowing snow has a smaller cost in the measured views. This is an investigation, not an implemented performance improvement or a diagnosis of a particular phone slowdown.

## Reliable same-circuit results

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, RTX 3090, Windows. Each renderer independently runs the same native circuit in Winter/Pine/Desert, with a frozen camera, car, lighting and wind clock, 2x MSAA, scale 1.0, VSync off and no cap. Warmup is 0.6 s; each main stage samples 1.5 s. HUD, dust and deposited tire marks are hidden to isolate scenery. Readbacks happen outside measurement windows. Winter uses the real surface powder materials plus the original 48 airborne grains; no floating ground/bank cards are active.

GPU values below average the initial and final full-stage medians. Their baseline drift is at most 1.2%. Main Compatibility records kit 200; main Mobile records kit 201, reflecting concurrent work. These are independent component measurements, not a source-frozen comparison between renderers or an incremental before/after optimisation.

| Biome | Compatibility GPU, 1080p / 4K ms | Mobile/Vulkan GPU, 1080p / 4K ms | Total submissions, Compatibility / Mobile |
|---|---:|---:|---:|
| Winter | 0.714 / 1.921 | 0.411 / 1.350 | 157 / 157 |
| Grass/Pine | 0.717 / 2.030 | 0.470 / 1.655 | 140 / 136 |
| Desert | 0.723 / 2.018 | 0.448 / 1.491 | 127 / 127 |

The removal modes retain the camera and mesh resources. Replacing surface materials with flat materials also changes masking, lighting and depth ownership, so the savings are **cost bounds**, not achievable optimisation percentages, isolated instruction counts or proposed visual settings. Effects overlap; differences must not be added together.

| Winter diagnostic | Compatibility 1080p / 4K GPU reduction | Mobile 1080p / 4K GPU reduction | Implication |
|---|---:|---:|---|
| Flat terrain material | 21.1% / 32.7% | 6.0% / 11.2% | Full-screen terrain surface work is a strong GLES investigation target. |
| Flat road materials | 14.6% / 9.3% | 10.6% / 14.9% | Ice colour, frost, finish and reflective shading are another substantial target. |
| Hide blowing snow | 1.0% / 1.9% | 3.3% / 7.3% | The tested wind state costs less than the main terrain/road paths; other event phases still need coverage. |
| Disable directional shadows | 6.0% / 0.9% | 11.3% / 10.2% | Shadow benefit varies by renderer. This is not permission to reduce approved shadows. |
| Flat bank materials | 8.4% / 4.9% | -0.6% / -1.8% | A flat bank replacement does not reliably improve Mobile; bank detail removal is not supported by these results. |
| Hide frost border | 3.8% / 4.6% | 5.0% / 4.0% | The border is a smaller full-screen cost. |

## Work attribution and next candidates

The detailed stock car accounts for **109 of Winter's 157 submissions** in the first view, including its colour/shadow work. Hiding it lowers Compatibility render CPU from approximately 0.663 to 0.475 ms at 1080p; Mobile falls from 0.183 to 0.130 ms. This is common car/driver work, not a Winter-specific regression. Without the car, Winter submits 48 draws, Grass 31/27 and Desert 18: Winter has 17–21 more environment submissions than Grass and 30 more than Desert in this view. The profiler counts complete viewport submissions, including shadows and the retained Winter border.

The scene inventory finds nine bank mesh resources containing 87,266 triangles in aggregate. This includes colour/chunk/shadow resource copies and is **not a unique bank geometry count** or a claim that every retained mesh is submitted in every view. Existing adaptive spatial draws and the complete shadow caster are preserved.

Source inspection identifies useful candidates for a follow-up implementation:

1. **Terrain material specialization.** `terrain.gdshaderinc` retains the eight-layer array/loop after exact packed-mask remapping. Investigate compiling the known active kinds into fixed ordered contributions, retaining all-kind fallback, the original weights, region predicate, fringe and accumulation order. Existing mask packing and region skipping already work; do not repeat those changes or replace the artwork.
2. **Shared ice/frost calculations.** `winter_wear_width()` computes `winter_edge_frost()` for colour, and the road/bridge fragment computes the same frost again for reflectivity. Check whether the driver already eliminates the duplicate work; an explicit shared result is a candidate, not a measured saving. Preserve actual road width, pigment, normals and seam radiance on both renderers.
3. **Submission overhead.** Further changes must respect immutable geometry, articulated parts, mutable paint/condition roles, original shadow ownership and existing simple-car preference. The current profiler does not establish that reducing bank geometry is necessary.

The existing moving Winter diagnostic completed real canonical AI driving. In its first 1080p full stage, simulation, particle sampling and trail sampling averaged about 0.177 / 0.064 / 0.018 ms per frame. The broader presentation block averaged 0.679 ms. Its `car` subsection includes wind, weathering, audio, support and suspension, so it must not be presented as isolated car animation cost. These short ordinary-driving samples do not cover saturated trails or continuous bank spray. Its moving GPU baselines drifted substantially and are excluded from reliable GPU percentage comparisons.

Second-view snow-covered-car tests keep the **same submission and primitive counts** as the clean car. A Mobile capture exposed an independently visible pause canvas; that attempt is retained as invalid. The corrected diagnostic disables ordinary input, explicitly hides nested non-weather CanvasLayers and asserts that HUD/pause/countdown covers stay hidden. Corrected runs pass on both renderers. The final corrected Compatibility 1080p repetition has stable clean GPU medians 0.728/0.729/0.730 ms versus snow-covered 0.746/0.747 ms: about 2.4% extra GPU time, with 161 submissions/355,483 primitives in every stage. It does not explain a large slowdown. The other second-view timing baselines remain unstable and are excluded from timing conclusions rather than averaged into an apparent gain.

## Actual commands and checks

Engine calls use `powershell -NoProfile -ExecutionPolicy Bypass -Command` and `scripts/dev.ps1 TestScript`. The common diagnostic is `-ScriptPath res://tests/profile_winter_render_audit.gd -Graphical`, with `-RenderingMethod gl_compatibility -RenderingDriver opengl3` or `-RenderingMethod mobile -RenderingDriver vulkan`.

| Actual run | Result |
|---|---|
| Main diagnostic; `-TestArgument @('--folder=res://../build/winter-render-audit-2026-10-14','--seconds=1.5')` | 63 + 63 checks, zero failures; same-circuit three-biome attribution and unchanged canonical snapshots |
| Initial second view; folder `.../view1`, `--view=1`, `--themes=winter`, two seconds and removal/weathered/full repetitions | 23 + 23 checks; Mobile capture contains pause UI and is excluded; later 4K timing drift also excludes timing claims |
| Corrected second view, Mobile; folder `.../view1-corrected`, modes `full,no_wind,flat_terrain,flat_roads,no_shadows,weathered_car,full,weathered_car,full` | 37 checks, zero failures; explicit hidden-overlay and canonical invariants |
| Corrected second view, Compatibility; same folder, `--1080p`, modes `full,weathered_car,full,weathered_car,full` | 11 checks, zero failures; same explicit invariants and stable final weathering repetition |
| `res://tests/profile_winter_desktop.gd`, Compatibility | Completed ordinary unscored AI diagnostic; actual full/no-wind/no-bank/flat/shadow/repeat stages at 1080p and 4K; moving GPU baseline drift excluded |
| `res://tests/test_script_parse.gd` | Final 765 scripts, zero failures after the visibility correction; corrected fixture also compiles/runs on both renderers |

Initial diagnostic errors are retained: restricted Godot could not write its ordinary `user://` logs; permitted rerun worked. The first existing-profiler CLI invocation passed one comma-joined argument, so its default five-second stages ran; the actual output and unusual folder name are retained, not mislabeled as the requested three seconds. The new inventory initially assumed every mesh was ArrayMesh; BoxMesh handling was corrected without weakening an assertion. An optional Python image-count attempt found no Pillow installation; no pixel-count result is claimed.

Raw [Compatibility](evidence/winter-render-audit-2026-10-14/start/gl_compatibility/report.json) and [Mobile](evidence/winter-render-audit-2026-10-14/start/mobile/report.json) reports retain every sample. The [summary](evidence/winter-render-audit-2026-10-14/summary.json), successful/failing logs, selected actual captures, summarizer and task-only patch/hash checkpoint are in the same evidence tree. The new diagnostic is export-excluded by the existing `tests/*` filter. Changed task files are the diagnostic, this report and its evidence; the shared runtime changes, Git index and HEAD are preserved.

No phone attachment check, physical-device test, APK export/install, backend write or deployment was performed. The reported slowdown on the owner's particular track/device remains unconfirmed. Remaining acceptance is an exact-track driving trace on that device, sustained bank/spray/full-trail workloads, and pixel/driver/phone validation of any subsequent implementation. Earlier phone results and these RTX 3090 figures do not certify current phone FPS or a performance improvement.
