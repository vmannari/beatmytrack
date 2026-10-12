# Winter environment and ice/bank correction — 2026-10-11

The owner expands the Winter wind experiment into a reference-led environment pass, then rejects the first dark road and smoother banks as asphalt-like and too rounded. The final local revision uses original scuffed ice artwork with baked finish data and restores the earlier high-frequency bank shapes, taller deposits and detailed snow shading. It retains the overhead camera, actual vehicle scale and existing HUD. Owner visual acceptance remains pending; this is not a claim of AAA quality or measured phone performance.

## Requirements and implementation

WE01 road ice: `winter_ice.gdshaderinc`, `surface_detail.gdshaderinc`, `creator_road.gdshaderinc`, `terrain.gdshaderinc`, `bridge_road.gdshaderinc`, `creator_bridge_visual.gd`, `bridge_presentation.gd`, `native_track_visual.gd`, and the two new v2 texture/import files. Medium blue-grey ice retains crystalline abrasion and irregular frost instead of flattening artwork into a uniform dark colour. A single packed finish sample supplies frost-dependent roughness/specular and derivative-filtered micro-slope. Ground roads, bridge decks and bank toes sample the same world-space 6 m tile. Two faint, broken road-aligned wear paths supplement actual race-persistent wheel marks.

WE02 lighting: `track_theme.gd`. Warm winter sun at −34° pitch/−55° yaw, cool ambient fill, longer shadows at restrained opacity 0.68, a 128-pixel sky reflection resource and subtle ordinary distance haze. Other biomes reset fog and shadow opacity. No visible horizon, volumetric fog, SSR or extra runtime lights are introduced.

WE03/WE12 banks and owner correction: `native_track_visual.gd` (`track-kit-119`) and `winter_bank.gdshader`. The first broader, lower bank variation was rejected. The final crest function and tall independent deposits restore the exact earlier shapes; the deposit cap is 900 versus the earlier 1800 maximum. Detailed original snow colouring returns, and bank meshes receive/cast real scene shadows. Toe ice shares road coordinates. Canonical soft snowbank contacts are unchanged.

WE04 wind: `winter_snow_wind.gd` (`winter-wind-7`), its shader and `winter_air_snow.gdshader`. Fast 24 m/s gusts retain the shared world direction, actual exposed-bank anchors and scene lighting. Shorter frayed fingers and lower alpha fit the darker ice. At most 49 ground patches, 36 bank layers and 24 small airborne grains render in three draws, with at most 578 triangles. The extra grains use bounded shader advection, no new particle simulation. Conservative depth protection keeps opaque car roofs clear. Pause/background/finish/retry and biome disposal remain verified.

WE05/WE09 vegetation and adaptation: `winter_scenery.gd`, `creator_scenery.gd`, `native_track_visual.gd`. Shared original snow-coated spruce/bush/stone/fence meshes are instanced in spatial tiles. Authored scales, rotations and variable fence lengths are retained. Up to 48 automatically generated mature trees/boulders/fences use real creator collision footprints, road/deck clearance, stable suppression keys and existing selection/deletion tools. Winter prioritizes the route before distant terrain. Up to 180 low bushes/twigs/small stones are passable visual cover, with shadows disabled on the smallest kit. Up to 64 red reflective stakes follow prepared road-bank geometry and avoid bridges. The art adapts to ordinary pieces, splines and overlapping bridge layouts; there is no hardcoded reference circuit.

WE06 vehicle integration: `skid_trails.gd`, `sand_dust.gd` (`winter-spray-4`), `contact_shading.gd`. Darker polished ice tracks vary with actual wheel motion, braking, slip and layering; mild rolling wear joins stronger scrub. The existing fixed snow pools emit a small rolling ice powder wake and stronger drift powder. Car contact shading is slightly stronger in Winter only. Canonical vehicle forces are unchanged.

WE07/WE08 terrain and atmosphere: `surface_detail.gdshaderinc`, `surface_shader_variants.gd`. Quiet broad snow variation and localized fine detail replace busy uniform grain; slopes derive coherently from a baked height field. Winter uses continuous diffuse lighting across these shallow cosmetic drifts. Sparse airborne grains plus low-density haze provide depth. The physical ground remains unchanged.

WE10 modest computation: original mesh instances, existing tire pools and baked textures; no runtime AI, per-frame terrain searches, new dependencies or new audio. The new artwork imports at 1024×1024 and finish data at 512×512, both mipmapped. Grass/desert/storm branches retain their own material behavior. Q01, V04/V05, G01/R01 and the five-lap/pinned-contract requirements also apply.

WE11 contracts: adding real automatic Winter obstacles intentionally bumps `TrackCompiler.VERSION` from `creator-compiler-22` to `creator-compiler-23`. Other biome geometry, route and metadata are exact apart from the version/hash. This is a local compiler revision, not a live catalog migration. Existing published versions/tickets/boards are not silently relabeled. Client/server rollout and publication of new immutable track revisions are required before shipping this solid-scenery change online; no deployment or public writes were performed.

## Actual commands and outcomes

All engine commands used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with PowerShell process execution policy Bypass and normal Windows certificate-store access. Renderer comparisons ran on an RTX 3090, not a phone.

