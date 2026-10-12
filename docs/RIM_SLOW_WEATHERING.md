# Dirty rims and twenty-times-slower background coating

Owner request, 2026-10-11. CW17 adds dirt/snow to the rims of all five cars. CW18 adds light accumulation outside the main splash pattern at exactly **one twentieth** of its exposure rate. CW19 preserves the accepted local per-car persistence, snow melting and manual Garage washing (CW13–CW16), plus G01/R01/V06/Q01 separation and evidence.

Rims now share the biome's existing dirt/snow colour and ordinary accumulation. Their authored radial mask covers the hub/spokes and fades before the tire tread. The grain moves with wheel spin/steering rather than sliding in world space. The existing dense sill/door and rear spray pattern remains the fast layer. Other painted body areas receive a lighter secondary film, including the bonnet and roof, without coating glass, lamp lenses, plate faces or tire tread. Current Winter upward-panel snow remains part of the original pattern.

## Exact rate and persistence

The slow layer has independent bounded dirt and snow accumulators. It uses the same movement/contact exposure as the existing pattern, multiplied by `1.0 / 20.0`, with the same exponential accumulation curve. It continues growing after the primary layer has saturated; it is not merely twenty-times-fainter colour or a value derived from the already saturated primary amount. At a controlled 20 m/s in Desert, 75 seconds produces approximately 0.858 primary dirt and 0.093 background dirt. After 1,500 seconds, the background amount reaches the same approximately 0.858. These are exposure amounts, not a claim that PBR pixel brightness changes in an exact 20:1 ratio.

The new slow wash volume re-coats at the same one-twentieth rate, independently of the fast wash volume. A pending slow re-coating remainder is saved so repeated short races/restarts do not discard progress; a fresh wash clears pre-wash re-coating debt. Main and slow coatings both respond to the same manual brush. Existing washed body locations retain their previous volume bounds and mapping. Wheel hits are mapped into authored wheel-rest coordinates, keeping a cleaned patch attached to the rotating rim.

Cosmetic version 1 entries gain `slow_dirt`, `slow_snow`, `slow_wash` and `slow_recoat`. Original eight-field entries remain valid and retain exact existing dirt/palette/wash bytes; they start with zero new background dirt/snow. The intermediate eleven-field form is also valid with zero pending remainder. Final entries contain twelve fields. No local-records schema/version bump, file deletion, backend field or competitive contract change. Two 4,096-byte R8 wash volumes per car use roughly 56 KB total Base64/scalar data for all five cars. This remains local-only, using the existing atomic saves.

## Files and cost

- `game/vehicle/vehicle_weathering.gd`: four wheel bindings, authored wash coordinates, independent slow accumulators/re-coating volumes, local snapshot/restore and wash debt reset.
- `game/vehicle/vehicle_weathering.gdshader`: radial rim coverage, lighter complementary background dirt/snow and the second interpolated wash sampler. Same original noise, opaque finish and geometry; no extra mesh/pass or generated assets. The second volume adds two texture reads to affected fragments.
- `game/vehicle/vehicle_condition.gd`: bounded optional slow fields/volume/remainder, preserving older local entries and rejecting malformed values.
- `game/ui/car_showroom.gd`: existing wash picker includes wheels and maps hits through the cosmetic controller; slow snow also participates in Garage melting. No new action, label or player-facing implementation text.
- `game/tests/test_rim_slow_weathering.gd` / `.uid`: all-car exposure ratios, spinning rim coordinates, both wash layers, old/new atomic save round trips and actual native captures/rim-wash pixels.
- `docs/VEHICLE_WEATHERING.md`, `docs/CAR_WASH.md`, status/plan and this document: current contracts, commands and remaining acceptance.

The existing small body-coordinate wash volume is retained for save compatibility, so wheel points at its lower edge use its clamped resolution. Brush radius remains 0.48 authored metres. No mesh, driving, wheel dimensions, physics, camera, five-lap contract, records/PB, upload or eligibility change. Shader/picking cost still needs phone measurement.

## Actual commands and results

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` through the launcher, with backend access disabled and isolated test records:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python build/checkpoint_rim_slow_weathering.py
```

Import passes. Existing weathering passes 860 checks, wash/persistence 1,383 headless checks, records 54, and app 99, all zero failures. Final focused headless checks pass 195; final Compatibility and Mobile/Vulkan capture runs pass 249 each. They verify exactly 0.05 exposure ratio for all five cars in Desert/Grass/Winter, blocked/canonical isolation, rotating rim wash coordinates, both volumes, atomic restart/legacy compatibility, pending short-race progress, actual visible rim washing and pixel-identical material reset. No assertion was weakened. Initial visual review found half-coated Formula rims from the body-height film; their film weight is now independent of body height so the whole rim gathers dirt. Body wash bounds are deliberately preserved after review of legacy-mask compatibility.

Evidence: [dirty Desert rims, 75 seconds](evidence/rim-slow-weathering-2026-10-11/compact-desert-75s.png), [background coat after 1,500 seconds](evidence/rim-slow-weathering-2026-10-11/compact-desert-1500s.png), [Grass mud](evidence/rim-slow-weathering-2026-10-11/compact-pine-75s.png), [front rim washed](evidence/rim-slow-weathering-2026-10-11/compact-pine-rim-washed.png), and equivalent all-car/biome views plus Mobile/Vulkan captures. These are actual shared model/material renders with controlled exposure, not completed races, timed footage or phone recordings.

## Remaining acceptance and checkpoint

The task-only checkpoint under `build/rim_slow_weathering/checkpoint-repo` preserves the main Git branch/index and unrelated working changes. Patch, hashes and actual logs are beside the evidence. **No phone test or attachment check, Android export/install, full Validate, physics regression/merge, backend operation or deployment.** Owner rim/background intensity, phone shader/picking performance and washing precision remain acceptance checks. Manual review: drive off-road, inspect the dirty rims in Garage, wash a rim and a body patch, change car/biome/restart, and check that the main pattern develops quickly while surrounding paint develops over roughly twenty-times-more exposure.
