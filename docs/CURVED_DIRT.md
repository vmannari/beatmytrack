# Dirt curving upward through the rear quarter

Owner correction, 2026-10-11. CW25 requires a curved flow that becomes more vertical at the back; this supersedes CW23–CW24's uniform shallow slope while preserving their mostly horizontal door/front direction. Retain existing dirt/rim/slow-layer/scrubbing/persistence and G01/R01/V06/Q01 boundaries.

`game/vehicle/vehicle_weathering.gdshader` adds a smooth quadratic rise beginning around the rear half of the door, scaled by each car's authored half-wheelbase. The previous 0.14 shallow slope remains ahead of that point. The curve's tangent increases from roughly eight degrees along the front/door to about 45 degrees near the Compact's rear axle and 59 degrees near its tail. Flecks, mottling and wet/melted smudges share the same curve, on both physical sides. Flat end panels retain their lateral projection. Main splash/wake masks, colour, rim coverage, twenty-times-slower accumulation, wash difficulty and all saved condition remain unchanged.

No new texture/asset/sampler, mesh, UI action/label, camera, physical simulation, score or backend change. The original procedural noise is simply sampled through the curved authored coordinates.

## Actual verification

`game/tests/test_rearward_dirt.gd` now checks the actual shader's front and rear regions separately: the front keeps the earlier mostly-horizontal assertion, and the rear must show the increasingly upright direction requested by this correction. Logical viewport projections are converted into captured-image pixels before sampling. The former whole-field shallow-slope assertion is superseded by the explicit owner correction, not removed to hide a physics or behavior failure.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd
python build/checkpoint_curved_dirt.py
```

Compatibility and desktop Mobile/Vulkan each pass **12 checks / 0 failures**. Front horizontal/vertical gradient totals are 201.69/1438.60 and 142.79/999.19; rear totals are 884.47/711.99 and 613.37/495.45. The front remains horizontally elongated while the tail region turns more vertical. Existing rim/slow-coat contract checks pass 195/0, including save/restart, old masks and exact exposure rate. Initial region sampling failed because Godot's 2880x720 logical viewport differed from its 512x128 capture; scaling the projected regions resolved the fixture error, keeping both direction assertions intact.

Actual inspected views: [rear to the right](evidence/curved-dirt-2026-10-11/desert-rear-right.png), [rear to the left](evidence/curved-dirt-2026-10-11/desert-rear-left.png), [rear corner](evidence/curved-dirt-2026-10-11/desert-rear-corner.png), [flow inspection](evidence/curved-dirt-2026-10-11/shader-flow.png), Grass/Storm variants and desktop Mobile/Vulkan equivalents. Controlled shared-car conditions use a strong 0.85 smudge to expose the direction clearly; these are not completed races or physical-device footage.

Only the shader, its existing diagnostic, weathering documentation/status/plan and this document change. A task-only Git checkpoint under `build/curved_dirt/checkpoint-repo` preserves the main index/branch and unrelated work; patch/hashes/actual logs are beside the evidence. No phone test/attachment check, Android export/install, full Validate, physics regression/merge, backend action or deployment. Owner acceptance of curve strength and phone appearance remain.
