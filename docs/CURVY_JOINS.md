# Curvy road-piece joins (2026-09-29)

Requirements: V02/V04/V05/Q01; owner screenshot of two angled joins on Curvy.

Kit 87 gives matching ground-road endpoints a small quadratic fillet, split between the two pieces at a shared midpoint. Trim distance is at most 1 m and limited to 45% of the adjacent edge length. Both sides share the same corner calculation, including numerical differences introduced by folded-tip trimming. Asphalt and inset markings use the same construction. Shoulder and line vertices use matching join normals, closing the former wedge gaps. Marking quads use endpoint normals rather than independent per-segment offsets.

Changed files:
- `game/track/visual_road_join.gd`: presentation-only join construction.
- `game/track/native_track_visual.gd`: kit 87, shared rounded outlines and shoulder/line normals.
- `game/tests/test_shoulders.gd`: sharp left/right and straight-join regression checks for road and inset marking margins.
- Associated Godot UID files, status/plan and this evidence.

No changes to authored track files, canonical road outlines, collisions, kerb contacts, replay rules or camera. This small cosmetic treatment is not a smoothing operation on the driving route. Bridges and unmatched width-discontinuous corners retain their original outline. The existing bridge-end slit visible at the left of the comparison is also visible before this change and is outside this ground-road join fix.

Actual validation through the pinned engine and `scripts/dev.ps1`:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestShoulders`: shoulder union/nearest-road/no-overlap regression passes; 55 join checks pass. The first run exposed two sub-millimetre sharp-angle discrepancies; shared-corner calculations fixed those before the final passing run.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSurfaceProfile`: 928 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: before and final captures pass. Canonical cells unchanged; zero bad road normals; twelve route views saved. Final views 0, 1, 4, 5, 6 and 11 inspected across the iteration; view 5 directly shows the owner-marked joins. The final shoulder batch is 32,718 vertices versus 29,724 before; asphalt is 5,202 versus 4,110.
- Android SDK `adb.exe devices`: no attached phone. No Android export, installation or physical-device test performed.

[Before](evidence/curvy-joins/before.png) / [After](evidence/curvy-joins/after.png).

Remaining acceptance: owner approval of the slight rounding, moving-camera/device inspection and mobile performance measurements. Captures retain the test harness pause/countdown overlay. Other working-tree changes were preserved and excluded from this task checkpoint.
