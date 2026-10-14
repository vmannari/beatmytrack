# Denser, slightly slower wind snow — 2026-10-13

The owner requests further reduced transparency, more particles and slightly slower wind snow. `winter-wind-10` increases visibility while retaining the previous irregular white powder shape and world-space motion. This request supersedes the earlier unchanged airborne-count and speed constraints for wind snow only.

Requirements and changed files:

- WIND04: `game/track/winter_snow_wind.gdshader` raises ground opacity from 0.50 to 0.65 and bank opacity from 0.50–0.66 to 0.62–0.80. `winter_air_snow.gdshader` raises grain alpha from 0.58 to 0.72. Existing fraying, gaps, lighting and terrain/car/bridge depth protection remain.
- WIND05/Q01: `game/track/winter_snow_wind.gd` doubles airborne grains from 24 to a fixed 48 in the same instanced batch. Ground remains 49 sheets, bank powder 36 layers. Three batches remain; the submitted triangle ceiling rises by 48, from 578 to 626. No added texture reads or per-frame particle simulation.
- WIND06/V04/V05/G01/R01: calm and strong-gust advection speeds decrease by 10%, from 6/24 to 5.4/21.6 metres per second. The existing smoothed intensity floor gives 9.288 m/s settled calm travel. Individual grain speeds, local shear, gust variation, pause/retry behavior and camera are retained. Vehicle snow-bank clouds, terrain/bank artwork, physics and scoring are unchanged.

`game/tests/test_winter_snow_wind.gd` updates the actual fixed-count and one-second gust-travel expectations, plus motion-preview caption. `test_winter_wind_realism.gd` compares against this task's saved wind9 baseline, using its original 24 grains for previous/restored views and 48 for the revised view. Fixed-clock comparisons deliberately isolate opacity/count rather than speed; actual advection is checked separately. Status and phase-plan entries record delivery.

Actual commands used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with PowerShell process execution-policy Bypass and Windows graphics access:

| Command arguments after the wrapper | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_wind_realism.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility: 54 checks, 0 failures |
| Same command with `-RenderingMethod mobile` | Mobile/Vulkan: 54 checks, 0 failures |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached |

Both renderers restore the previous fixed-clock baseline pixel-exactly. Sampled cool-surface positive white contribution increases by 24.7% on Compatibility and 19.2% on Mobile; this is a fixture-specific rendered contribution, not a mass or opacity measurement. Normal-MSAA moving opaque roofs remain exact at all three inspected frames. GPU motion probes retain spatial velocity variation and exact paused pixels. Canonical snapshots remain exact.

Actual fixed-scene profiles show three wind draws and 554 additional submitted triangles with the fixture's active bank subset. Raw hidden/full desktop timing varies with load and does not establish incremental GPU cost or phone FPS. The explicit maximum remains 626 triangles. All testing here is desktop RTX3090 rendering, including the Mobile renderer; no physical-phone test, APK export/install, full Validate, backend test or deployment was performed.

[Previous](evidence/winter-wind-density-2026-10-13/previous.png), [revised](evidence/winter-wind-density-2026-10-13/refined.png), [wind motion](evidence/winter-wind-density-2026-10-13/motion.html), [driving motion](evidence/winter-wind-density-2026-10-13/driving-motion.html), [Mobile motion](evidence/winter-wind-density-2026-10-13/mobile/motion.html). Logs, comparisons, motion probes and profiles are saved alongside these captures.

Owner density/speed/readability review and physical-phone frame-pacing acceptance remain open. Restart the client to load the revision. The isolated checkpoint and source patch are under `build/winter_wind_density`; the main index/HEAD and concurrent work are preserved.
