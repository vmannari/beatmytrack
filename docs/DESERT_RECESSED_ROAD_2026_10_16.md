# Recessed Desert road — 2026-10-16

The owner requests the opposite of Grass: Desert roads below the surrounding terrain, with surface transitions unchanged. DR01 lowers the road bed. DR02 retains the original material transitions. DR03 keeps cars, effects, ghosts and placed objects seated. G01/R01/Q01 preserve canonical handling/bridge flight, immutable records, other biomes and bounded native preparation.

Desert uses an immutable presentation-only elevation field. Road/deck footprints receive an18 cm downward translation; the original authored road top0.012 becomes-0.168. Distant terrain remains at its original-0.06 datum, placing the road about10.8 cm below that terrain. The existing sandy apron rises smoothly back to the original ground over its existing footprint. Source X/Z geometry, material UVs, shader roles, textures, blend widths and transition functions are retained. No surface shader was edited by this change. Subdivision adds interpolated geometry only where needed to let large terrain/cover triangles follow the recess rather than cover it with a flat plane.

`BridgePresentation.visual_height_at` adds the cosmetic field to the existing pure elevation sampler. The inherited canonical `height_at`, physics0.63, compiler/rules, track cells/routes and stored ghost poses remain unchanged. Cars, tire marks, dust origins, contact shadows, checkpoint markers and replay ghosts use visual support. Movable props remain rigid; tire/prop/debris presenters apply the same field. Retained editor instance groups recompute support from original poses, including unchanged instances, without accumulating offsets.

The field is capped at8 MiB; temporary normal-sample caching caps32768 entries and clears after preparation. The existing prepared-world64 MiB limit now accounts for an extra four bytes per Desert grid cell. Direct road arrays/cache payloads remain original; the completed Desert world owns the deformed resources. Custom instance motion bounds gain downward extent, while automatic bounds remain automatic. Kit208 fences old presentation artifacts. No new texture, draw overlay, rendering world, runtime API, background job or external asset is introduced. Geometry/preparation work increases; no phone latency, memory or FPS claim is made.

Actual pinned Godot4.7.2 results:

| Check | Actual result |
| --- | --- |
| Original geometry/material baseline |10 headless;13 Compatibility;13 Mobile; zero failures |
| Final recess, original UV/material roles, other-biome exact meshes, five-car canonical traces, bridge support, independent scenery buffers, moving bounds and retained editor movement |48 headless;54 Compatibility;54 Mobile; zero failures |
| Existing prepared compilation/world ownership, exact restore, canonical driving and byte/entry limits |85 checks; zero failures; one retained world within67108864 bytes |
| Existing personal ghost persistence/selection/presentation |38 checks; zero failures |
| Final project parsing |839 scripts; zero failures |
| Scoped source patch |Reverse-application check and task-file whitespace check pass |

All five cars run240 canonical ticks using the pure elevation sampler and the same simulation supplied with `BridgePresentation`; snapshots match exactly. Actual native tests also verify instance color/custom data, moving tire height and retained editor placement. The terrain refinement fixture checks the original material UV projection to1e-6 and a depressed interior vertex. Full-world material shader roles match the saved original across all five biomes. All four other-biome mesh signatures remain exact. These are scoped checks, not an exhaustive all-track drive or an all-pixels-identical rendering claim.

Before/final corner, low edge and bridge-mouth views from both renderers, JSON signatures, source snapshots, logs and `task-only.patch` are under `docs/evidence/desert-recess-2026-10-16/`. Initial prepared-world testing exposed `MultiMesh.duplicate` assigning a buffer with incompatible formats/count, especially with the dummy renderer. Explicit format/count construction and a guarded buffer copy fix it; original colors/custom data and motion bounds are retained. Initial failure logs remain. Subsequent native checks cover retained editor poses and the distinction between automatic and custom bounds.

Commands actually run, with isolated workspace APPDATA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_recess.gd -TestArgument '--before'
# Baseline also ran with -Graphical -RenderingMethod gl_compatibility
# and -Graphical -RenderingMethod mobile -RenderingDriver vulkan.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_recess.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_recess.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_recess.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_personal_ghosts.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Changed runtime files: new `game/track/desert_road_relief.gd`; `native_track_visual.gd`, `bridge_presentation.gd`, `prepared_world_cache.gd`, `contact_shading.gd`, `breakable_prop_visual.gd`; `game/core/game.gd`; `game/ui/checkpoint_marker.gd`; `game/vehicle/skid_trails.gd`, `sand_dust.gd`, `rewind_ghosts.gd`. The new focused fixture is `game/tests/test_desert_recess.gd`; UIDs, this report and project instruction/status files complete the scoped checkpoint. Concurrent controls, Garage, backend and physics work is retained.

Owner appearance and physical-device moving-view/performance acceptance remain. No phone attachment check/test, APK build/install, backend modification/deployment or FPS measurement was performed.
