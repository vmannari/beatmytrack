# Loose-ground punishment and recovery — 2026-09-15

Requirements: G01, R01, R03, R07, V02, V04, V05. Owner requests stronger off-road slowdown, lingering grip loss with visible cleaning, and recoverable high-speed sideways rollovers.

## Behavior

- Full dirt coating now costs up to 45% tire traction (previously 25%), affecting lateral recovery, braking and acceleration. Full pickup takes 10 m of dirt or 20 m of grass; full cleaning takes 140 m of clean travel instead of 80 m. Waiting does not clean tires. Existing oil/water remain separate coatings. Dirt-related longitudinal loss fades out below 3 m/s and reaches full strength at 12 m/s, preserving slow-speed escape and pushing.
- Additional loose-ground resistance is pickup factor × (3 + 0.22 × speed) m/s², applied to both forward and sideways motion, smoothly introduced from 6 to 18 m/s. Grass has half the additional dirt resistance, on top of its existing surface resistance.
- Dirty tires deposit brown paired trails even during straight travel. Each new segment becomes more transparent as coating falls. Existing marks retain their deposited strength until overwritten by the bounded 240-mesh pool. Airborne/tumbling vehicles do not deposit marks.
- Grounded loose-surface travel at >=24 m/s (86.4 km/h), with >=65 degrees of sideways slip, triggers one 144-tick (1.2 s) tumble. Speed dissipates at 14 m/s²; pedals do not propel the car during recovery. Existing planar collision/prop resolution remains active. The car always finishes upright, with a further 2 s of trigger cooldown. Both slide directions are supported. Reset clears rollover and coatings.
- Physics version is arcade-planar-0.22. Recorder schema 8 appends [roll_ticks, roll_direction, roll_cooldown] at snapshot index 19, retaining earlier indices. PB identity includes the physics version and tuning, so the changed handling uses separate comparisons.

## Changed files

`game/vehicle/handling_config.gd`, `vehicle_simulation.gd`, `vehicle_state.gd`, `skid_trails.gd`, `car_visual.gd`; `game/core/game.gd`; `game/persistence/handling_recorder.gd`; `game/tests/test_soil.gd`, `test_tracks.gd`, `test_kerbs.gd`; `scripts/dev.ps1`; this document, DEVELOPMENT_STATUS and PHASE_0_PLAN. Earlier unrelated workspace edits were preserved.

## Actual verification

Commands use Windows PowerShell `-NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot 4.7.2.stable.official.ed1daf0bf.

- `TestSoil`: 34 checks pass, including mirrored trigger/recovery, exact rollover replay, no slow/straight/asphalt rollover, dirt coasting slowdown, straight dirty marks, fading deposition and tumble suppression.
- `CaptureSoil`: 34 checks pass in the graphical renderer; staged in-engine [dirty trail](evidence/soil/dirty-trails.png) and [inverted rollover](evidence/soil/rollover.png) captures inspected. They show a full-coating-to-cleaner trail and the whole vehicle inverted, including wheels.
- First `Validate` attempt exited with native Windows access violation -1073741819 during recorder parse, while graphical capture was also running. No GDScript error was reported. Retried validation alone: driving (70), handling (77), tracks (163) and intervening suites passed, but refinement detected insufficient tyre-stack pushing. Old pickup/penalty values restored temporarily reproduced passing movement, isolating the regression; final tuning now fades added drag and longitudinal coating loss at low speeds. Final `TestRefinement` passes 29 checks (two stacks moved), and `TestSoil` still passes 34. Full final validation outcome recorded below.

## Limits and acceptance

This is a deterministic arcade tumble with a visual roll and lift, using the existing planar collision footprint; it is not a six-degree-of-freedom rigid-body simulation. Existing surface sampling uses the car center. Captures are staged component evidence, not a recorded player lap. Owner driving-feel acceptance, rollover threshold/animation review, normal-camera trail readability across track themes and phone performance remain pending. No physical-phone test was performed. No Android export or merge was performed.

Final `Validate` exited 0: import, 101 script parses, startup and all 24 suites (1500 checks) passed. Exact same-engine driving/full-race replays passed. During this run the low-speed coating expression was narrowed to dirt only; earlier dry-track replay results are mathematically unchanged, and subsequent hazard/refinement/soil suites exercised the final expression. Some UI fixtures reported ObjectDB cleanup warnings; no test failures. Saved log: [validation](evidence/soil/validation.log). `git diff --check` reported no whitespace errors (line-ending warnings only).

2026-09-15 follow-up supersedes the initial roll direction/duration: [rollover correction](ROLLOVER_CORRECTION.md), physics 0.23, 72 ticks / 0.6 seconds, same nominal total speed penalty.
