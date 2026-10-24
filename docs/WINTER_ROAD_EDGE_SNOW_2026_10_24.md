# Winter snow from road edges — 2026-10-24

WRE01 anchors snow-emission windows at the exposed upwind road boundary. WRE02 preserves the accepted effect: stream/grain shape, texture, colour, opacity, speeds, gust parameters, lighting, car protection and particle budgets. WRE03/R01/G01/Q01 cover world/curve alignment, lookup bounds, lifecycle, canonical data and native review.

The shipping effect is integrated into opaque road/snow materials, with a small airborne grain layer. Moving just the inactive fallback-card anchors would not change ordinary gameplay. A static wind-aligned source lookup now supplies actual road-entry positions to the existing shared local-window function. Each unchanged elliptical window is translated so its upwind tip begins at that boundary; grains and streams continue downwind using the existing field. The normal window radius/lifetime/speed calculations remain. The presentation integrator body is text-exact against task entry.

Source preparation uses the same authored road contours, 16 cm finish extension and spline surface tessellation as rendering. Scanline intervals are merged across road pieces, so internal joins do not become emitters. Current native grids without authored pieces use actual road-cell runs. Bridge-covered origins are omitted. The simulator/world-XZ side-axis sign is explicit. The single nearest-sampled float lookup is at most 512x512 (4 MiB); the native fixture is 96x16 (24 KiB) with ten road-edge origins. Large worlds coarsen lookup spacing. There is no per-frame road scan, extra particle population, new art, camera or audio change.

Private run-owned materials share the lookup; prepared materials retain their original defaults and the existing release/restore lifecycle. `winter-wind-17-road-edge-sources` and visual-kit214 invalidate cached flattened shaders so an old cached road cannot silently retain the old interface.

## Actual validation

Pinned engine 4.7.2.stable.official.ed1daf0bf; desktop RTX 3090. Logs, source hashes and checkpoint are in [report.json](evidence/winter-road-edge-snow-2026-10-24/report.json).

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_road_edge_snow.gd -CommandTimeoutSeconds 240` — 38 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_road_edge_snow.gd -Graphical -RenderingMethod mobile -TestArgument @('--capture') -CommandTimeoutSeconds 300"` — 59 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_road_edge_snow.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--capture') -CommandTimeoutSeconds 300"` — 59 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -CommandTimeoutSeconds 240` — 34 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_ground_snow.gd -CommandTimeoutSeconds 240` — 34 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBiomes -CommandTimeoutSeconds 180` — 108 checks, 0 failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 240` — 1117 scripts, 0 failures.

The source test checks every prepared origin against the exact road polygons, verifies outside/inside along the wind at straight and curved boundaries, enforces lookup bounds and compares authored content/cells/contact triangles byte-exactly. Existing lifecycle, 49/36 fallback layers, 48 airborne grains, 12/18 m/s motion, strengths, pause/background/retry/finish/biome isolation remain.

The native test runs the actual Winter Game. All run-owned opaque finishes share the correct lookup, and fallback cards remain disabled in the integrated path. A GPU comparison evaluates the task-original window and the relocated window at seven clocks over their matching support. All three output channels are pixel-exact (maximum error0) on both renderers. A separate positive-output check excludes an empty comparison. Ground/bank/air grain shaders, the flow bitmap and the wind audio controller are byte-exact against task entry.

Native normal-camera before/after captures change 26690/31749 pixels, while the relocated snow itself remains visible (4276/5795 perceptible pixels in the sampled frames). At each of six clocks, every sampled opaque car-roof pixel is exact. A visibility toggle restores exact frozen snow pixels; simulation snapshots remain unchanged.

[Native motion and before/after preview](evidence/winter-road-edge-snow-2026-10-24/preview.html). Both renderer selections, three comparison states and seeking are checked in the existing Edge browser. Captures are actual Godot output, without image editing. Readback hitch diagnostics are not FPS measurements.

## Corrections, files and acceptance

The first capture launch exposed PowerShell's single-flag array binding; an explicit argument array fixes it. The first GPU reference used a compile-time constant random key and differed at one clock; feeding both functions the same runtime key yields zero error without changing the effect or threshold. Initial logs remain. A concurrent Game tutorial/rewind change is preserved and excluded from this task's patch.

Runtime files: `game/track/winter_road_snow_sources.gd`, source binding/version in `game/track/winter_snow_wind.gd`, source relocation in `game/track/winter_wind_variation.gdshaderinc`, and only the cache version in `game/track/native_track_visual.gd`. `game/tests/test_winter_road_edge_snow.gd` provides focused verification. This document, three status entries and scoped evidence helpers complete the slice. No existing invariant was weakened. The scoped checkpoint uses task-entry snapshots; status snapshots are refreshed immediately before publication to preserve concurrent prefixes.

Owner recognition on the affected track and sustained phone/tablet appearance/GPU sampling cost remain acceptance checks. Source placement necessarily changes which places emit; the effect's rendering/motion controls remain. No phone/tablet attachment check or physical-device test, APK/export/install, native rebuild, live account/backend mutation, deployment or owner-process restart was performed. Reload the development client to load the new shader/cache interface. Concurrent work and existing owner processes remain intact.
