# Road-surface regression investigation — 2026-09-22

Requirements R01/R03/R07/V02/V04/V05/Q01. The owner asked whether the road surface explains the recent mobile slowdown. This extends the earlier feature investigation, which did not isolate surface shading.

## Controlled comparisons

Same physical DN2103 / Android 13 / Mali-G77 MC9, Godot 4.7.2 Compatibility, normal 0.667 3D scale, shadows enabled, real HUD/timing/telemetry and normal biome effects. Each variant is bracketed by current-material baselines. All stages restart, warm for five seconds and measure twenty seconds. AI attempts are unscored; no records are written.

Only duplicate ShaderMaterials change. Mesh resources, transforms, canonical track data, physics, camera, lighting, render scale, weather, HUD, particles and material base colours remain. The exact original material objects are restored for each baseline and on completion.

Variants:

- `asphalt_previous`: shared surface include from Git commit `767dcb0` (`game/track/surface_detail.gdshaderinc`), with the newly added directional asphalt function replaced by an identity function. Current creator geometry, mask/cutout code, worn-line logic and edge-strip geometry remain. This isolates the newer dry-asphalt detail and directional grain; it is not a whole-game historical rollback. Grass, sand, wet and icy detail functions in the older include match their current counterparts.
- `directional_off`: removes only the directional asphalt colour call. All other current shader code remains.
- `road_flat`: constant palette colour on creator asphalt, white markings and cosmetic asphalt-edge meshes. Original mask discard, lighting and geometry remain, but cosmetic texture/wear/crossfade are simplified. Sand/grass shoulders remain detailed.
- `terrain_flat`: removes detailed colouring from the base ground, weighted terrain layers and creator grass/sand shoulders. Terrain mask feathering/weights and road detail remain. Tapered striped kerbs are retained.

The probe covers `creator_road.gdshader`, `terrain.gdshader` and `ground.gdshader`. It does not replace separate bridge-deck shaders, prop shaders or the weather screen effects. `surface_materials_changed` counts assigned replacement materials, not draw calls or unique GPU programs. Previous-detail and directional modes also create equivalent variants for collected materials where their altered functions are unused.

## Ajorata results: dry-asphalt regression confirmed

For each variant, the comparison baseline is the average of the current-material medians immediately before and after it. Milliseconds per rendered frame; lower is better.

| Comparison | Bracketing baseline | Variant median | Variant p95 | Median saving |
|---|---:|---:|---:|---:|
| Previous asphalt detail | 20.336 | 16.846 | 20.129 | **3.490 ms** |
| Current detail, directional pass off | 20.275 | 18.770 | 22.540 | **1.505 ms** |
| Flat creator-road colour | 20.299 | 16.929 | 20.445 | **3.370 ms** |
| Flat terrain/shoulder colouring | 20.304 | 16.794 | 20.162 | **3.510 ms** |

The five current-material baselines were 20.370, 20.301, 20.249, 20.348 and 20.260 ms. Returning to the current shader repeatedly restores the slower frame time. Historical asphalt detail improves the measured median from about **49.2 to 59.4 FPS**, with the same 353 end-of-stage draw calls and 51 collisions. Particle primitive counts vary slightly with presentation scheduling. This is a substantial surface-shading regression, not a CPU telemetry effect or a shadow-quality change.

The directional pass accounts for a measurable part of the newer cost. The terrain comparison includes underlying painted-asphalt layers as well as grass/sand/ground, so it does not assign 3.51 ms exclusively to grass or sand. Savings overlap and are constrained by frame pacing near 16.7 ms; do not sum them. None of these p95 results establishes sustained 60 FPS.

## Storm results: terrain/shared shader is the major surface cost

| Comparison | Bracketing baseline | Variant median | Variant p95 | Median saving |
|---|---:|---:|---:|---:|
| Previous shared asphalt detail | 25.681 | 20.067 | 23.320 | **5.614 ms** |
| Current detail, directional pass off | 25.698 | 25.432 | 28.228 | 0.266 ms |
| Flat creator-road colour | 25.714 | 25.575 | 28.627 | 0.139 ms |
| Flat terrain/shoulder colouring | 25.689 | 16.730 | 20.184 | **8.959 ms** |

The five current baselines were 25.651, 25.710, 25.685, 25.743 and 25.634 ms. The repeated baselines establish that the large improvements are reversible within the same APK. Older shared detail improves the median from **38.9 to 49.8 FPS** with all weather and shadows retained.

