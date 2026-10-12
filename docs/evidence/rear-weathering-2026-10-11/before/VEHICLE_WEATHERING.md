# Gradual biome car weathering — 2026-10-11

Owner requirements CW01–CW05: Desert dust especially on the sides; Winter snow/frost; Grass off-road mud; Night off-road mud; Storm wet grime. CW06 covers gradual accumulation, lifecycle and all five vehicles. CW07 incorporates the owner's correction: dirt originates at the tires and fans diagonally upward toward the rear, especially in Desert. G01/R01 preserve simulation/competitive separation; V04/V05/V06 preserve the established presentation; Q01 records actual verification.

The next local run automatically applies race-owned weathering in races and untimed practice. Two rearward spray fans per side start near the actual front/rear tire locations, widening and rising toward the rear. This produces the strongest Desert dust behind the front wheels across the lower doors and up into the rear quarter panels, with a smaller plume behind the rear wheels. A faint sill film joins the deposits. The hood and upper front panels stay substantially cleaner. Winter adds powder and small icy highlights on upward panels. Storm darkens and glosses the paint, with streaked road grime and stronger off-road mud. Windows, lights, plates, driver and rubber remain their original materials. There is no new menu, label or setting.

## Behavior and files

- `game/vehicle/vehicle_weathering.gd` / `.uid`: reads canonical ticks, speed, grounded state and four wheel contacts using the existing read-only surface observer. Exponential accumulation stays within 0–1 and is independent of redraw rate. At 20 m/s, Desert reaches about 32% exposure after 15 seconds and 86% after 75; Winter about 28% and 81%. Mud accumulates only on loose/off-road wheel contact in Grass/Night, then persists on the road. Storm wetness approaches saturation over roughly a minute; road grime accumulates more slowly than off-road grime.
- `game/vehicle/vehicle_weathering.gdshader` / `.uid`: original opaque body-space tire-spray fans, fine irregular speckling, soft mud patches and vertical wet streaks. Wheelbase/span are converted from each car's physical config back to authored body coordinates; radius follows the existing visual wheel. The finish copies the original paint color, roughness, metallic, specular and clearcoat values, with separate cached PBR/toon variants. No transparent pass, extra geometry, screen/depth reads, image generation, external assets or downloads. Clean cars retain their original StandardMaterial3D surfaces; retry restores those same resources exactly.
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
