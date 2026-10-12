# Fine winter powder and harsh wind — 2026-10-11

The owner subsequently preferred the previous softer shape and requested trying it at this increased speed. [Soft shape with fast wind](WINTER_SOFT_FAST.md) restores revision 3's exact shader/geometry while retaining 24 m/s gusts and the 30 fps review. The grain-only density/geometry targets below are historical.

The owner rejects the fog-like broad sheets and asks for faster motion that reads as harsh wind. Revision 4 uses separate rounded powder grains and short wind trails, with visible clear space between them. Grains leave actual bank crests, lift briefly and skim the road; source contact, scene lighting and the world wind direction remain. Owner visual acceptance is still pending.

Requirements WW13 (powder grains instead of fog coverage), WW14 (harsh gust speed), WW15 (world contact, lighting and car readability), WW16 (bounded modest computation), plus WW01–WW12, V04/V05, G01/R01 and Q01. Physics, five laps, race clocks/scores/uploads, car handling/geometry, audio and the driving-camera contract are unchanged by this task.

## Files and behavior

- `game/track/winter_snow_wind.gd`: `winter-wind-4`, two MultiMesh batches containing at most 486 ground grains and 216 bank grains (six per 6 m cell, eighteen per source, twelve sources). Replaces the large sheets with small QuadMeshes. Source lookup stays local at 4 Hz; membership reuse skips uploads when nearby sources merely change rank. Ground buffers change only at spatial-grid transitions. There is no CPU motion integration per grain.
- `game/track/winter_snow_wind.gdshader`: staggered finite grain lifetimes, fixed-world downwind motion, small crosswind variation, a brief bank lift followed by road-height travel. Rounded soft edges use pixel derivatives to reduce harsh subpixel outlines. Strong gusts lengthen the short trail proxies. A shared advected field varies cluster opacity without filling the air between grains. The existing snow albedo, real ambient/directional/shadow light, depth intersections and no-shadow-casting policy remain. Removes all broad haze-sheet coverage.
- `game/tests/test_winter_snow_wind.gd`: retains canonical/lifecycle/lighting/static-and-moving-car checks; updates the bounded geometry test for fine grains. Adds the measured full-gust world travel and an image-space sparse-coverage check. Both driving and curve previews now contain 120 frames at 30 fps/four seconds so fast motion is reviewable. The driving preview still uses a separate canonical simulation and restores the original race without tickets, score writes or uploads.
- `docs/WINTER_WIND_GROUNDING.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: owner feedback, actual commands/results and acceptance limits.

The shared advection speed is **24 m/s at full gust**, up from 5.5 m/s. Individual grain speeds vary approximately ±15%, so strong-gust travel is about 20–28 m/s. The interpolation constants are 6–24 m/s; the existing 0.24 settled visual intensity floor gives 10.32 m/s before individual variation. Real races continue to use the recorded wind's smooth gust envelope; a controlled strong/calm cycle is used only for review captures. This is presentation motion, not a wind force applied to the vehicle.

Restart the local client so the new grain meshes and larger instance buffers are created. No new bitmap/audio asset or dependency; existing density PNG remains SHA256 `4f8b0ee626af36a174cd23e8a9275bac144ff2d91fb9126aeefa59627583f0e9`. Original shader/code, existing texture provenance and prior offline recipe are retained.

## Cost and actual checks

The maximum is **702 small grains, two draw calls and 1,404 triangles**. The actual capture has ten source banks, 666 grains and **1,332 additional triangles** (362,431 off/363,763 on). This uses more vertices than the prior sheets, but a much smaller transparent footprint. At maximum proxy scales/trail lengths, the summed horizontal card area is bounded at about 102 m² versus the prior 2,391 m² before culling/alpha shaping; this is a geometric bound, not a measured GPU-overdraw or phone-speedup claim. The shader uses one density lookup rather than the earlier two, plus existing snow/depth sampling and normal scene lighting.

Measured desktop presentation updates were approximately **0.059–0.085 ms** across recorded runs. Final four 120-frame GPU medians (off/on/on/off) were 1.326/1.613/1.994/2.408 ms; render-CPU medians 1.789/1.767/1.776/1.816 ms on RTX 3090 Compatibility. Timing drift/shared-machine activity prevents a precise incremental-cost conclusion. Raw [profile.json](evidence/winter-snow-powder-2026-10-11/profile.json) is saved; no phone-performance claim.

Actual results: final headless **33/0**, Compatibility capture/driving **45/0**, desktop Mobile/Vulkan drawn-shader/lifecycle **33/0**, app lifecycle **99/0**, scoped whitespace check clean and density hash unchanged. Full-gust shared travel covers exactly 24 world metres in one test second. Powder affects **1,395 of 70,325 sampled world pixels (1.98%)** at the comparison threshold, below the 8% clear-air bound; that is one fixture at strong gust, not an all-scenes coverage promise. Lighting-difference sum is 135.424 in the lit world and zero with illumination/reflections disabled. Frozen opaque roof: **741 sampled pixels, zero changed**. Moving roof: **709/713/709 sampled pixels, zero changed in all three frames**. Actual simulation snapshots, road cells and contact geometry stay exact.

### Actual commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
git diff --check -- game/track/winter_snow_wind.gd game/track/winter_snow_wind.gdshader game/tests/test_winter_snow_wind.gd
Get-FileHash -LiteralPath game/assets/textures/winter_wind_flow_v1.png -Algorithm SHA256
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' start-server
Start-Sleep -Seconds 2
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
python build/checkpoint_winter_powder.py
```

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. No focused failure occurred. Initial headless 32/0 preceded the speed assertion; capture 44/0 preceded the added sparse image check, with final 45/0 including both. Bank allocation/budget expectations change to the explicit bounded grain design; canonical, exact-roof and lifecycle requirements are retained. No full Validate, physics regression, Android export/install, backend work or deployment was performed.

## Evidence and remaining acceptance

[Four-second 30 fps driving preview](evidence/winter-snow-powder-2026-10-11/driving-motion.html), [driving still](evidence/winter-snow-powder-2026-10-11/driving.png), [strong-gust still](evidence/winter-snow-powder-2026-10-11/gust.png), [without wind](evidence/winter-snow-powder-2026-10-11/before.png), [curve](evidence/winter-snow-powder-2026-10-11/bend.png), [30 fps curve motion](evidence/winter-snow-powder-2026-10-11/motion.html), [rotated view](evidence/winter-snow-powder-2026-10-11/rotated.png), [compact viewport](evidence/winter-snow-powder-2026-10-11/compact.png) and [unlit check](evidence/winter-snow-powder-2026-10-11/unlit-lighting-check.png) are actual Godot renders. Both previews have 120 unique frames and contain a controlled strong/calm review gust. The driving preview is a short canonical fixture, not a completed player race. Captures were inspected for distinct grains, short trails, clear road/car and faster sideways movement. Earlier fog-like revisions remain preserved.

The task-only patch/checkpoint manifest and actual logs are saved alongside this evidence, using an isolated repository under `build/winter_powder/checkpoint-repo`; main branch/index and unrelated work are untouched.

The settled ADB check returned **no connected devices**. **No physical-device test was performed.** Owner approval of powder size/density and harsh-wind motion, phone frame pacing/thermal/CPU upload cost, fast-grain aliasing on different render scales, Mali/Adreno depth/MSAA and every track/bridge combination remain. Drawing proxies are sized for overhead visibility, not literal physical snow-grain dimensions. No higher airborne snowfall, fluid simulation, car wind force or score-contract change is introduced.
