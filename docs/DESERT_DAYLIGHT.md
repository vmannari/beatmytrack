# Desert road, stone kerbs and daylight

2026-09-24, V02/V04/V05/Q01, visual kit 59. Owner accepted the dune ground and supplied desert-road references. This explicitly supersedes the previous sunset requirement; a later lighting pass is deferred.

Desert road pigment is now muted sand/gravel with restrained baked mineral and broad variation. Desert creator roads omit painted white edge lines, retaining the timed finish line. Existing raised kerbs use alternating muted sandstone colours, preserving their shape, taper and physical behavior. Dunes retain their original artwork and relief; the previous sunset compensation is replaced with a daylight pigment balance. Desert now uses the same daylight angle, ambient light and sun as the Grass theme. Dust, traction, canonical cells, camera and all other biome palettes remain unchanged.

The shared packed-road shader adds one baked texture lookup for broad variation. No new textures, geometry, runtime noise or lights are added; removing the desert edge-line mesh reduces one material draw for applicable creator roads. These implementation costs are not a measured phone performance claim.

[Inspected gameplay capture](evidence/desert-daylight/road-and-kerbs.png). The original dune milestone comparisons are retained. The existing desert dust captures are refreshed with daylight; their legacy sunset-road filename remains for the capture harness.

Changed files: `game/track/track_theme.gd` (palette and daylight), `surface_detail.gdshaderinc` (road grain and dune pigment), `native_track_visual.gd` (kit version, desert edge lines and kerb material), `game/tests/test_desert.gd` (replace superseded sunset assertion with requested daylight assertion), plus status/plan/instruction documents and evidence. No canonical physics files changed.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot 4.7.2:

- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, 0 failures, including five-car deterministic replay, packed/loose traction, dust, biome isolation and material restoration. Two fewer material assertions than kit 58 because the edge-line material is absent.
- `-Action TestSurfaces`: 50 checks, 0 failures.
- `-Action TestBiomes`: 92 checks, 0 failures.
- `-Action ExportAndroid -QuickValidation`: successful import/startup, 74 driving, 18 catalog and 22 menu checks; APK exported successfully.
- Android SDK `adb install -r build/android/circuit01-debug.apk`: Success on attached DN2103, preserving player data.

Logs are saved beside the screenshot. Existing build-tools 35.0.1 fallback and two ObjectDB shutdown leaks in driving tests remain. No device rendering/performance test was performed in this pass. Owner review of road/kerb appearance and daylight, phone motion and thermal performance remain outstanding. Reference photographs are guidance only and are not copied into assets.
