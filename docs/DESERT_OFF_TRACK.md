# Desert off-track tyre effects — 2026-09-24

## Road-edge follow-up

Owner screenshot exposed dark intermittent sections where tyres cross canonical kerb cells (5). Those cells still selected rubber marks despite the desert's sandy apron. `game/vehicle/skid_trails.gd` now maps desert kerbs to visual sand as well; the shared effect lookup also replaces kerb smoke with sand dust. Canonical handling is unchanged. `game/tests/test_desert.gd` checks desert edge trails/dust and preservation of meadow kerb classification.

Actual validation: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e` passed 79 checks; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSoil` passed 163. Refreshed saved-track desktop evidence, including off-track marks, inspected. No phone test/export; owner review of the original corner in motion remains.

Requirements: V02/V04/V05/Q01; owner request for desert-appropriate off-track tyre marks, better debris and dust clouds.

Root cause: `SkidTrails.surface_at` converted only desert road cells to visual sand. Off-track canonical soil class 1 still selected green grass marks, grass clippings and mud. The shared presentation lookup now maps desert road/soil/sand to sand, without modifying canonical cells or handling.

`game/vehicle/skid_trails.gd` selects sandy tread grooves off track. `game/vehicle/sand_dust.gd` advances to desert-dust-9: existing bounded lingering clouds and contact puffs now operate off track; rear spray uses small flattened tan grains in a low, wide ballistic fan, with modest emission even during straight off-track driving. No additional emitters or particle capacity. Other biome effects restore on profile change.

`game/tests/test_desert.gd` adds off-track contact emission, no-clippings, canonical-cell preservation and meadow-restoration checks, plus two desktop evidence captures. Status and phase-plan entries document this slice.

Actual commands (pinned Godot 4.7.2):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert` — 67 checks, 0 failures; desktop Compatibility renderer.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSoil` — 163 checks, 0 failures.

Inspected [off-track dust](evidence/desert/off-track-dust.png) and [sand tyre grooves with particles cleared](evidence/desert/off-track-marks.png). Capture drives a presentation fixture across actual off-track soil; it is not a physical driving test. Existing CaptureDesert also refreshes its usual road/dune/apron images.

No Android export, install, phone test or performance measurement performed. Device attachment was not established (adb is not on PATH). Remaining acceptance: owner motion/appearance review and physical-device frame pacing with sustained off-track dust. Dense dust intentionally obscures the view per the existing desert override. Unrelated pre-existing worktree edits are retained.
