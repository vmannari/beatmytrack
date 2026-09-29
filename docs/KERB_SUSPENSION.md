# Individual-wheel kerb suspension — 2026-09-29

Requirements: owner request for clearer suspension over kerbs with one or several tyres; V01/V04/Q01. Presentation-only: handling, canonical state, physics version and replay contracts remain unchanged.

`game/vehicle/car_visual.gd` retains each wheel's rest position and offsets its steering pivot independently using the existing four kerb contact heights. It compensates for the chassis kerb plane so an uncontacted wheel stays on the road. The existing damped canonical pitch/roll is accentuated by 70% on the sprung body (21% for the stiffer kart). Wheel spin and steering remain independent. Airborne/rolling poses restore wheel rest travel. `game/core/game.gd` supplies the existing track contact samples.

`game/tests/test_suspension.gd` adds single-wheel, same-side pair, three-wheel and flat-road checks for tyre height, body direction and unchanged canonical snapshots. `game/tests/test_kerbs.gd` hides the start-light overlay in its existing actual-track evidence capture.

Actual commands, using pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestSuspension`: 59 checks, zero failures.
- `TestDriving`: 74 checks, zero failures; reports six ObjectDB instances leaked at exit.
- `CaptureKerbs`: 40 checks, zero failures; actual creator-road crossing. Initial evidence-overlay cleanup used the wrong CanvasLayer type; corrected to Control and reran successfully.
- `TestCars`: 95 checks, three failures in the existing `body.get_child_count() > 10` model-structure assertion for pickup/classic/formula. The same failures were present in the September 25 log inspected before this run completed. All five-car lap/replay checks passed. No assertion changed or weakened.
- Android SDK `adb.exe devices`: empty attached-device list.
- `git diff --check`: passed (line-ending notices only).

Desktop evidence: `build/kerbs/before.png`, `crossing.png`, `after.png`; crossing inspected. This is a close inspection camera, not a gameplay-camera change. Existing capture shows a transverse crossing; asymmetric contacts are covered numerically, with subjective driving review still outstanding.

Limitations: tyre contact uses current simulation samples while chassis position is render-interpolated; no new swept visual tyre solver. No phone attached; no Android export or physical-device test performed. Owner acceptance of strength/readability at gameplay zoom and phone frame cost remains outstanding.
