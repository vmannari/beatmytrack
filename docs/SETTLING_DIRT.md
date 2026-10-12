# Dirt flattening and settling toward the rear

Owner correction, 2026-10-11. CW26 reverses CW25's increasing upward bend: tire spray rises initially, becomes more horizontal at the back, and begins falling near the tail. Preserve the previous dirt/rim/slow-layer/scrubbing/persistence contracts and G01/R01/V06/Q01 boundaries.

`game/vehicle/vehicle_weathering.gdshader` now uses a concave, half-wheelbase-scaled visual arc beginning at the front axle. Its tangent is roughly 22 degrees there, about 11 degrees through the middle of the Compact, zero near its rear axle and approximately seven degrees downward near its tail. The same settling coordinate drives fine/coarse flecks, film mottling and wet/melted smudges on both physical sides. End-panel projection is retained. This is a cosmetic sampling curve, not new particle or driving physics.

Main splash/wake masks, colours, dirty rims, twenty-times-slower surrounding accumulation, grime age/scrubbing, saved wash strokes and all competitive contracts are unchanged. No new asset, texture/sampler, mesh, UI action/label or camera change.

## Actual verification

The existing `game/tests/test_rearward_dirt.gd` retains the mostly-horizontal front/door check. The owner explicitly supersedes the previous upright-rear assertion: the rear must now be flatter than the front. A second actual-shader inspection pass reads the curve itself, confirming that it rises behind the tire and falls before the tail, rather than merely rotating the texture downward.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rearward_dirt.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd
python build/checkpoint_settling_dirt.py
```

Compatibility and desktop Mobile/Vulkan each pass **15 checks / 0 failures**. Front horizontal/vertical field gradients are 340.32/1428.79 and 238.05/984.33; rear values are 74.81/659.97 and 53.40/474.22, confirming the rear is substantially more horizontal. Both actual arc crest/tail checks pass. Existing rim/slow-coat checks pass **195/0**, retaining exact exposure rate, washing, reboot persistence and legacy data. No physics/storage assertion was weakened or removed.

Inspected controlled shared-car renders: [rear to the right](evidence/settling-dirt-2026-10-11/desert-rear-right.png), [rear to the left](evidence/settling-dirt-2026-10-11/desert-rear-left.png), [rear corner](evidence/settling-dirt-2026-10-11/desert-rear-corner.png), [flow](evidence/settling-dirt-2026-10-11/shader-flow.png), [arc inspection](evidence/settling-dirt-2026-10-11/shader-settling-arc.png), Grass/Storm variants and desktop Mobile/Vulkan equivalents. They are actual material/model diagnostics, not completed races or device recordings.

Only the existing shader, existing diagnostic, weathering documentation/status/plan and this document change. A task-only Git checkpoint under `build/settling_dirt/checkpoint-repo` preserves the main branch/index and unrelated work; patch/hashes/actual logs are beside the evidence. No phone test/attachment check, Android export/install, full Validate, physics regression/merge, backend action or deployment. Owner acceptance of this corrected direction and phone appearance remain.
