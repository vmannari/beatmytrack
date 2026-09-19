# Tire rotation — 2026-09-18

Requirements: G01/V02/V04/V05; owner requests rotating tires while driving.

All five vehicle models now rotate tires, hubs and spokes about a separate local axle beneath the steering pivot. Signed interpolated travel determines rotation using the scaled tire radius. Reverse reverses spin, stationary redraws do not spin wheels, and reset/discontinuous simulation ticks reset the visual phase. This is rolling-distance animation, not a simulated drivetrain or burnout effect. Canonical handling, records and camera are unchanged.

Changed files: `game/vehicle/car_visual.gd`, `game/vehicle/vehicle_models.gd`, `game/tests/test_cars.gd`, `game/tests/capture_cars.gd`, this document and the two status documents.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:

- `-Action CaptureCars`: 120 checks, zero failures. Initial phase captures were overwritten by the live presentation loop; the fixture now pauses presentation and captures on the road. Final Formula close-up inspected.
- `-Action TestCars`: initial run 65 checks passed; final expanded run 95 checks, zero failures, including 30 wheel assertions and 15 five-lap runs with exact replay and zero contacts.
- `git diff --check -- game/vehicle/car_visual.gd game/tests/test_cars.gd`: passed (line-ending advisory only).

Evidence: [Formula phase A](evidence/cars/formula-wheel-phase-a.png), [phase B](evidence/cars/formula-wheel-phase-b.png). Matching pairs exist for compact, pickup, classic and kart in the same folder. These are diagnostic closeups, not a changed gameplay camera.

No phone/device test or APK export performed. Remaining acceptance: owner review of animation at gameplay scale and phone frame pacing. Existing unrelated working-tree changes retained; no mixed-scope commit made.
