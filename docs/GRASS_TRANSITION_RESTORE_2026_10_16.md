# Grass material transition correction — 2026-10-16

The owner rejects the smoother sand edge and requires surface-material transitions as before. GVT01 restores the original Grass sand-to-grass footprint and normalized material coverage. GV01/GV02/GV03 retain the exposed asphalt face, new sloped cross-section and bounded native stones/grass. G01/R01/Q01 preserve canonical data, original asphalt/bridges/car/camera, caches and actual native-renderer evidence.

The first verge revision compressed the original blend into its new narrow slope. It retained the old shader function, but the shorter world-space footprint made the edge look smooth. Grass now uses the original `RoadSurfaceHeight.width` outer contour again. Its original material UV range spans that contour, including the previous world-space irregularity and `shoulder_fringe`/painted-surface transition functions. Those shared material functions and all painted-terrain code remain unchanged.

The physical cross-section is independent: an inner strip sits beneath the unchanged road, the 35–60 cm slope drops from0.027 to-0.038, and a flat outer extension carries the rest of the original material blend. The asphalt top remains0.062, retaining its35 mm exposed face. Height is interpolated from frozen per-triangle planes in both cooperative and parallel emission. Pebbles/blades seat on those actual planes, share the existing draw and keep the2048-detail bound. Contact shading follows height rather than the restored broad material UVs. Visual kit207 fences old prepared/editor/disk artifacts. No canonical or backend contract changes.

Actual pinned Godot4.7.2 checks:

| Check | Result |
| --- | --- |
| Focused width/material-footprint, slope/normal, clipping, bounded details, actual artwork, original road/canonical data, direct/prepared arrays | 37 headless;40 Compatibility;40 Mobile; zero failures |
| Actual corner, close edge and bridge-mouth captures | Three corrected views per renderer, with the rejected narrower views retained under `before/` |
| Existing shoulder ownership, joins and internal contours | Union area30,71 join checks and18 internal-contour checks; zero failures |
| Disk cache |70 checks; zero failures |
| Editor worker, retained GPU/CPU arrays, live masks and cache bounds |406 checks; zero failures |
| Project parser |832 scripts; zero failures |

`docs/evidence/grass-transition-restore-2026-10-16/` contains actual logs, before/final captures, saved pre-correction sources, hashes and a correction-only patch. The original pre-verge comparison remains under `grass-verge-2026-10-16/before/`. This restoration preserves the previous transition footprint and shader treatment; changed surface elevation, lighting, added grit and tiny native details prevent an all-pixels-identical claim.

The initial headless check retained one height-bound failure: single-precision plane evaluation slightly overshot the authored range. The interpolation now clamps to the original minimum/maximum; the assertion is unchanged and all focused runs pass. No source invariant was weakened.

Commands actually run, using workspace-local APPDATA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_verge.gd -TestArgument '--evidence=res://../docs/evidence/grass-transition-restore-2026-10-16/'
# Same focused script also ran with -Graphical -RenderingMethod gl_compatibility
# and -Graphical -RenderingMethod mobile -RenderingDriver vulkan.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shoulders.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_cache.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_loading_roads.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Changed source: `game/track/grass_road_verge.gd`, `shoulder_mesh.gd`, `native_track_visual.gd`, `creator_road.gdshaderinc`, and the existing `game/tests/test_grass_verge.gd` fixture/evidence destination. Project status/instructions record this newer correction. Concurrent changes are retained. Owner appearance and physical-device acceptance remain; no phone attachment check/test, APK build/install, backend change/deployment or FPS measurement was performed.
