# Sun-catching desert sand and pebbles

2026-10-13 DS23/DS24/V02/V04/V05/G01/R01/Q01. The owner requests glistening reflections on terrain sand and stones to suggest sunlight catching grains and small pebbles. This authorizes a restrained mineral finish beyond the earlier fully matte desert presentation. Preserve the approved pigments, artwork, terrain/road geometry, original desert dust generation, tire marks, camera, canonical driving/scoring and performance optimizations.

Sparse mineral coverage comes from the existing packed surface-factor texture. Selected resolved grains receive bounded dielectric GGX highlights from actual scene lighting, view direction and shadows. Broad sand stays rough with zero specular response; the finish has no emission, animation clock, particles, reflection viewport or new texture. Mip bias and a derivative-based distance fade suppress unresolved grains. Loose terrain, sand skirts and banks share the finish; the compacted road retains zero specular response. The original single cover batch receives a two-float vertex tag: stone faces receive the finish while dry scrub stays matte. Existing pebble placement, population, positions, normals, colours and triangle count remain intact.

Changed runtime files: `game/track/native_track_visual.gd` (kit184→185 invalidates disposable visuals), `surface_detail.gdshaderinc`, `terrain.gdshaderinc`, `creator_road.gdshaderinc`, `ground.gdshader`, `desert_road.gdshader`, `surface_shader_variants.gd`; new `desert_sun_finish.gdshaderinc`/UID and `desert_pebbles.gdshader`/UID. New diagnostic `game/tests/test_desert_sun_glints.gd`/UID; this report, agent override, status and phase plan. No image assets, external dependency, canonical contract or schema change. Other-biome finish calls remain disabled. The recent opaque ordering, exact mask packing/fallback and fixed-role compilation are preserved.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned `4.7.2.stable.official.ed1daf0bf`:

| Action / suffix | Actual outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_desert_sun_glints.gd -Graphical -TestArgument '--folder=res://../docs/evidence/desert-sun-glints-2026-10-13/final/'` | Final Compatibility 13 checks, zero failures. Two paired views: 608/2,050 visible contribution pixels in the 578,100-pixel inspection region. Restored off-state is pixel-exact. Archived original materials versus disabled finish: zero changed pixels. 24 camera positions: maximum mean channel delta 0.001476, below unchanged 0.01 bound. Canonical state/cells/hash preserved. |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan` | Final desktop Mobile/Vulkan 13 checks, zero failures. 678/1,686 contribution pixels; off-state restoration exact. Disabled finish versus original: maximum 1/255 channel difference, below unchanged 2/255 tolerance. Motion mean delta 0.001009. Same canonical and cover-tag checks. |
| `TestDesert` | Final 87 checks, zero failures, original nine-second dust and exact five-car packed/loose replay behavior. |
| `TestRoadCache` | 70 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd` | Final 60 checks, zero failures across all five biomes. The pebble shader binds only the existing surface-factor sampler. |
| `Import` | Exit zero; registered classes introduced by concurrent visibility work, including `TrailVisibility`, without reverting those changes. |
| `Doctor` | Matching engine/templates; OnePlus DN2103 attached. No physical-phone test performed. |
| `git diff --check -- game/track/surface_detail.gdshaderinc game/track/terrain.gdshaderinc game/track/creator_road.gdshaderinc game/track/native_track_visual.gd` | Exit zero; existing CRLF normalization warnings. |

The same frozen 1600×900 RTX 3090 scene alternates archived original materials/new finish/original/new, with one-second warmup and two seconds measured per stage. No records or competitive result are produced; particles/trails are hidden only to isolate material proof. The old shaders are expanded from the task's pre-change source snapshots, including original cover material and original hazard/bridge roles. Material change includes the additional mineral sample and specular lighting work. Both renderers keep 130 draws and 429,372 reported primitives in all four stages.

| Renderer | Original GPU medians, two stages | Finish GPU medians, two stages | Difference of mean medians |
| --- | --- | --- | --- |
| Compatibility | 0.950 / 1.036 ms | 1.026 / 1.041 ms | +0.0405 ms |
| Mobile/Vulkan | 0.465 / 0.466 ms | 0.489 / 0.491 ms | +0.0245 ms |

These are short frozen desktop GPU samples, with visible stage drift in Compatibility; they are not sustained driving, phone FPS or thermal measurements. They do not replace the previous performance report or assert zero cost. Full stage medians/p95/sample counts and pixel/motion reports are saved under `evidence/desert-sun-glints-2026-10-13/final/{gl_compatibility,mobile}/report.json`.

Inspected [Compatibility terrain](evidence/desert-sun-glints-2026-10-13/final/gl_compatibility/after-35.png), [Mobile terrain](evidence/desert-sun-glints-2026-10-13/final/mobile/after-35.png) and the paired before/original/disabled views. Six motion-frame captures per renderer accompany the 24-position check. These use the existing gameplay camera on a different saved local track from the owner's original screenshot. Small minerals respond to scene sunlight and view; no broad wet sheen is added.

Initial failed diagnostics are retained: cached shaders lacked source paths; the baseline needed explicit material roles; the unrelated hazard was initially given terrain specialization; focus-induced pause overlays invalidated image comparisons; HDR images needed conversion to display bytes; a concurrently changing hitch observer raised an invalid `int` call. The final unscored fixture freezes presentation/hides pause overlays and disables its hitch observer, leaving runtime pause/diagnostic behavior untouched. No failing visibility/stability assertion is weakened. A first Mobile motion run exceeded the existing bound; the final rerun passes after the capture handling corrections.

This slice edits no dust/trail files. Concurrent visibility changes are retained and excluded from the checkpoint; whole-file equality is not claimed. `preserved-presentation.json` proves the original desert profile/cloud/alpha/growth/rotation functions remain exact against the pre-task source. Original budgets are checked by `TestDesert`.

Task-only baseline/fix Git checkpoint: `build/desert_sun_glints/checkpoint-repo`; patch/ledger under this evidence tree. Main branch/index and unrelated work remain preserved. No APK export/install, physical-device run, backend operation, deployment, full regression or physics merge. Remaining acceptance: owner glint strength/style review, physical-phone readability/motion/performance/thermal behavior and broader terrain/object layouts. Large placed rock models are outside this small terrain-pebble finish slice.
