# Gradual biome car weathering — 2026-10-11

Owner requirements CW01–CW05: Desert dust especially on the sides; Winter snow/frost; Grass off-road mud; Night off-road mud; Storm wet grime. CW06 covers gradual accumulation, lifecycle and all five vehicles. CW07 incorporates the owner's correction: dirt originates at the tires and fans diagonally upward toward the rear, especially in Desert. CW08 extends the dirt across the rear body and bumper. CW09–CW11 follow the supplied rally-car dirt reference: dense lower-body film, fine irregular splashes thinning upward, and preserved rear/biome behavior. G01/R01 preserve simulation/competitive separation; V04/V05/V06 preserve the established presentation; Q01 records actual verification.

The next local run automatically applies race-owned weathering in races and untimed practice. A dense sill/lower-door film carries irregular short splash flecks, thinning upward like the owner's reference. Two rearward spray fans per side start near the actual front/rear tire locations, widening and rising toward the rear. Rear wake deposits also cover the tailgate's centre and rear bumper, strongest low down. The hood and upper front panels stay substantially cleaner. Winter adds powder and small icy highlights on upward panels. Storm darkens and glosses the paint, with streaked road grime and stronger off-road mud. Windows, lamp lenses, plate faces and tires retain their original materials. There is no new menu, label or setting.

## Behavior and files

- `game/vehicle/vehicle_weathering.gd` / `.uid`: reads canonical ticks, speed, grounded state and four wheel contacts using the existing read-only surface observer. Exponential accumulation stays within 0–1 and is independent of redraw rate. At 20 m/s, Desert reaches about 32% exposure after 15 seconds and 86% after 75; Winter about 28% and 81%. Mud accumulates only on loose/off-road wheel contact in Grass/Night, then persists on the road. Storm wetness approaches saturation over roughly a minute; road grime accumulates more slowly than off-road grime.
- `game/vehicle/vehicle_weathering.gdshader` / `.uid`: original opaque body-space tire-spray fans, dense lower-body film, clustered irregular droplets and vertical wet streaks. Wheelbase/span are converted from each car's physical config back to authored body coordinates; radius follows the existing visual wheel. The finish copies the original paint color, roughness, metallic, specular and clearcoat values, with separate cached PBR/toon variants. No transparent pass, extra geometry, screen/depth reads, image generation, external assets or downloads. Clean cars retain their original StandardMaterial3D surfaces; retry restores those same resources exactly.
- `game/core/game.gd`: six added lines for race ownership, initial biome setup, read-only presentation, retry reset and biome-change reset. Pause, countdown, finished coast and rewind preview cannot add buildup. A confirmed rewind retains the accumulated cosmetic coating and continues from the new tick. Race exit frees the race-owned effect.
- `game/tests/test_vehicle_weathering.gd` / `.uid`: all-five-car progression, road/off-road/bridge contact, stationary/airborne/roll, blocked state, repeated redraw, rewind preview, original livery, material restoration and 30/60/120 Hz equivalence. Actual Game integration confirms unchanged canonical snapshots, pause/retry and biome switch. Optional native captures inspect each biome, all cars in Winter and normal race cameras.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document: outcome and remaining acceptance. No physics/content/rules schema or golden fixture changes are needed for this cosmetic slice.

Exposure uses at most four additional wheel-cell queries per advancing presentation tick, then two scalar updates per prepared finish material. Long presentation gaps over one second are skipped to avoid sudden coating jumps. The shader uses fixed procedural noise; there are no per-particle CPU updates or persistent saves. The original body's mesh, collision, wheel span, handling, camera, five laps, records, race uploads and verification remain unchanged.

## Actual verification

All commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
python build/checkpoint_vehicle_weathering.py
```

Import passed. Initial headless progression passed 464 checks; expanded lifecycle passed 485 checks on desktop Mobile/Vulkan. Final native tire-spray capture runs pass 522 checks in Compatibility and Mobile/Vulkan, including five pixel-identical clean/reset comparisons on each renderer. Existing isolated application regression passes 99 checks. Test account/backend access is disabled; no real player race or score was submitted.

The controlled Compact showroom has exactly 72 draws and 108,604 triangles both clean and coated in Compatibility. Actual raw scene counts for both renderers are saved in `render-counts.json` alongside the captures. These are geometry/draw measurements on RTX 3090, not phone timings or thermal acceptance. The shader adds fragment work to affected paint surfaces but adds no passes or meshes.

Evidence: [clean](evidence/vehicle-weathering-2026-10-11/clean.png), [Desert tire spray, left](evidence/vehicle-weathering-2026-10-11/desert-tire-spray-left.png), [Desert tire spray, right](evidence/vehicle-weathering-2026-10-11/desert-tire-spray-right.png), [Desert](evidence/vehicle-weathering-2026-10-11/desert-75s.png), [Winter](evidence/vehicle-weathering-2026-10-11/winter-75s.png), [Grass mud](evidence/vehicle-weathering-2026-10-11/pine-75s.png), [Night mud](evidence/vehicle-weathering-2026-10-11/night_city-75s.png), [Storm](evidence/vehicle-weathering-2026-10-11/storm-75s.png), [Winter race camera](evidence/vehicle-weathering-2026-10-11/winter-gameplay-coated.png). Each biome also has a 15-second close-up, 75-second close-up, reset comparison and clean/coated race-camera pair. Mobile/Vulkan captures are under `mobile/`. Close-ups use the real shared car in an isolated studio; race-camera images use real Game scenes frozen for review with controlled 75-second exposure. They are not completed races or physical-device recordings.

Initial commands hit the host PowerShell execution policy and sandbox engine-log access; process-scoped execution-policy selection and approved local engine access resolved them. An exploratory StandardMaterial shader inspection used an unavailable API and was discarded; final code uses the original bounded shader and direct material properties. The first command-line array syntax was corrected to the actual `-Command` invocation shown above. Mud was refined after visual inspection to soften large flat patches. A later Mobile run failed all five clean/reset pixel comparisons because the initial studio reference was captured before cached radiance settled; warming the baseline for 60 render frames resolved the failure while preserving the exact comparison. The owner then corrected the deposition direction, and the final mask now uses actual axle positions and rearward/upward widening fans. No failed assertion was weakened or skipped.

## Remaining acceptance and checkpoint

DN2103 is attached according to ADB. **No physical-device test, Android export/install, full Validate, backend change or deployment was performed.** Owner acceptance of intensity/timing and phone shader performance, sustained real driving and varied tracks/bridges remain. The cosmetic state resets per race; it does not persist into the Garage or change vehicle performance. There are no added snow/mud geometry clumps or a washing/progression system.

The task-only Git checkpoint and binary patch are saved beside the evidence. The isolated repository under `build/vehicle_weathering/checkpoint-repo` preserves the main branch/index and unrelated work. Original shader code and authored procedural texture need no additional asset license.

## Rear coverage correction (CW08), 2026-10-11

The owner requested dirt on the rear as well as the diagonal side fans. `vehicle_weathering.gdshader` adds a rear-facing, behind-rear-axle wake mask that covers the full tailgate width, including the centre previously excluded by the lateral wheel mask. `vehicle_weathering.gd` also admits matte dark body plastics to the same existing finish, with a rear-only mask. This includes the rear bumper without adding geometry or dirtying front-facing trim that shares its batch. Existing side spray, accumulation timing, biome gates, pause/countdown/finish/rewind behavior, handling and score contracts are retained. Lamp emission, glass and plate lettering materials are excluded.

`test_vehicle_weathering.gd --capture-rear` captures all five cars directly from behind, clean and after 75 seconds in every biome, then checks exact clean restoration. Actual command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -TestArgument @('--capture-rear')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture-rear')"
python build/checkpoint_rear_weathering.py
```

