# Winter wind visual revision — 2026-10-11

The owner rejected the first snow-wind effect as far below the AAA quality target. The first implementation's visual acceptance is withdrawn. This revision replaces its regular thin bands and flat bank cards with softer, broken sheets and small billowing bank rolls. **This is a revised experiment awaiting owner visual acceptance, not an AAA certification.**

Requirements WW05 (remove artificial repeated streaks), WW06 (connect powder to visible snowbanks), WW07 (review at normal driving scale with a moving car), WW08 (retain modest computation), alongside WW01–WW04, V04/V05, G01/R01 and Q01.

## Current behavior and files

- `game/track/winter_snow_wind.gdshader`: removes repeated sine stripes and the reused dust silhouette. Two samples from an original baked density/warp/grain field create uneven sheets with soft breakup and different lengths/widths. Bank drawing proxies face the camera while their centers follow the fixed world wind. Two soft wisps plus one sparse granular wisp use each existing source's three slots. Depth intersection and opaque-height clipping keep low powder below the car roof.
- `game/track/winter_snow_wind.gd`: reads visible bank geometry using its material role, which survives prepared-world batching that renames the mesh nodes. Anchors sit 6 cm above actual upwind bank vertices rather than below the higher rendered analytic crests. Geometry is prepared once; it can pick up a bank mesh after construction. A completed scan with no exposed points is not retried every frame. Contact-bank sources remain a bounded fallback for worlds without a matching visual mesh. No contact/collision geometry is changed.
- `game/core/game.gd`: passes the built track visuals into the existing weather node. This task owns only that one-line integration change; concurrent vehicle-weathering work is preserved and excluded from the checkpoint diff.
- `game/assets/textures/winter_wind_flow_v1.png` and `.import`: original 256×256 RGB data texture, 133,087-byte PNG, lossless import with mipmaps. R carries broad density, G carries smooth distortion, B carries fine powder. SHA256 `4f8b0ee626af36a174cd23e8a9275bac144ff2d91fb9126aeefa59627583f0e9`.
- `game/tests/bake_winter_wind_flow.gd` and `.uid`: deterministic offline baker using the already pinned Godot/FastNoiseLite engine, seeds 71041/38172/98123 and two octaves at frequencies 0.012/0.008/0.34. Two final builds produced the exact same PNG hash. The game loads the texture; it does not generate noise at runtime. Godot's [Noise API](https://docs.godotengine.org/en/stable/classes/class_noise.html) supplies seamless images; [FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html) is part of the engine.
- `game/tests/test_winter_snow_wind.gd`: retains original lifecycle/budget/canonical checks; adds actual visual-source lookup, an actual drawn Mobile shader smoke check, normal-camera canonical driving preview and moving opaque-roof pixel comparisons. Capture output moves to this revision's evidence folder so rejected evidence remains intact.
- `docs/WINTER_SNOW_WIND.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `licenses/ASSETS.md`: rejection, current evidence, provenance and pending acceptance.

All new density data and code are original project work. No reference image is copied or shipped, no new external library/provider is used, and the existing recorded wind/audio, frost, roads, bank materials, car geometry, camera contract and canonical physics are not edited by this task.

## Budget and measured checks

The maximum remains **81 ground cards plus 36 bank wisps: two draw calls, 117 quads/234 triangles**. The actual captured scene uses 10 source banks and 111 quads/222 triangles. There is no new particle-compute dispatch, light, shadow or full-screen pass. Bank selection remains local, bounded to 81 spatial buckets at 4 Hz. CPU presentation measurements across final runs were approximately 12–15 µs per update on this desktop.

Wider transparent sheets and two density samples cost more fill than the rejected narrow bands; equal draw counts do not prove equal GPU cost. Four alternating 120-frame measurements and raw CPU/GPU values are saved in [profile.json](evidence/winter-snow-wind-refinement-2026-10-11/profile.json). Shared desktop GPU activity caused timing variation. These are diagnostic desktop observations, not a precise incremental-cost or physical-phone claim.

Final checks: headless lifecycle 30/0; Compatibility graphical capture/driving 40/0; actual desktop Mobile/Vulkan draw/lifecycle 30/0; app lifecycle 99/0; final density rebuild byte-exact. The frozen capture retains 741 sampled roof pixels exactly. Three moving-car frames retain 708/708/683 sampled roof pixels exactly, with zero changed pixels in every comparison. Actual road cells, bank contacts and original simulation snapshots remain unchanged by weather presentation. The driving preview uses its own canonical simulation and restores the original race; no completed race, ticket, PB or upload is generated.

### Actual commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_winter_wind_flow.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
Get-FileHash -LiteralPath game/assets/textures/winter_wind_flow_v1.png -Algorithm SHA256
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
python build/checkpoint_winter_wind_refinement.py
```

An intermediate density candidate remained marbled/flat and was discarded. The first visual-source check failed because cached/batched geometry had lost the named bank node; material-role lookup fixed it without removing the assertion. Controlled captures explicitly resume the isolated effect after window-focus notifications while production background behavior remains tested and intact. Initial moving-roof checks sampled unscaled 1280×720 viewport coordinates against a 960×540 window image and found no roof; coordinate scaling was corrected and the exact zero-change requirement retained. The capture now advances HUD speed explicitly while controlling the review gust independently of the random audio opening. No threshold was relaxed to conceal an occlusion failure.

## Evidence and acceptance

[Normal-camera driving preview](evidence/winter-snow-wind-refinement-2026-10-11/driving-motion.html) contains 60 actual 960×540 frames at 12 fps, five seconds of canonical straight-line driving with a controlled strong/calm visual gust. It is a diagnostic fixture, not a full player race. [Driving still](evidence/winter-snow-wind-refinement-2026-10-11/driving.png), [stationary strong gust](evidence/winter-snow-wind-refinement-2026-10-11/gust.png), [same view without wind](evidence/winter-snow-wind-refinement-2026-10-11/before.png), [curve](evidence/winter-snow-wind-refinement-2026-10-11/bend.png), [curve motion](evidence/winter-snow-wind-refinement-2026-10-11/motion.html), [rotated camera](evidence/winter-snow-wind-refinement-2026-10-11/rotated.png), and [compact viewport](evidence/winter-snow-wind-refinement-2026-10-11/compact.png) are saved separately from the rejected pass. Captures have been visually inspected; owner preference for this density, shape and movement is still pending.

Actual logs, scoped patch and checkpoint manifest are saved alongside the evidence, using an isolated Git repository under `build/winter_wind_refinement/checkpoint-repo`. Main branch/index and concurrent work remain untouched.

ADB lists the attached DN2103 phone. **No physical-device appearance/performance test, Android export/install, full Validate, backend work or deployment was performed.** Device overdraw/frame pacing, thermal behavior, depth/MSAA on Mali/Adreno, sustained gust readability, all bridge layers and owner visual approval remain. Sparse high airborne snowfall is still outside this two-effect slice. Runtime visuals still share the existing recorded wind's envelope and fixed world direction; no separate scheduler/audio revision is introduced.
