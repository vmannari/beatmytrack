# Lengthwise dirt and a shallow rearward rise

Owner correction, 2026-10-11. CW23 replaces the apparent up/down dirt streaks with front-to-back marks; CW24 gives those marks a slight upward slope toward the rear on both physical sides. Preserve CW01–CW22 dirt/rim/slow-layer/scrubbing/persistence contracts and G01/R01/V06/Q01 presentation/score boundaries.

The wet/melted-smudge field previously used short lengthwise and long vertical noise, so it could dominate the finer spray with vertical curtains. `game/vehicle/vehicle_weathering.gdshader` now shares one authored-car flow coordinate for mottling, flecks and smudges: +Z runs toward the rear, and the side's cross-stream height subtracts 0.14 metres per metre of rearward travel behind the front axle. The resulting direction is mostly horizontal with an approximately eight-degree rearward rise. End panels use the lateral coordinate to avoid rear/front striping. Opposite camera views mirror the image while preserving the same physical direction toward the rear.

Streaks are much longer along this flow than across it. Fine/coarse splash droplets also have longer horizontal dimensions and the same shallow rise. The original tire-fan coverage, dense sill/lower-door film, rear wake, dark Grass palette, rim mask, twenty-times-slower surrounding coat and all wash masks are unchanged. No new texture, asset, sampler, UI label, geometry, camera or physical driving rule.

## Actual verification

`game/tests/test_rearward_dirt.gd` (+UID) compiles the actual shipping shader's streak field into an isolated unshaded inspection pass, then compares horizontal/vertical pixel gradients. It also captures Desert, Grass and Storm from both physical sides and a rear corner, including a strong melted-smudge value (0.85) to reproduce the reported failure. Test records/backend access are isolated/disabled; no player condition is written.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
python build/checkpoint_rearward_dirt.py
```

Compatibility and desktop Mobile/Vulkan each pass **11 checks / 0 failures**. The actual field's vertical/horizontal gradient totals are 4495.24/760.29 and 3154.35/536.30 respectively (about 5.9:1), confirming long horizontal marks with the shallow shear. Existing rim/slow-coat regression passes **195 checks / 0 failures**, preserving exact exposure/washing/reboot/legacy contracts. Import passes. No failing assertion was removed or weakened.

Inspected actual renders: [Desert, rear to the right](evidence/rearward-dirt-2026-10-11/desert-rear-right.png), [Desert, rear to the left](evidence/rearward-dirt-2026-10-11/desert-rear-left.png), [Grass mud](evidence/rearward-dirt-2026-10-11/pine-rear-right.png), [rear corner](evidence/rearward-dirt-2026-10-11/desert-rear-corner.png), [flow inspection](evidence/rearward-dirt-2026-10-11/shader-flow.png) and desktop Mobile/Vulkan equivalents. These are actual shared-car/material renders with a controlled cosmetic condition, not completed races or device footage.

Only the existing shader, new diagnostic/UID, weathering documentation and status/plan change. The task-only checkpoint under `build/rearward_dirt/checkpoint-repo` preserves the main branch/index and unrelated changes. Patch, hashes and actual logs are beside the evidence. No phone test/attachment check, Android export/install, full Validate, physics regression/merge, backend action, deployment or generated asset. Owner acceptance of the texture's direction/intensity and phone appearance remain.