Storm does not show a meaningful gain from flattening only the creator-road meshes. Its large surface cost lies in the weighted terrain/ground/shoulder group. The historical include changes the common shader programs used by both terrain and road materials; this result is **not proof that the wet-asphalt colour branch itself executes the new dry-asphalt calculations**. Wet flags and masks were verified to survive replacement. Worn markings still use dry detail, and the larger shared shader can also affect compiler output, branching and register use. These individual GPU mechanisms have not been timed. The measured conclusion is that reverting the newer shared asphalt implementation removes 5.6 ms here, and simplifying the larger terrain group removes about 9 ms.

## Source-level explanation

The old dry-asphalt colour branch evaluates two interpolated `pigment` noise calls. The current branch evaluates approximately thirteen, including warping, weathering, patches/cracks and grain; the directional pass adds six more. Each noise evaluation itself computes four hashed lattice corners. This source-level increase is not a GPU-time multiplier, but it explains why the material deserves measurement. New details are evaluated procedurally per fragment rather than sampled from a precomputed asphalt texture.

The mobile old/current comparisons measure this cost directly while preserving shadows. A regression attributable to surface shading can therefore coexist with the earlier weather/shadow costs; those earlier feature-off savings were not proof that the road was inexpensive.

The next optimization should target shared surface/terrain shading: precompute or texture-sample the expensive asphalt detail, reduce the directional pass, and investigate specialized terrain materials that avoid unnecessary surface calculations. Preserve the approved appearance, masks and physics. Replacing the shipping art with these flat diagnostic colours is not the proposed fix.

## Implementation, provenance and validation

Changed files:

- `game/diagnostics/surface_material_probe.gd`: scoped shader variants, cached material replacements and restoration.
- `game/diagnostics/previous_surface.gdshaderinc`: original project shader copied with `git show 767dcb0:game/track/surface_detail.gdshaderinc` for the historical comparison; not third-party artwork.
- `game/diagnostics/mobile_race_probe.gd`: attach the surface experiment to existing debug-marker stages, report replacement count and restore materials.
- `scripts/profile-features-phone.ps1`: `-SurfaceProfile` selects nine alternating stages and a separate evidence directory, retaining prior measurements.
- `game/tests/test_surface_profile.gd` and `scripts/dev.ps1`: graphical experiment checks through `TestSurfaceProfile`.
- This report, status/plan and evidence record commands and outcomes.

Actual commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSurfaceProfile
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -SurfaceProfile
```

The fresh APK export passed import/startup, 74 driving, 18 catalog and 22 menu checks; the existing driving ObjectDB leak warning remains. The graphical shader experiment initially passed 79 checks. Expanded dry/wet verification then passed **928 checks**, including mesh-resource identity, retained palette/texture-mask/wet/ice/road flags, actual shader rendering and exact original-material restoration on both tracks. The first test harness incorrectly instantiated the game script without its `World` scene node and failed; changing it to instantiate the actual game scene fixed the harness. No production invariant was weakened. No canonical physics was edited, so full replay regression was not rerun.

Desktop captures demonstrate [current detail](evidence/surface-performance-2026-09-22/desktop-baseline.png), [historical asphalt detail](evidence/surface-performance-2026-09-22/desktop-previous-asphalt.png) and [flat road shading](evidence/surface-performance-2026-09-22/desktop-road-flat.png). The flat comparison was visually inspected. These are diagnostic variants, not a proposed shipping appearance.

## Limits

All eighteen phone stages completed. The initial battery temperature was 37.5°C, 40.2°C after Ajorata and 42.0°C after Storm (battery readings, not GPU temperatures). Tight bracketing baselines help control that warming; this is not a thermal-soak certification. Shader switches occur before the warm-up window. No phone screenshot was taken during measurement windows.

The runner removed the debug marker/results and temporary device configuration, then successfully cold-launched normal play. Player files were retained. Original production materials and settings remain installed. Final raw reports, APK SHA-256, device/battery records, test/export/runner logs and screenshots are in [the evidence directory](evidence/surface-performance-2026-09-22/). The [task-only review patch](evidence/surface-performance-2026-09-22/surface-profiling-changes.patch) excludes prior shared-workspace edits; no unrelated work was committed.

Final verification: both raw reports contain nine stages; the device file listing confirms the diagnostic marker/results are absent. `git diff --check` passes for modified tracked files, and `git apply --reverse --check --ignore-space-change` verifies the review patch against the mixed-line-ending workspace.

Short AI runs do not represent all tracks, complete races, worst-case particle loads, long thermal sessions or other phones. Ajorata's driver repeatedly contacts obstacles. Whole-frame differences include GPU/driver scheduling and are not exact shader GPU timestamps; capped frame pacing can hide additional savings near 16.7 ms. Variants simplify appearance solely to measure cost. No production shader-quality change is made by this investigation.
