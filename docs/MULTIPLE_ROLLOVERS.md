# Momentum-driven multiple rollovers - 2026-09-16

Requirements: G01/R01/R03/R07/V04/V05. Owner requests multiple flips when warranted.

## Behavior

At each complete 0.6-second revolution, the canonical simulation checks the remaining sideways speed in the original tumble direction after resolving collisions. At 18 m/s or more, it continues directly into another revolution. Otherwise it finishes upright. Each revolution retains the existing 28 m/s² slowdown; held throttle or steering cannot add energy while rolling. No arbitrary preselected flip count is needed. Ordinary ground-trigger thresholds remain unchanged.

This allows a fast tumble to continue onto asphalt. An obstacle stop or sufficiently strong rebound prevents another flip. The two-second re-trigger cooldown starts after the final revolution; reset clears the chain. Presentation reuses the grounded 0.6-second cycle continuously, and landing suspension only activates when the complete tumble ends.

Synthetic unblocked broadside fixtures at 30, 46 and 60 m/s produce one, two and three revolutions respectively (0.6, 1.2 and 1.8 seconds). The 60 m/s fixture intentionally exercises high-speed state independently of a particular vehicle's powered speed cap. Each of the five selectable vehicles is additionally checked at its own speed cap.

Physics version advances from arcade-planar-0.24 to arcade-planar-0.25, separating comparable PB/replay rules. Existing roll timer/direction/cooldown fully describe continuation, so recorder schema 8 and snapshot layout do not change.

## Changed files

`game/vehicle/vehicle_simulation.gd`, `game/tests/test_soil.gd`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and `docs/GROUNDED_ROLLOVER.md`; evidence under `docs/evidence/soil/`. Existing unrelated multi-car/editor/UI workspace changes were preserved.

## Actual commands and results

Pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- Initial `TestSoil`: 106 checks pass.
- Final `CaptureSoil`: 111 checks pass, including all five vehicles, mirrored one/two/three-flip recovery, exact JSON-input replay, monotonic speed loss under held controls, reset, cooldown, asphalt continuation, real barrier cancellation, and prior dirt/visual safeguards.
- Captured actual simulation-driven two-flip motion, then assembled it using existing `.tools/review/Scripts/python.exe` and Pillow. [Animated sequence](evidence/soil/multi-roll.gif), [inspected contact sheet](evidence/soil/multi-sequence.png). Fixed 120 Hz simulation sampled every three ticks; GIF uses alternating 20/30 ms delays. The camera follows the car in this isolated fixture; it is not a player-race recording. The staged floor edge is visible near the end.
- Full `Validate` result recorded below when complete.

## Limits and remaining acceptance

The continuation rule models remaining lateral momentum; the chassis still uses the existing planar collision footprint and presentation-only ground-support shape rather than full 3D rigid-body tumbling. Vehicle-specific rollover susceptibility is unchanged. Owner feel/visual acceptance and physical-phone performance remain pending. No phone test, export or merge was performed; phone attachment was not checked.

Final `Validate` exited 0: import, 111 script parses, startup and all 28 reported suites (1801 checks) passed, including full-race replay for all five cars and car-balance checks. [Complete validation log](evidence/soil/multi-validation.log). Some UI fixtures reported ObjectDB cleanup warnings; no failing checks. Scoped `git diff --check` passed (line-ending warnings only).
