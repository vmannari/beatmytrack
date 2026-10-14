# Spatially varying wind powder — 2026-10-13

The owner rejects uniform movement and powder appearance, requesting stronger speed variation over time and across space. `winter-wind-11` retains the white powder, fixed particle budget and slightly slower prevailing travel from wind10, while changing its transport field and morphology. Owner visual acceptance remains open.

Requirements and changed files:

- WIND07, spatial and temporal transport: `game/track/winter_wind_variation.gdshaderinc` uses a stationary, bounded world-space phase warp and unequal temporal gust phases. The along-wind phase gradient is strictly positive, 0.4945–1.5055, avoiding reversed folds. Local regions compress/accelerate or stretch/slow powder as it passes. There is no spatial multiplier growing with elapsed time or travel. Local density pulses use two unequal periods rather than a single shared pulse.
- WIND08, powder appearance: `game/track/winter_snow_wind.gdshader` makes shorter, finer packets with changing widths, deflection and coarse-density-dependent thresholds. White cores remain dense; gaps and packet shape change instead of uniformly fading every fragment. The stationary warp is evaluated in the fragment so overlapping cards share its exact world phase. Existing lighting, granular filtering and car/bridge/terrain guards remain.
- WIND09, related airborne motion: `winter_air_snow.gdshader` places its 48 grains through the same phase map using four bounded inverse iterations, with individual 72–125% travel rates. No per-frame CPU particle integration or new particle pool. Camera-follow membership wraps outside the visible fade region as before.
- Q01/V04/V05/G01/R01: `winter_snow_wind.gd` changes only its presentation version. Keep 49 ground sheets, 36 bank layers, 48 airborne grains, three instanced batches, 626 maximum submitted triangles, texture-read counts, 5.4/21.6 m/s prevailing endpoints, CPU placement intervals, camera, audio, vehicle bank clouds, terrain/bank appearance and canonical driving/scoring. Added shader arithmetic includes two stationary-warp sine evaluations per snow fragment and the bounded airborne inversion; no free phone-performance claim is implied.

`game/tests/test_winter_wind_flow.gd` inherits the existing world placement, lifecycle, lighting, car/roof visibility, normal-MSAA driving and GPU local-motion checks. It renders wind10/revised/restored wind10 with the same 48-grain population and fixed world clock. The comparison measures changed visible powder morphology rather than imposing the previous task's increased-brightness requirement on this appearance change. The original density test remains unchanged. `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record delivery.

The new GPU speed diagnostic uses the actual production phase map, interpolated vertex temporal offsets, screen derivatives converted to the world-wind basis and a finite-difference temporal rate. Solving that map measures local texture transport velocity rather than just random instance speeds. It tests a wider spatial range than the previous field, changes through unequal gust phases, exact frozen-clock pixels and unchanged canonical state. A known 21.6 m/s rendered calibration verifies renderer-specific readback decoding. These are visual phase velocities, not physical wind measurements or evidence of snow simulation.

Actual commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with PowerShell process execution-policy Bypass and Windows graphics access:

| Arguments after wrapper | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_wind_flow.gd -Graphical -TestArgument @('--capture','--video')` | Final Compatibility: 61 checks, 0 failures |
| Same command with `-RenderingMethod mobile` | Final Mobile/Vulkan: 61 checks, 0 failures |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached; no phone run |

At the diagnostic's fixed 21.6 m/s prevailing travel, the sampled Compatibility phase-speed range expands from 13.33–34.12 m/s to 9.80–65.49 m/s; Mobile expands from 13.84–34.19 to 10.70–65.14 m/s. Spatial ranges are about 2.7 times broader. Mean speed changes by approximately 4.4 m/s across the three sampled clocks. Calibration error is below 0.6 m/s on both renderers. Screenspace quantization and sampling affect these extrema; bank placement, visible density and particle velocities are not all represented by this diagnostic.

Previous fixed-clock baseline restoration is pixel-exact on both renderers. Normal-MSAA moving opaque roofs remain exact at all three inspected frames. Local-flow GPU probes retain spatial variation and exact paused pixels; canonical snapshots remain exact. Actual profiles retain three wind draws and 554 additional submitted triangles in this fixture's active bank subset, below the 626 maximum. Raw GPU/CPU timings are recorded but desktop load/readback effects prevent a clean incremental-cost or phone-FPS claim.

Initial diagnostic decoding incorrectly applied sRGB conversion to Compatibility's direct numeric unshaded output. It was corrected and a known-speed calibration added; initial logs are retained. An initial packet mask thinned the effect excessively and was replaced with changing density thresholds/widths retaining white cores. Final appearance captures and checks supersede those initial captures. No assertion was relaxed to accept failed car protection, canonical state or motion continuity.

[Previous wind](evidence/winter-wind-flow-2026-10-13/previous.png), [revised wind](evidence/winter-wind-flow-2026-10-13/refined.png), [wind motion](evidence/winter-wind-flow-2026-10-13/motion.html), [driving motion](evidence/winter-wind-flow-2026-10-13/driving-motion.html), [Mobile motion](evidence/winter-wind-flow-2026-10-13/mobile/motion.html). Profiles, calibrated speed reports, baseline snapshots and logs are saved beside the captures.

Restart the client to load the revision. Owner review remains for powder character, uneven local motion and readability across creator tracks/cameras. Physical-phone frame pacing and thermal acceptance remain untested. No APK export/install, full Validate, backend test/deployment or live write was performed. The task-only Git checkpoint/source patch is under `build/winter_wind_flow`, preserving the main index/HEAD and concurrent work.
