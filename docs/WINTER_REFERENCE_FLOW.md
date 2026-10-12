# Reference-led winter powder flow — 2026-10-11

The owner supplies a photograph after rejecting the previous attempts. The visual target is long, frayed powder fingers skimming the road, denser localized lift beside the upwind bank, and clear road between the flows. Revision 6 implements that direction in the game's existing overhead view. The reference's horizon, sky, roadside structures and darker asphalt are not adopted; the supplied photo is guidance, not a shipping asset. Owner visual approval remains pending.

Requirements WW20 (reference-led elongated/frayed flow), WW21 (localized bank lift settling onto road), WW22 (world lighting, camera-independent motion and opaque car readability), WW23 (modest bounded computation), plus V04/V05, G01/R01 and Q01. Physics, five laps, timing/scoring/upload contracts, vehicle forces, audio, car meshes and driving camera are unchanged.

## Files and behavior

- `game/track/winter_snow_wind.gd`: `winter-wind-6`. Fewer ground patches (49) with longer/narrower 14×2.1 m bounds; at most twelve banks with three 12×3 m layers each. Existing prepared upwind crests and local 4 Hz source lookup remain. Expanded bank bounds account for longer flow. Both batches still cast no new shadows.
- `game/track/winter_snow_wind.gdshader`: the shared advected density field is sampled at approximately 21:1 along/across anisotropy to form long branching fingers instead of rounded cloud lobes. Warped feathered edges, fine density breakup and a soft source onset remove the hard rectangular emitter border. A denser component stays near the bank and tapers into thinner fingers downwind. Lift remains near the source, fades by six metres and settles to the 6.5 cm road layer; it does not remain suspended over the entire road. Normals follow the profile, with existing scene lighting/snow albedo. A conservative solid-height guard supplements depth fading at terrain/car/bridge intersections. Full-gust advection remains exactly 24 m/s.
- `game/tests/test_winter_snow_wind.gd`: smaller fixed allocation contract; retained speed/lifecycle/canonical/static-roof/lighting checks and 30 fps actual driving/curve capture. Moving-car comparisons now verify direct single-sample opaque pixels and fully interior roof pixels in the normal MSAA view, with renderer settings restored before recording frames.
- `docs/WINTER_SOFT_FAST.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: reference interpretation, actual evidence and pending acceptance.

No core/game change, new bitmap/audio asset, runtime noise generation, library/provider or copied reference imagery. Existing density PNG remains SHA256 `4f8b0ee626af36a174cd23e8a9275bac144ff2d91fb9126aeefa59627583f0e9`; existing snow/texture provenance is retained.

## Cost and actual outcomes

Maximum **49 ground patches/36 bank layers, two draw calls and 530 triangles** (98 + 36×12), down from the preceding soft version's 594. The ten-bank capture adds 458 triangles (362,431 off / 362,889 on). Conservative unshaped card area is about 2,737 m² versus the previous soft version's 2,391 m²; longer/lifted layers increase fill/shading despite the smaller vertex budget. This is not a phone-overdraw or speedup claim. There is no full-screen effect or new shadow pass. CPU source/presentation work remains bounded and no physics is added.

Final measured desktop updates were about 10–13 µs. Four alternating 120-frame GPU medians were 1.904/1.681/1.937/1.425 ms (off/on/on/off); render CPU 2.276/1.956/2.294/2.032 ms on RTX 3090 Compatibility. Shared-machine timing varies; [profile.json](evidence/winter-reference-flow-2026-10-11/profile.json) is diagnostic evidence, not a precise incremental-cost or mobile benchmark.

Final focused outcomes: **headless 33/0, Compatibility capture/driving 47/0, desktop Mobile/Vulkan actual draw/lifecycle 33/0, app lifecycle 99/0**. Actual road/contact geometry and original simulation snapshots remain exact. Static normal-AA roof: 741 samples/zero changes. Moving single-sample opaque roof: 779/780/768 samples/zero changes. Moving normal-MSAA interior: 503/513/494 samples/zero changes; mixed silhouette boundary changes 1/0/0. The unlit lighting difference is zero versus 1,849.082 in the lit comparison, so the wind receives scene light. The affected-pixel fraction is logged at 28.33% for this strong-gust fixture; it is not a universal density limit or an all-scenes promise.

Initial captures correctly failed the overly broad warm-colour comparison on one pixel. Direct single-sample comparisons prove all opaque samples remain exact; normal-AA neighbourhood checks prove the change belongs to the blended silhouette, where the background snow legitimately contributes to colour. The opaque zero-change requirement remains strict in both direct and normal-AA interior checks. Runtime AA is unchanged, and the saved video frames use normal AA. Early rectangular source borders were feathered; persistent high road lift was confined to the bank. Failed/intermediate logs remain saved. An initial unapplied patch contained an empty dummy-path hunk and was corrected before modification/testing.

### Actual commands

```powershell
python build/caption_winter_reference.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
git diff --check -- game/track/winter_snow_wind.gd game/track/winter_snow_wind.gdshader game/tests/test_winter_snow_wind.gd
Get-FileHash -LiteralPath game/assets/textures/winter_wind_flow_v1.png -Algorithm SHA256
python build/checkpoint_winter_reference.py
```

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`. No full Validate, physics-regression suite, Android export/install, backend work or deployment was performed.

## Evidence and remaining acceptance

[Four-second 30 fps driving preview](evidence/winter-reference-flow-2026-10-11/driving-motion.html), [driving still](evidence/winter-reference-flow-2026-10-11/driving.png), [strong gust](evidence/winter-reference-flow-2026-10-11/gust.png), [without wind](evidence/winter-reference-flow-2026-10-11/before.png), [curve](evidence/winter-reference-flow-2026-10-11/bend.png), [30 fps curve preview](evidence/winter-reference-flow-2026-10-11/motion.html), [rotated camera](evidence/winter-reference-flow-2026-10-11/rotated.png), [compact view](evidence/winter-reference-flow-2026-10-11/compact.png) and [unlit comparison](evidence/winter-reference-flow-2026-10-11/unlit-lighting-check.png) are actual Godot renders. Previews contain 120 unique frames and a controlled strong/calm review cycle; the driving fixture uses canonical motion in a separate simulation, not a completed player race, and produces no competitive write. Captures were inspected for long/frayed streams, bank contact/lift and readable car/road. The photo clarifies direction; this does not claim an exact photographic match or owner-approved AAA quality.

Actual logs, scoped patch and checkpoint manifest are saved alongside evidence using `build/winter_reference/checkpoint-repo`; main branch/index and concurrent work remain untouched. Restart the client to rebuild the changed patch/pool geometry. **No phone/device test or attachment check was performed in this task.** Owner visual comparison, sustained-gust readability, phone fill/shadow cost and frame pacing, device depth/MSAA behavior and every bridge/terrain case remain pending. Flow is bounded presentation geometry and baked density, not a volumetric/fluid or vehicle-wind simulation.
