# Winter stream speed and grain refinement - 2026-10-14

The owner requests more varied speed, less transparent snow and a grainier pattern. Keep the previously requested scattered local events and clear gaps.

- WIND22: the shared `snow_local_event` returns the existing gate plus an integrated per-event phase offset and speed derivative. Each event has a different speed bias, plus a2.4m/s sinusoidal surge with its own phase/frequency. The finite-age integral resets only while the event is invisible; there is no unbounded travel multiplier stretching the pattern during a long race. The base envelope remains12-18m/s. Actual opaque ground and fallback streams use the local phase;48 small air grains have different speed biases and bounded acceleration phases.
- WIND23: opaque ground powder uses small irregular analytic grains, a skewed coordinate basis and randomly empty grain cells. The existing fine texture channel varies grain sizes. Screen derivatives filter the shapes at distance. Denser white cores use the square-root amount response and0.92 gain (capped0.85), while faint fill between grains falls from0.22 to0.012. Broad stream cores are strengthened locally. Air and the standalone card fallback use a denser amount response too. No texture read or geometry population is added.
- WIND24/V04/V05/G01/R01/Q01: wind16/cache kit197 refreshes expanded shader bodies. Keep world/ground integration, independent8-13s event periods/3.2-5.2s lifetimes, exact-zero clear areas,48 air grains/96 triangles, two flow texture reads, zero integrated floating-card submissions, original Winter bank branch, terrain/road artwork, camera, local condition, vehicle bank snow clouds and canonical handling/scoring. Concurrent grass/road-height and racing-render changes are preserved and excluded from the scoped patch.

New `test_winter_grain_speed.gd` inherits the existing integration/local-event/driving/material-restoration/visibility suite. It renders the actual shared GPU event and phase functions to measure active stream variation, rather than reproducing the formulas on the CPU. A calm12m/s phase base produces5.52-18.45m/s sampled along-wind phase speeds in Compatibility and5.52-18.32 in Mobile; this is a shader-phase diagnostic, not physical wind measurement. At0.5s separation,9870/9801 active-core samples change by more than1m/s. Returning to the prior presentation clock restores exact speed-field pixels.

The grain probe renders the shipping powder function and the saved previous body at960x576 over40x24m, matching roughly the gameplay pixel density. The99.5th-percentile coefficient rises0.1412 ->0.2078 on both renderers. Neighbor contrast relative to total contribution rises0.4059 ->1.9872 Compatibility and0.4006 ->1.9467 Mobile. These are fixture-specific coefficients and image metrics, not physical snow opacity or mass. Diagnostic masks and actual-world captures were visually reviewed. Scattered grain shapes replace the prior smooth texture-only fill.

Actual commands use pinned Godot4.7.2.stable.official.ed1daf0bf through `scripts/dev.ps1`, with process ExecutionPolicy Bypass:

| Wrapper arguments | Final outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_grain_speed.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility88 checks,0 failures |
| Same command with `-RenderingMethod mobile` | Mobile/Vulkan88 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_road_cache.gd` |70 checks,0 failures |

Initial attempts are retained: increasing fine texture frequency filtered it into softer/weaker powder and failed the grain checks; resolved procedural clumps corrected that. One initial Mobile capture changed32 warm-roof pixels by1RGB unit; final static/moving roof and pause/restoration checks pass with assertions unchanged. A concurrent road-height edit temporarily removed a called shoulder interface; it published its matching native visual edit before the successful retry. An invalid four-scalar shader matrix constructor was corrected to vector columns. No runtime backend or assertion relaxation was used to obtain the final passes.

Raw enabled/disabled desktop profiles are retained without a phone FPS/speedup claim. No phone test/APK/install/deployment/full Validate was performed for this revision. Owner acceptance remains for perceived speed variation, grain size/density and creator tracks/camera modes.

[Actual localized motion](evidence/winter-grain-speed-2026-10-14/localized-motion.html), [Mobile motion](evidence/winter-grain-speed-2026-10-14/mobile/localized-motion.html), [grain coefficient comparison: previous](evidence/winter-grain-speed-2026-10-14/grain-previous.png) / [revised](evidence/winter-grain-speed-2026-10-14/grain-revised.png), [driving motion](evidence/winter-grain-speed-2026-10-14/driving-motion.html). Restart the client to load the shader revision. Task-only checkpoint/source patch: `build/winter_grain_speed`; main index/HEAD are untouched.
