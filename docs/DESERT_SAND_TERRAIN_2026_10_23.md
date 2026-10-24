# Desert sand: terrain colour and frequency, 2026-10-23

The owner likes the RSP HTML preview and requests a closer terrain colour match and slightly more frequent appearances. This is a small refinement of that accepted direction.

- **STC01:** airborne sand now uses `TrackTheme.DESERT[2]` (`c1a478`), the existing loose-sand terrain palette, in place of the separate grey `b8b1a7` tint. A 0.90 linear pigment multiplier keeps the red-channel brightness close to the previous powder, preserving its soft contrast under Desert light.
- **STC02:** independent burst periods change from 6–11 to 5–9 seconds and skipped cycles from 12% to 10%. This is about 24% more nominal burst starts, based on the mean period and skip probability; it is not a measured player-session percentage. Burst size, individual lifetime, drift, lift and opacity remain as in the preview the owner liked.
- **G01/R01/Q01:** keep the same six separated crest sites, 48 quads/96 triangles, density asset, depth/roof guards and lifecycle. Terrain artwork/geometry, camera, wind audio, vehicle dust and canonical driving are unchanged by this task. More frequent transparency can increase fragment work; no device performance improvement is claimed.

Runtime changes are limited to `game/track/desert_sand_wind.gd` and its shader. The existing focused fixture writes a new evidence folder and adds a rendered hue comparison against the terrain palette. It retains the existing mutedness limit of 0.16, no bright saturated specks, contrast p99 below 0.20, visibility/quiet checks, exact opaque-roof checks and canonical/lifecycle assertions. No asset or external dependency is added.

[Desktop Mobile motion](evidence/desert-sand-terrain-2026-10-23/mobile/motion.html) and [Compatibility motion](evidence/desert-sand-terrain-2026-10-23/gl_compatibility/motion.html) use the normal driving camera. Each folder also retains before/gust/calm/detail/palette/occlusion images and JSON measurements. The neutral-floor palette fixture is an isolation view; driving views retain the original warm sun veil. The earlier RSP preview and evidence remain available for comparison.

<!-- CHECKS -->

Native verification: focused **55 headless / 68 Compatibility / 68 desktop Mobile**, Desert **87**, ambience **111**, biomes **108** and parser **1031 scripts** pass. Both renderers retain 784 exact roof pixels and zero bright saturated specks. Rendered terrain-hue errors are 0.0021/0.0175 of a hue turn, with saturation 0.082/0.133 and contrast p99 0.086/0.137. Hardware is an RTX 3090; desktop Mobile is Vulkan on Windows, not a tablet measurement.

Actual commands, source hashes and the scoped checkpoint are in [report.json](evidence/desert-sand-terrain-2026-10-23/report.json). Tests use the pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with normal Windows certificate-store access. Representative commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -CommandTimeoutSeconds 300
.tools/review/Scripts/python.exe docs/evidence/desert-sand-terrain-2026-10-23/encode_preview.py
```

The initial Mobile run already passed the original 0.16 saturation threshold numerically. An unnecessarily broad temporary hue-test limit was restored to 0.16 before final checks; the initial receipt is retained as `mobile-initial.log`. Both final renderers use the strict colour criteria. Screenshot readbacks can emit `RACE_HITCH`; they are not gameplay frame-time measurements.

The task-only patch compares the three code/test files with their saved preceding versions and adds this document, evidence helpers and additive status updates. Concurrent work is preserved. Client reload and owner acceptance of colour/cadence remain, along with sustained physical-device appearance/performance acceptance. No phone/tablet attachment check or physical-device test was performed. No APK/export/install, account/backend mutation or deployment was performed.