Both final native runs pass **705 checks / 0 failures**, including 25 visibly coated rear views and 25 pixel-identical rear resets per renderer. The existing canonical-snapshot, contact, frame-rate and actual-Game lifecycle assertions remain. Compact clean/coated studio rendering stays at 72 draws and 108,604 triangles; no extra pass or mesh. Rear evidence is saved separately: [clean](evidence/rear-weathering-2026-10-11/compact-rear-clean.png), [Desert](evidence/rear-weathering-2026-10-11/compact-rear-desert.png), [Winter](evidence/rear-weathering-2026-10-11/compact-rear-winter.png), [mud](evidence/rear-weathering-2026-10-11/compact-rear-pine.png), [Storm](evidence/rear-weathering-2026-10-11/compact-rear-storm.png), plus all other cars and Mobile/Vulkan equivalents. These are controlled actual-model renders, not completed races or device recordings.

Only the weathering script/shader, its existing test and the status/plan/this document changed in CW08. A new task-only checkpoint under `build/rear_weathering/checkpoint-repo` records this follow-up independently of the earlier slice and other working changes. No physical-device test, Android export/install, full Validate, physics regression, backend action or deployment was performed. Owner rear-coverage preference and phone performance remain acceptance checks.

## Rally-reference pattern (CW09–CW11), 2026-10-11

The owner's rally-car photograph supersedes the broad cloudy/camouflage-like texture. The shipping shader now uses a denser continuous film at sill/lower-door height, smaller clustered splash droplets and a softer, increasingly sparse upward edge. Short flecks lean with the existing diagonal rearward tire fans. Mud has a heavier, darker packed lower layer; Desert retains sandy colour, Winter its snow/ice palette, and Storm its wet finish. Rear panel flecks use the lateral body coordinate, avoiding the horizontal bands produced by projecting side coordinates onto a rear-facing panel. Fine droplets fade into their average density once subpixel, reducing aliasing at driving-camera distances; this is not a measured phone-motion claim.

Only the existing shader and test change at runtime/test level. No exposure, contacts, matrices, binding, game/physics, default livery, geometry, records or eligibility changes. The white livery in evidence is an isolated diagnostic paint choice so the pattern can be compared with the reference; it is not saved to player settings. The owner's image supplies pattern guidance only: no image pixels, real car identity or sponsor branding are copied into shipping assets. Droplets and masks are original code with no new texture or license.

Actual final commands, pinned to the same engine and launcher:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -TestArgument @('--capture-reference','--capture-rear')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture-reference','--capture-rear')"
python build/checkpoint_reference_weathering.py
```

Each final run passes **769 checks / 0 failures**: the unchanged all-five-car lifecycle, frame-rate/contact and canonical-snapshot tests; 25 all-car rear coat/reset pairs; ten original/white side resets; controlled 15/75-second side and rear-corner views; and five normal-camera clean/coated pairs. A new actual-render check requires lower-door dirt to produce more than three times the upper-door colour change and a meaningful minimum change for both Desert and Grass mud. Its first version caught insufficient Desert film (Compatibility 0.066 lower / 0.009 upper; Mobile 0.049 / 0.007); the implementation's lower film and packed shading were strengthened, preserving the assertion. Final Compatibility lower/upper values are 0.142/0.011 for Desert and 0.398/0.049 for mud; Mobile values are 0.093/0.008 and 0.322/0.032. Fine droplets were also revised after review to remove regular dot spacing and rear striping.

Evidence is saved under `evidence/reference-weathering-2026-10-11`: [original Desert side](evidence/reference-weathering-2026-10-11/original-desert-75s.png), [white mud comparison](evidence/reference-weathering-2026-10-11/white-pine-75s.png), [white Desert comparison](evidence/reference-weathering-2026-10-11/white-desert-75s.png), [rear corner](evidence/reference-weathering-2026-10-11/original-desert-rear.png), plus all five cars from behind under `rear-cars/` and desktop Mobile/Vulkan equivalents. Native `render-counts.json` preserves scene measurements; Compact studio clean/coated remains 72 draws and 108,604 triangles. No additional passes/meshes or image lookups. These are controlled actual-model renders, not completed races or physical-device footage.

The new task-only checkpoint under `build/reference_weathering/checkpoint-repo` preserves the main index/branch and unrelated changes. Status/plan and this document are updated. No physical-device test, Android export/install, full Validate, physics regression, backend action or deployment was performed. Owner acceptance of the reference interpretation and phone appearance/motion/performance remain.

## Darker Grass off-road mud (CW12), 2026-10-11

The owner requests darker accumulating off-track dirt in Grass. The single Grass (`pine`) deposit colour in `game/vehicle/vehicle_weathering.gd` changes from `806247` to dark earthy brown `463225`. Existing off-road contact gating, gradual accumulation, side/rear splash pattern, shading, pause/reset and canonical state stay unchanged. Other biome colours are exact. The existing test gains a `--weathering-output=` capture destination so this follow-up's evidence does not overwrite the accepted reference captures, and a one-second studio-settling interval before each clean reference; no new assertions or test suite were introduced.

Actual commands use the same pinned launcher/engine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -TestArgument @('--capture-reference','--weathering-output=res://../docs/evidence/grass-mud-color-2026-10-11')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture-reference','--weathering-output=res://../docs/evidence/grass-mud-color-2026-10-11')"
python build/checkpoint_grass_mud_color.py
```

