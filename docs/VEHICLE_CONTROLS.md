# Vehicle-specific driving controls — 2026-09-18

Requirements: G01 (active controls), V02/V03/V04/V05 (coherent art, readable HUD and visual acceptance), R01 (local integration).

The selected vehicle now supplies the touch-control skin in races and creator practice. Compact uses cool steel and rubber; pickup uses square rugged plates and fasteners; classic uses warm metal, wheel-ring motifs and drilled pedals; Formula uses squared grips and drilled racing plates; kart uses rounded grips and narrow pedal silhouettes. Ink outlines, restrained highlights, Barlow labels and gold pressed edges match the illustrated HUD. Touch zones, handedness, sizing and canonical input/handling remain unchanged. Drawn details scale with their controls. Keyboard actions also show press feedback.

Changed files for this slice:
- `game/ui/touch_controls.gd`: vehicle styles and pressed artwork.
- `game/ui/playground_hud.gd`: bind skin to actual handling configuration.
- `game/tests/capture_controls.gd`: real-game captures and vehicle/target checks.
- `scripts/dev.ps1`: pinned-engine CaptureControls entry point.
- This document, DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md: outcomes and acceptance.

Actual commands (PowerShell, via pinned Godot 4.7.2 entry point):
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/touch_controls.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureControls
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDriving
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBridgeHUD
```
Parse passed. CaptureControls passed 5 actual HUD vehicle bindings and 120 action-target checks across scales 0.8/1.0/1.3 and both handedness modes, saving ten 1280x720 normal/pressed gameplay PNGs. The first capture attempt failed because Windows could not resolve `res://../`; the corrected runner globalizes the output path and asserts each PNG save succeeds. TestDriving: 70 checks, zero failures (two ObjectDB instances reported leaked at exit). TestBridgeHUD: 91 checks, zero failures.

Desktop screenshots: [compact](../build/controls/compact.png), [pickup](../build/controls/pickup.png), [classic](../build/controls/classic.png), [Formula pressed](../build/controls/formula-pressed.png), [kart](../build/controls/kart.png). These five were visually inspected. Additional normal/pressed counterparts are in `build/controls/`. Captures use the handling yard, not a completed timed race. The narrow kart/classic artwork retains the larger rectangular hit zone for reliable input.

No device test or Android export was performed. Attachment status was not checked. Remaining acceptance: owner's visual review, physical-phone brightness/readability and simultaneous steering/pedal feel, including larger controls and left-handed mode. No physics contract/schema/version changes. Existing unrelated work in the working tree was preserved.

## Mechanical pedal refinement — 2026-09-18

Owner rejected the clean, simplistic pedal tiles. Requirements G01/R01/V02-V05. Replaced only pedal drawing in `game/ui/touch_controls.gd` with tapered stamped plates, exposed steel arms and pivots, mounting screws, distinct sidewall thickness, hard cel-shaded bevels, recessed rubber with raised/worn contact ribs, or countersunk racing holes. Sparse authored edge scuffs suggest use without random texture or glossy gradients. Brake is broad and throttle tall/narrow; kart has smaller racing plates. Labels sit below the shoe-contact surface. Pressing lowers the face and reduces its apparent depth, retaining the gold edge. Steering artwork and hit zones are unchanged.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureControls` passed all 5 vehicle bindings and 120 scaled/mirrored target checks, producing ten updated normal/pressed PNGs at the links above. All five styles were visually inspected (Formula in pressed state). `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBridgeHUD` passed 91 checks, zero failures. `git diff --check -- game/ui/touch_controls.gd` passed. No new physics tests were needed for drawing-only changes. Development status and phase plan updated.

No phone/device test or Android export performed; device attachment was not checked. Physical-phone readability and owner visual approval remain pending. Screenshots are desktop handling-yard captures; target checks validate input geometry, not subjective realism.

The HUD regression process also reported two ObjectDB instances leaked at exit; its 91 assertions passed. This warning remains unresolved.
