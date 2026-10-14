# Whiter, denser wind-blown powder — 2026-10-13

The owner requests more realistic wind snow, specifically whiter colour and less transparency, with other improvements. `winter-wind-9` retains world-space gust advection and modest rendering budgets while making the powder more concentrated and locally irregular. Owner visual acceptance remains open.

## Requirements and files

- WIND01, white visible powder: `game/track/winter_snow_wind.gdshader` raises ground opacity0.25→0.50 and bank opacity0.29+0.14source→0.50+0.16source. Near-neutral white albedo replaces the grey-blue pigment; actual scene lights and shadows retain their cold shading. Lower filament thresholds make the existing directional field more legible.
- WIND02, snow character: the same fine texture channel makes denser grains/frayed gaps, with derivative filtering to reduce distant flicker. Ground sheets receive a shallow14mm oscillation suggesting saltation. `winter_wind_variation.gdshaderinc` produces stronger local pulses and quieter gaps, preserving the existing spatial shear. `winter_air_snow.gdshader` gives the24 sparse grains individual86–110% advection speeds, biased lower heights and faster small vertical variation; colour/alpha also become whiter/stronger.
- WIND03/Q01/V04/V05/G01/R01: `winter_snow_wind.gd` changes only its visual version. Keep49 ground sheets,36 bank layers,24 air grains, three batches and the578-triangle ceiling; texture sample counts, refresh intervals, placement, shared24m/s strong-gust travel, audio, camera and canonical driving remain. No new asset, terrain shader or runtime simulation is added. Extra arithmetic occurs in the shaders.

`game/tests/test_winter_wind_realism.gd` inherits the actual wind/local-flow/lifecycle/lighting/roof tests. Its paired comparison expands the saved previous variation include and renders previous/refined/restored previous shaders at a fixed world clock. `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record delivery.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with PowerShell process execution-policy Bypass and normal Windows certificate/graphics access. RTX3090 desktop graphics, not phone rendering.

| Actual arguments after `scripts/dev.ps1` | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_wind_realism.gd -Graphical -TestArgument @('--capture','--video')` | Final Compatibility:54 checks,0 failures |
| Same command with `-RenderingMethod mobile` | Final Mobile Vulkan:54 checks,0 failures |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached; no physical-device test performed |

Final paired previous-baseline restoration is pixel-exact. The comparison isolates mixed MSAA boundaries while the inherited suite separately retains normal-MSAA opaque-roof protection. An earlier comparison failed at two mixed edge pixels by only1/255; additional settling did not remove that quantization. The diagnostic now disables MSAA only for the same-settings previous/refined/restored comparison, then restores the original setting. The exact restoration assertion remains, as do all normal-MSAA car/roof assertions. Initial logs are retained.

Sampled cool-surface positive white-light contribution is7.495× the previous wind shader on Compatibility and2.580× on Mobile. This metric measures rendered contribution over the sampled fixture; it is not opacity, snow mass or a whole-image brightness multiplier. Moving opaque roofs remain exact at all three inspected frames. Actual GPU vertex probes retain spatial variation and pixel-exact paused motion; canonical snapshots are unchanged.

The inherited fixed-scene profile retains three additional wind draws. Desktop load varies across stages, so raw hidden/full timings do not establish a reliable isolated shader-cost change or phone FPS. Explicit capture readbacks and profiling can generate diagnostic hitch logs; these are not active-game frame-pacing measurements. The unchanged geometry/texture budgets are the bounded-cost constraint.

## Evidence and acceptance

[Previous](evidence/winter-wind-realism-2026-10-13/previous.png), [refined](evidence/winter-wind-realism-2026-10-13/refined.png), [stationary wind motion](evidence/winter-wind-realism-2026-10-13/motion.html), [normal-camera driving motion](evidence/winter-wind-realism-2026-10-13/driving-motion.html), [Mobile wind motion](evidence/winter-wind-realism-2026-10-13/mobile/motion.html), [Native profile](evidence/winter-wind-realism-2026-10-13/profile.json), [Mobile profile](evidence/winter-wind-realism-2026-10-13/mobile/profile.json).

Restart the client to load the revision. Owner review remains for whiteness/density, fast powder character and road readability in varied cameras and creator layouts. Sheets and sparse grains remain inexpensive visual proxies. No physical-phone test, Android export/install, full Validate, physics merge, backend test/deployment or live write was performed. Existing artwork provenance and bank-interaction effects remain.

The isolated task checkpoint/source patch is under `build/winter_wind_realism`. Main index/HEAD and concurrent work are preserved; large motion HTML remains in workspace evidence.