Both native runs pass **664 checks / 0 failures**, including the existing all-five-car road/off-road, persistence, pause/retry, canonical-snapshot and exact side-reset checks. Original paint/records remain unchanged. Actual Compatibility white-car lower-door colour change increases from 0.398 to 0.462, with upper change 0.070; the retained dense-lower-band assertion passes. Desert's 0.142/0.011 values remain exact. The first Mobile run failed five original-paint clean/reset comparisons while every white-paint comparison passed; allowing asynchronous studio preparation to settle before the baseline resolved this previously observed fixture issue. Exact assertions remain unchanged. [Grass mud on the original car](evidence/grass-mud-color-2026-10-11/original-pine-75s.png), [white comparison](evidence/grass-mud-color-2026-10-11/white-pine-75s.png), [rear corner](evidence/grass-mud-color-2026-10-11/original-pine-rear.png) and normal-camera pairs were inspected; desktop Mobile/Vulkan equivalents are under `mobile/`. These are controlled actual-car renders, not completed races or phone recordings.

CW12 changes only the colour constant, test capture destination, this document and status/plan. The task-only checkpoint is under `build/grass_mud_color/checkpoint-repo`; main index/branch and unrelated changes are preserved. No new shader, assets, handling, backend, deployment, Android export/install or physical-device test. Phone appearance and owner preference for the darker mud remain acceptance checks.

## Rims and slow background dirt (CW17–CW19), 2026-10-11

All five cars' rims now gather biome dirt/snow, with grain and washed patches attached to wheel rotation. A lighter complementary body coat has independent persistent exposure at exactly one twentieth of the main pattern's rate, including independent slow re-coating of washed areas. Existing local condition and Garage washing are preserved; legacy masks retain their mapping. Glass, lenses, plates and tire tread remain excluded. See [RIM_SLOW_WEATHERING.md](RIM_SLOW_WEATHERING.md) for files, additive storage fields, exact checks, captures and remaining owner/device acceptance. No physics, score, backend or deployment change.


## Persistent local dirt and Garage washing (CW13-CW16), 2026-10-11

The owner supersedes the race-owned reset behavior: retained per-car dirt, snow melting into smears of previous dirt, and manual Garage washing. All condition is local only. See [CAR_WASH.md](CAR_WASH.md) for the additive save contract, changed files, actual commands/results/screenshots, task-only Git checkpoint and remaining acceptance. Explicit offline/diagnostic clean resets remain available; race retry and biome changes retain dirt.