| Command / check | Actual result |
| --- | --- |
| `dev.ps1 -Action Import` | New typed scripts, shaders and both textures imported successfully. |
| `-Action TestScript -ScriptPath res://tests/bake_winter_ice_finish.gd` | 512×512 finish data generated. Expected raw-image-load/export warning: this is an offline, export-excluded tool. |
| `-Action TestScript -ScriptPath res://tests/test_winter_compiler_contract.gd -TestArgument @('--refresh-contract-fixtures')` | 29 checks, 0 failures; historical compiler-20 raster goldens exact, compiler-22→23 non-Winter geometry exact; new Winter contract distinct. Numeric replay text preserved. |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd` | Final 93 checks, 0 failures, including imported dimensions/mips, solid/deletable scenery, cached/fresh compilation and alternate spline/bridge clearance. |
| Same, `-Graphical -TestArgument @('--capture','--video')` | Final Compatibility 95 checks, 0 failures; actual canonical RouteDriver inputs, wheel trails/powder, 150 rendered driving frames at 30 fps. |
| Same, `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')` | Final Mobile Vulkan 94 checks, 0 failures. |
| `test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')` | Final Compatibility 47 checks, 0 failures. Static 723 roof samples and moving opaque/normal-AA interior samples all unchanged by gusts; dark light-response delta 0. |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan` | Final Mobile 47 checks, 0 failures. Static 743 roof samples; moving direct samples 771/758/759 and AA interior 596/597/580 unchanged; dark delta 0. |
| `-Action TestIce` | 69 checks, 0 failures. |
| `-Action TestCompilerRaster` | 8 checks, 0 failures against explicitly upgraded contract fixtures. |
| `-Action TestHazards` | 151 checks, 0 failures. |
| `-Action TestApp` | 99 checks, 0 failures. |
| `-Action TestDriving` | 72 checks, 0 failures; existing ObjectDB shutdown warning (34 objects) retained. |
| `-Action CaptureWinterBridge` | Two actual views saved; collision cells exact. Repeated after final ice grading. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q` (backend working directory used `tests/test_verifier.py`) | 69 passed in 84.99 seconds; one Starlette deprecation warning. These explicit offline regression diagnostics do not add full replay acceptance fallback. |
| Android SDK `adb.exe devices`, normal-access run | Empty device list. No phone/device test was performed. |

The initial fixture rotations were outside 0–359° and were corrected. Historical raster fixtures still used compiler-20 hash prefixes; direct comparison to compiler-22 initially gave eight failures, so the migration audit now explicitly proves historical-20 goldens and separately compares 22→23 geometry. A JSON fixture refresh initially changed quantized integer inputs to decimals, causing one backend failure; final refresh uses only byte-preserving string replacements for the version and hash, and all 69 backend tests pass. Mobile's old roof colour threshold initially sampled only 59 pixels (none changed); the renderer-aware luminance/chroma fixture now retains the same minimum coverage and exact-pixel assertions. Imported texture checks initially queried logical texture dimensions/mips, producing two failures per renderer; final checks inspect the actual imported Image storage (1024/512 with mips), retaining both budget requirements.

Raw profiles are saved beside the captures. Final compact scenery view is 393228 submitted primitives and 316 Compatibility / 332 Mobile draw calls, including scene/shadows/HUD. Wind visibility adds exactly three draws and 506–578 triangles in the measured fixtures. Desktop visual update loops were roughly 12–19 µs; GPU timings varied widely with concurrent desktop load and renderer startup (roughly 0.28–2.5 ms medians across passes). These are smoke measurements, not a controlled whole-environment before/after benchmark, an Android frame budget or proof of device efficiency. The overall scene/shadow cost still needs actual mobile acceptance.

## Evidence, provenance and remaining acceptance

- [Actual driving image](evidence/winter-environment-2026-10-11/driving.png), [driving motion](evidence/winter-environment-2026-10-11/driving-motion.html), [bend](evidence/winter-environment-2026-10-11/bend.png), [material-only view](evidence/winter-environment-2026-10-11/materials.png), [compact gameplay](evidence/winter-environment-2026-10-11/compact.png).
- [Mobile bend](evidence/winter-environment-2026-10-11/mobile/bend.png), [Mobile gameplay](evidence/winter-environment-2026-10-11/mobile/gameplay.png). The Mobile renderer is additional desktop coverage; the configured Android renderer remains Compatibility.
- Actual paired wind/roof/light captures and driving sequences are under `wind-validation/` and `wind-validation-mobile/`. Only mixed MSAA silhouette pixels may reflect a changing background; opaque interior pixels stay exact.
- Bridge views are under `bridges/`; source snapshots and failed/passing logs are retained for review. Evidence-only wide inspection cameras do not modify gameplay camera contracts.
- [Exact built-in imagegen prompt and saved asset paths](assets/WINTER_ICE_V2_PROMPT.md), plus `asset-manifest.json`. Spruce/snow-caps/bushes/rocks/fences/stakes are original code-authored geometry. Existing snow/wind/vehicle resources and their provenance remain. The owner's screenshots are direction only, not shipping texture/image assets.

Restart the client to load the revised resources/cache version. Remaining checks: owner appearance review on real creator circuits and different camera orientations/zoom, texture repetition and tire/wind readability over a complete race, low-end Android frame time/thermals, touch play and shadows, then explicitly authorized server/client rollout and catalog republication for compiler-23. No Android export/install, full project Validate, live upload, backend deployment, board migration or production release was performed.

A task-only Git checkpoint is recorded under `build/winter_environment/checkpoint-repo`; it excludes other ongoing changes and leaves the main branch/index alone.
