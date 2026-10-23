# Grass reference verge — 2026-10-16

The owner supplied a raised-asphalt/sandy-shoulder reference and requested it for Grass. GV01: retain the existing road and expose a 3–4 cm side. GV02: slope a nominal 35–60 cm sandy shoulder into grass. GV03: add restrained gravel, small stones and grass patches. G01/R01/Q01: preserve the original car/camera, canonical driving data, bounded preparation/caches and actual native-renderer evidence.

Grass asphalt now uses a real sloped shoulder, from Y=0.027 at the lip to Y=-0.038 at the existing grass skirt. The unchanged authored asphalt top is Y=0.062, leaving a 35 mm visible face; the original terrain at Y=-0.06 remains about 122 mm below the asphalt. The outer edge varies smoothly in world space. Nominal visible width is 0.35–0.60 m outside the rounded lip; corner miters follow the existing contour geometry. Dirt roads and the retired native raster fixtures keep their previous presentation.

The original asphalt top, bevel, side faces, markings, kerbs and bridge meshes are retained. The Grass-only lower flat fringe is replaced by contact shading in the slope's existing material. The existing cleared `desert_apron_v1.png` supplies fine mineral detail; no new bitmap, reference-image pixels or image generation are used. Small native five-facet pebbles and three-blade grass clusters share the shoulder draw and existing paint/privacy-free local preview masks. Deterministic world-cell placements cap at 2,048 details/30,720 vertices per track. The reference circuit emits 12,411 detail vertices. These details have no collision, lights, processing clock or simulation role.

`grass_road_verge.gd` reuses `ShoulderMesh` ownership and its parallel/cooperative clipping. A small virtual emission hook preserves the original flat emitter for other surfaces. Real slope and detail normals survive direct and worker preparation. The Grass material keeps the actual grit sampler during specialization; other roles still compile it away. Visual kit206 invalidates old road/editor/world artifacts. Existing 32 MiB road and 64 MiB prepared-world cache budgets remain. Concurrent Night terrain/barrel, spline and backend changes are retained and excluded from the task checkpoint.

Actual pinned Godot 4.7.2 results:

| Check | Result |
| --- | --- |
| Original reference fixture | 10 headless; 13 Compatibility; 13 Mobile; zero failures |
| Final slope, width, overlap ownership, actual stones/blades, artwork role, canonical data, unchanged other-biome road arrays and direct/prepared equality | 34 headless; 37 Compatibility; 37 Mobile; zero failures |
| Cooperative/parallel overlap fixture, over 512 source triangles | Included above: five checks; exact arrays and 48 m² union |
| Existing shoulder ownership/joins/internal contours | Union area30, 71 join checks and18 internal-contour checks; zero failures |
| Existing road-height/bridge suite, explicit visual-only mode | 58 checks; zero failures |
| Editor worker preparation, retained GPU/CPU arrays, live masks and memory bounds | Final geometry: 406 checks; zero failures |
| Disk road cache | 70 checks; zero failures |
| Prepared race/world cache | 85 checks; zero failures; one retained world within64 MiB |
| Final declared texture-unit budget | 63 checks; zero failures; maximum8 per material |
| Project parser | 837 scripts; zero failures |

Native before/final corner, low edge and bridge-mouth views are in `evidence/grass-verge-2026-10-16/{before,final}/{gl_compatibility,mobile}/`. These are actual Godot viewport captures; renderer appearance differs normally. `baseline-headless.json` and final renderer JSONs record actual array/source hashes. This is not an exhaustive all-track or physical-phone visual review, a performance benchmark or an AAA acceptance claim.

Initial issues are retained. The sandbox prevented Godot's Windows log/certificate-store access; native tests then ran with isolated workspace APPDATA outside the sandbox. The first narrow opposing-shoulder fixture exposed Boolean fragments with repeated vertices or widths below10 micrometres, whose unrenderable area carried the competing strip's height. Only these cosmetic slivers are omitted; the asphalt solver and its microscopic road triangles are unchanged. The exact area, height and parallel-equality assertions remain. The first grit refinement was aliased to the RGB factor map by the existing biome sampler optimizer, producing colored grain. Native review caught it; the Grass shoulder now retains its actual apron artwork and has an explicit specialization assertion. Initial views/logs are retained in `initial/`, `aliased-grit/` and `logs/`.

Commands actually run through the required entry point, with workspace-local APPDATA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd -TestArgument '--before'
# Also ran the preceding baseline with -Graphical -RenderingMethod gl_compatibility
# and with -Graphical -RenderingMethod mobile -RenderingDriver vulkan.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd -TestArgument '--profile-only'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd -TestArgument '--visual-only'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shoulders.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_loading_roads.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_cache.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

The historical grass-road test now identifies the approved sloped Grass shoulder separately from unchanged Storm sand. Its optional visual-only mode leaves the older physics comparison available and runs only the relevant road/support checks. No canonical simulation, compiler/physics contract, track document, backend or deployment changes are made by this task. Owner appearance and physical-phone moving-view/performance acceptance remain. No phone attachment check, phone test, APK export/install or deployment was performed.

Changed source: `game/track/grass_road_verge.gd`, `shoulder_mesh.gd`, `native_track_visual.gd`, `creator_road.gdshaderinc`, `surface_shader_variants.gd`; focused tests `game/tests/test_grass_verge.gd`, `test_grass_road_height.gd`; associated UIDs and project status/instruction files. Saved sources, exact final hashes, actual logs and a source-only task patch are under `docs/evidence/grass-verge-2026-10-16/`.
