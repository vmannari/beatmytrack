# Outside-corner penalties — 2026-09-16

**Superseded detector:** [Silmukka missed-cut correction, rules v6](SILMUKKA_SHORTCUTS.md). Earlier test results below are historical, not owner acceptance.

Requirements G01 / R03 / R07 / T02 / V05. Owner feedback supersedes v4 acceptance: slightly wide outer corners still received shortcut penalties.

## Cause and correction

The previous spatial check treated any missed centreline corridor as shortcut evidence. A wide outside path can miss that corridor too, especially when progress projection catches up or selects a neighbouring hairpin leg. A new regression reproduces this: the old implementation fails the outside-path assertion.

Automatic route geometry remains useful, but distance from the route is insufficient evidence of a shortcut. `NativeTrack.has_cut_gap` now requires an inside bypass, measures local bend direction over metres, and vetoes clearly outside evidence. `is_outer_curve` uses the car's connected route hint to identify a wide outside position. `TrackSession` clears pending shortcut distance debt there, preventing that excursion from leaving a delayed charge on rejoining. The hint supplies an exemption only; it cannot award lap progress or prove a cut.

The warning still fires in the tick that confirms a cut. No confirmation timer or general tolerance increase was added. Existing kerb allowance, counted penalized laps, five-second penalty and two-second warning remain. Scoring key advances to `standing-5-local-v5`; handling is unchanged and prior record files are preserved.

Changed implementation: `game/track/native_track.gd`, `game/race/track_session.gd`, `game/race/race_rules.gd`. Tests: `game/tests/test_route_validation.gd`, `game/tests/review_route_validation.gd`. Documentation: this file, `ROUTE_PROGRESS_VALIDATION.md`, `PHASE_0_PLAN.md`, `DEVELOPMENT_STATUS.md`, and the evidence directory.

## Actual verification

Commands used the pinned Godot 4.7.2 entry point: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>`.

| Action | Final result |
| --- | --- |
| TestRouteValidation | 55 checks, zero failures; outside/inside distinction in four rotations, outside debt reset, kerbs, hairpins, real cuts, lap counting and warning timing |
| TestTracks | 167 checks, zero failures, including native driven laps and replay comparisons |
| TestRecords | 53 checks, zero failures |
| TestApp | 86 checks, zero failures |
| TestPieces | 172 checks, zero failures |
| TestFreeEditor | 55 checks, zero failures |
| ReviewRouteValidation | Read-only diagnostic: 49 offset trajectories over seven saved tracks; not an assertion suite |

Before correction, TestRouteValidation reported 35 checks with one failure on the new outside-path proof assertion. Final inside-hairpin cuts warn 42–50 ms after leaving the tested 5 m kerb corridor at 24 m/s, across 60/120/240 Hz. This is a fixture measurement, not a universal maximum detection delay.

The saved-track review propagates `nearest_route` hints as the physical car does. All 21 centreline and ±4 m trajectories finish without penalties. Reproduced outside penalties on Over and under (+6 m) and Speedy (-8 m) disappear. The expanded ±6/±8 m stress paths are not all valid racing lines: one Blind spot -8 m trajectory still incurs a penalty, and several extreme paths do not finish. Over and under +6 m has a remaining route-projection/finish issue despite no penalty. These diagnostics are not complete physical driving or collision simulations and are not blanket acceptance.

Logs: [before failing regression](evidence/outer-curve-shortcuts/outer-curve-before.log), [final regressions](evidence/outer-curve-shortcuts/outer-route-final.log), [saved-track baseline](evidence/outer-curve-shortcuts/outer-owner-before.log), [final physical-hint review](evidence/outer-curve-shortcuts/outer-owner-physical-hint.log). Other command logs are alongside these.

## Remaining acceptance

Owner driving of the reported corner remains necessary; the exact track/corner was not supplied during this follow-up. Complex overlapping routes and mixed inside/outside excursions remain ambiguous, and the conservative outside veto can forgive some mixed cuts. This is local scoring, not verified competitive anti-cheat. The wider stress-path projection issue above remains unresolved.

No HUD, camera or artwork changes in this follow-up; earlier rendered warning captures are retained in `evidence/shortcut-v4/`. No phone/device test was performed. Full Validate was not rerun; the previously documented engine-process crash is not claimed resolved. The working tree includes unrelated owner changes; no combined Git commit was made.
