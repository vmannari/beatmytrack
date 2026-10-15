# Restrained Winter drifting snow ? 2026-10-14

The owner rejects the previous revision as too fast and excessive. This pass slows and reduces it while retaining the existing ground-material integration. Realism and visual quality remain owner acceptance questions.

- WIND16: `winter_snow_wind.gd` changes visual phase speed from28?36 to12?18m/s. The existing independent smoothed motion envelope remains. Snow amount now ranges0.12?0.45 instead of0.24?1.0.
- WIND17: `winter_ground_snow.gdshaderinc` reduces powder contribution gain/cap from0.88 to0.60. `winter_wind_variation.gdshaderinc` reduces stationary/temporal phase warp and crosswind drift amplitudes, reducing abrupt local surges while retaining local variation. The analytic stationary gradient remains positive within0.7525?1.2475. Thin-stream shape and white powder shading remain.
- WIND18/V04/V05/G01/R01/Q01: visual version14/cache kit193 invalidates serialized old shader bodies. Existing ground integration,48 low air grains/96 triangles, two ground texture reads, original snow-bank branch, geometry/artwork, camera, vehicle snow clouds, material ownership/restoration and canonical handling/scoring remain. No new sampler, geometry population or particle system.

`test_winter_snow_wind.gd` updates approved numerical speed/amount expectations. New `test_winter_wind_restraint.gd` inherits the actual ground, car visibility, driving, material ownership, lifecycle and canonical-state suite. It substitutes saved previous shader bodies into the same run-owned materials and compares modest gust0.25 at the same camera and clock. Previous travel30m/s and amount0.43 become13.5m/s and amount0.2025. Original resources are restored; the previous render restores pixel-exactly. The actual revised update moves0.45m per30fps frame and changes visible surface pixels.

Actual commands use pinned Godot4.7.2.stable.official.ed1daf0bf through `scripts/dev.ps1`, with process execution-policy Bypass and graphical access:

| Wrapper arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_wind_restraint.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility:84 checks,0 failures |
| Same command with `-RenderingMethod mobile` and explicit Mobile evidence output directory | Mobile/Vulkan:84 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_road_cache.gd` |70 checks,0 failures |

The revised/previous RGB change ratio against each clear render is0.3089 Compatibility and0.3128 Mobile. This is fixture-specific image contribution, not physical snow mass or opacity. The paired six-second motion capture compares the same scene/camera/time with the previous and revised material bodies. Opaque moving car interiors remain exact; Compatibility records one changed mixed MSAA boundary sample at frame80, within the retained boundary check. Canonical snapshots, pause/reset/background and material restoration checks pass.

Still captures were reviewed for the reduced contribution. The test's camera and motion previews support owner review; they do not establish a realistic/AAA result. The initial sandboxed cache test could not open its normal user log; the authorized retry passed. The initial log is retained. Raw desktop enabled/disabled profiles are retained, without a speedup or phone FPS claim. No phone run, APK export/install, deployment or full Validate was performed for this revision.

[Before/after motion](evidence/winter-wind-restraint-2026-10-14/comparison-motion.html), [Mobile comparison](evidence/winter-wind-restraint-2026-10-14/mobile/comparison-motion.html), [revised still](evidence/winter-wind-restraint-2026-10-14/revised.png), [driving motion](evidence/winter-wind-restraint-2026-10-14/driving-motion.html). Restart the client to load the new cache revision. Task-only checkpoint/source patch is under `build/winter_wind_restraint`; main index/HEAD and concurrent changes are preserved.
