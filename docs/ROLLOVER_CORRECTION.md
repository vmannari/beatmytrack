# Faster rollover direction correction - 2026-09-15

Requirements: G01/R01/R03/R07/V04/V05. Owner reports reversed rollover and slow motion.

## Change

- Corrected the local roll sign: the roof now tips toward lateral travel, tested for left/right slides at all four cardinal headings.
- Halved tumble duration from 144 to 72 simulation ticks (1.2 to 0.6 seconds). Simulation and presentation share one duration constant.
- Compressed the existing slowdown into the shorter tumble (28 instead of 14 m/s²), retaining 16.8 m/s nominal total loss without contacts. Two-second post-recovery cooldown remains.
- Physics version arcade-planar-0.23 separates comparable PBs/replays. Snapshot structure stays schema 8.

Changed: `game/vehicle/vehicle_simulation.gd`, `game/vehicle/car_visual.gd`, `game/tests/test_soil.gd`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and `docs/SOIL_RECOVERY.md`. Existing unrelated working-tree changes retained.

## Actual verification

Pinned engine via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestSoil`: 66 checks pass. Tests direction through the actual rendered transform, exact 72-tick recovery, two-second cooldown, mirrored replay, trigger exclusions and dirty-trail behavior.
- `CaptureSoil`: 66 checks pass; staged [right roll](evidence/soil/roll-right.png) and [left roll](evidence/soil/roll-left.png) screenshots inspected.
- Scoped `git diff --check`: no whitespace errors.

The rollover retains its planar collision footprint and visual lift. Screenshots show staged poses; owner must judge speed in motion. No phone test, Android export or merge performed; phone attachment not checked. Full domain/UI validation from the initial implementation is historical, not a result for this revision.

Completed TestHandling: 77 checks, zero failures, including exact full-race replays. Completed TestTracks: 163 checks, zero failures, including lap/replay/collision/ramp and tire-cleaning checks. Together with TestSoil: 306 unique focused checks pass. Logs: [handling](evidence/soil/roll-handling.log), [tracks](evidence/soil/roll-tracks.log).

Presentation follow-up: [grounded rollover](GROUNDED_ROLLOVER.md) replaces the large visual lift with supported tire/side/roof contact and landing suspension; canonical timing stays 0.6 seconds.
