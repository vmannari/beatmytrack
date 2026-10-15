# Localized Winter snow streams - 2026-10-14

The owner requests streams here and there at random rather than a uniform effect across the track area. This pass keeps the last approved slower visual travel and replaces the everywhere-positive density modulation with sparse local events.

- WIND19: `winter_wind_variation.gdshaderinc` uses deterministic world-coordinate hashes for individual event phase, position, size and duration. Each bounded18x10m allocation region has an independent8-13s clock; a3.2-5.2s event fades in/out, then remains completely clear. Each event chooses a fresh jittered center and unequal elongated extent. Soft support stays inside the allocation region, avoiding boundary cuts or appearance jumps when the next event is selected during its clear interval. The small transported texture streams break up this support; it is not a visible elliptical sprite.
- WIND20: opaque surface powder evaluates the event gate before its two flow reads and returns exact zero in clear areas. Air grains use the same world-coordinate gate and reject empty areas before the depth read. The bounded card fallback evaluates gates per fragment instead of interpolating density across whole cards. The normal game still submits zero floating ground/bank cards.
- WIND21/V04/V05/G01/R01/Q01: presentation wind15/cache kit194 updates expanded disk shader bodies. Retain12-18m/s phase travel, prior0.12-0.45 snow amount, thin streams, powder gain0.60,48 low air grains/96 triangles, original bank branch/artwork/geometry/camera/car-footprint/depth protection, vehicle-impact snow clouds and canonical driving/scoring. There are no added texture reads, particles, uniforms, CPU emitters, per-frame random allocations or saved-track changes. Randomness is cosmetic, coordinate-based and camera-independent; returning to a presentation clock recreates its pixels within each renderer.

New `test_winter_local_streams.gd` inherits the existing ground integration/driving/lifecycle/material-ownership/visibility suite. A diagnostic CanvasItem shader renders the actual shared GPU window function over144x90m rather than reimplementing it on the CPU. Times0/3/6/9s show12.0-16.2% positive window area on Compatibility and12.3-16.4% on Mobile. Actual fine powder occupies a subset of those windows; these percentages are diagnostic spatial coverage, not snow mass or a physical simulation. Time0 restores exactly after later times. Clear regions coexist with white cores, and independently timed events change the field.

An eight-second actual-world capture at the strongest gust retains the slower18m/s speed. Changed samples against the clear render at one-second intervals are3653/7180/12120/8713 Compatibility and3203/6067/10401/7478 Mobile. Coverage changes as local events emerge/subside. Paused/disabling/restored-ground pixels, moving opaque car interiors and canonical snapshots remain exact in their existing checks. The visible stills and mask captures were inspected; final perceived snow realism remains owner acceptance.

Actual commands use pinned Godot4.7.2.stable.official.ed1daf0bf through `scripts/dev.ps1` with process ExecutionPolicy Bypass:

| Wrapper arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_local_streams.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility83 checks,0 failures |
| Same command with `-RenderingMethod mobile` | Mobile/Vulkan83 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_road_cache.gd` |70 checks,0 failures |

Raw desktop enabled/disabled profiles are retained. Early empty-window returns reduce unnecessary powder evaluation, but no isolated performance improvement or phone FPS claim is made. No phone run/APK/install/deployment/full Validate was performed for this revision. A concurrent surface-binding guard change is preserved and excluded from the task-only source patch.

[Localized motion](evidence/winter-local-streams-2026-10-14/localized-motion.html), [Mobile motion](evidence/winter-local-streams-2026-10-14/mobile/localized-motion.html), [local event mask](evidence/winter-local-streams-2026-10-14/window-0.png), [actual world](evidence/winter-local-streams-2026-10-14/localized-2.png). Restart the client to load the shader revision. Checkpoint/source patch: `build/winter_local_streams`; main index/HEAD and concurrent work remain untouched.
