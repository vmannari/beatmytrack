# Black vehicle undersides — 2026-09-24

Owner request: prevent seeing through the car during a rollover; make the bottom black. Requirements V02/V04/V05/Q01.

`game/vehicle/car_visual.gd` closes each authored shell with six downward-facing opaque black triangles following its existing lower outline. The material is shared within each car for static batching. This covers compact, pickup, classic, Formula and kart nose shells, including secondary shell details. `game/vehicle/vehicle_models.gd` also makes the kart's existing closed floor black. Geometry is presentation-only; handling, collision and camera are unchanged.

`game/tests/test_vehicle_batch.gd` captures inverted unbatched and production-batched models. Evidence: `docs/evidence/undersides/{compact,pickup,classic,formula,kart}.png`. All five desktop screenshots were inspected: floors are solid black and match between batching modes.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestVehicleBatch`, pinned Godot 4.7.2. Final result: **35 checks, 0 failures**, including triangle preservation, bounds, batching, independent wheels, brake response and capture writes. Initial run failed five capture writes because Windows needed a globalized directory path; corrected and rerun successfully.

Remaining acceptance: owner review during live rollover and physical Android check. No phone test or APK export was performed. Diagnostic captures use an inverted static pose, not a recorded crash. Open-wheel suspension gaps remain intentional.
