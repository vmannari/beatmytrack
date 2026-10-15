# Fast, light drifting snow — 2026-10-14

The owner supplies [Facebook](https://www.facebook.com/geologyintheuniverse/videos/drifting-snow-across-a-highway-in-iceland-blowing-snow-or-wind-blow-snow-is-snow/296757598180727/) and [Reddit](https://www.reddit.com/r/oddlysatisfying/comments/1pxwdqs/snow_blowing_across_a_road_in_iceland/) video references, emphasizing very fast motion without needing dense/strong-looking snow. The Reddit post was readable, but Facebook retrieval and direct media/poster playback were blocked; bounded public-media download attempts returned403. No frame-by-frame reference inspection is claimed. Implementation follows the owner's description; reference footage is not a shipping asset.

`winter-wind-13` keeps powder in the actual opaque ground materials and changes its motion/shape:

- WIND13: `game/track/winter_snow_wind.gd` separates the motion envelope from snow amount. Sparse settled coverage remains0.24 while prevailing visual phase travel is28 m/s, instead of the previous9.288 m/s. Dense gust travel reaches36 m/s, instead of21.6. A separate smoothed motion envelope preserves speed changes between these endpoints. Pause/background freeze both envelopes and retry resets them. These are game presentation values, not measured wind speeds in the reference videos or changes to canonical wind forces.
- WIND14: `winter_ground_snow.gdshaderinc` changes broad nearly isotropic patches into narrower wind-aligned streams and trailing grains. Higher density thresholds leave more clear road between streams while retaining white cores. Local spatial/temporal variation, actual surface shading, car-footprint protection and low grain height remain.
- WIND15/Q01/V04/V05/G01/R01: `native_track_visual.gd` changes only the visual cache revision to192 so serialized shader bodies load the new pattern. Keep48 grains/96 triangles, zero floating-card submissions when surface support exists, two surface texture reads, original artwork, material ownership/restoration, geometry, camera, audio, vehicle bank-impact clouds and canonical handling/scoring. Motion adds one bounded scalar envelope; there are no new assets, samplers or particle systems.

`game/tests/test_winter_snow_wind.gd` updates the approved gust-speed expectation, proves fast sparse travel and includes the new envelope in pause/background/retry checks. Motion-preview captions reflect the current speed/ground behavior. New `test_winter_fast_spindrift.gd` inherits the ground/visibility/driving/lifecycle/material-isolation suite. Its actual fixed-clock captures compare sparse versus dense coverage, restore sparse pixels exactly, show sparse movement over one30fps frame and retain exact canonical state. A six-second dedicated light-powder motion preview prevents reviewing only the densest gust case. Status and phase-plan entries record delivery.

Actual commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`, with process execution-policy Bypass and Windows graphics access:

| Arguments after wrapper | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_fast_spindrift.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility:78 checks,0 failures |
| Same command with `-RenderingMethod mobile` | Final Mobile/Vulkan:78 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_road_cache.gd` | 70 checks,0 failures |
| `-Action Import` | Final retry passed |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached; no phone run |

Sparse powder at0.24 coverage travels0.933333 m per30fps frame. The fixed-clock dense-to-light RGB image-difference ratio is4.168 on Compatibility and4.067 on Mobile; this measures fixture-specific rendered change, not snow mass or a physical opacity ratio. Sparse pixels restore exactly after increasing and then reducing coverage. Actual sparse surface pixels visibly change as travel advances. Initial and moving opaque/mixed car roof checks, paused/restored ground pixels and canonical snapshots pass unchanged.

The first Mobile attempt could not resolve its inherited test class. Initial import reported an unrelated account-controller preload failure; refreshed registrations allowed the isolated test retry to pass, and final import completed cleanly. Initial logs are retained; no backend source or assertion was changed to resolve these transient registration issues.

Raw desktop GPU/CPU profiles are retained; they are not an isolated speedup measurement or phone FPS result. Geometry, sample counts and instancing remain bounded. No physical-phone test, APK export/install, full Validate, backend test/deployment or live write was performed. Owner acceptance remains for perceived speed, thin-stream character and visibility on varied creator tracks/cameras.

[Fast light motion](evidence/winter-fast-spindrift-2026-10-14/fast-light-motion.html), [Mobile light motion](evidence/winter-fast-spindrift-2026-10-14/mobile/fast-light-motion.html), [sparse still](evidence/winter-fast-spindrift-2026-10-14/sparse.png), [dense still](evidence/winter-fast-spindrift-2026-10-14/dense.png), [driving motion](evidence/winter-fast-spindrift-2026-10-14/driving-motion.html). Restart the client to load the revision. Task-only checkpoint/source patch is under `build/winter_fast_spindrift`; main index/HEAD and concurrent changes are preserved.
