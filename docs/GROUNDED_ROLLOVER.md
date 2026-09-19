# Grounded rollover presentation - 2026-09-15

Requirements: G01/R01/V02/V04/V05. Owner asks for a more realistic-looking rollover.

## Implemented

Replaced the large sine-wave lift and constant spin with cross-section support: the tires, side/mirrors and roof determine minimum height as the car turns. Maximum extra hop is 6 cm. The mass center stays over the simulated path rather than orbiting the ground-level model origin. Angular motion eases through initial tipping and recovery and accelerates through the middle of the tumble. Rendering interpolates between simulation ticks; pausing freezes the pose.

Body suspension stays neutral during the roll, then receives a single compression and small lateral settling impulse at touchdown. This is a presentation change: the 0.6-second rollover, correct direction, speed penalty, automatic recovery, canonical physics 0.23 and recorder schema 8 remain.

Changed files: `game/vehicle/car_visual.gd`, `game/core/game.gd`, `game/tests/test_soil.gd`, this document, `docs/ROLLOVER_CORRECTION.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and captures under `docs/evidence/soil/`. Existing unrelated workspace edits retained.

## Actual verification

Pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestSoil`: 73 checks pass, including direction, exact recovery/replay, entire-roll support height, mass-center alignment, interpolation, no canonical state mutation, landing compression, paused landing and settling.
- `TestSuspension`: 13 checks pass.
- `TestDriving`: 70 checks pass, including exact replay and app driving integration. The fixture reports two ObjectDB cleanup instances at exit; no failures.
- `CaptureSoil`: 73 checks pass in the graphical renderer. Captured a fixed-tick roll/landing sequence and inspected the [contact sheet](evidence/soil/realistic-sequence.png) and side/roof poses. [Animated roll and landing](evidence/soil/realistic-roll.gif) uses 40 fps-equivalent frames, alternating 20/30 ms GIF delays. This is an isolated pose sequence with a fixed car path, not a live player race.
- Sequence assembly used existing Pillow in `.tools/review/Scripts/python.exe`. The first attempt with system Python failed because Pillow was unavailable there; no packages were installed.

156 unique focused checks pass. No physics/schema changes, full-suite rerun, merge, export or physical-phone test. Phone attachment was not checked. Remaining acceptance: owner judges motion while driving; ground support is an approximate visual hull, not 3D rigid-body collision, and uneven ground/bridge transitions retain the existing planar approximation.

2026-09-16: [multiple rollovers](MULTIPLE_ROLLOVERS.md) now repeat the grounded cycle while lateral momentum warrants another revolution; 0.6 seconds is per flip, not a cap on the whole tumble.
