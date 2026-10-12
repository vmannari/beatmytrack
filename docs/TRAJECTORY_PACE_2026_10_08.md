# Faster artificial-driver trajectories - 2026-10-08

The owner requested about another 10% of artificial-driver pace, focusing on trajectory calculation. `profiled-trajectory-5`, `racing-trajectory-3` and `frenet-ltv-mpc-2` achieve **10.1% shorter race times on average** against the previous v4 controller on the same 27 circuits, profiles and canonical contracts. All 27 circuits improve and all final five-lap recordings independently verify.

Requirements: **TD02 / TD03 / TD05 / TD08 / TD09 / T01-T04 / Q01**. Physics **0.53**, compiler **22**, rules **v20**, vehicle configuration, profile traits, race length and verified timing are unchanged. No power/speed/configuration is added to the car, and no reported time is rescaled.

## What improved

The minimum-curvature line can be needlessly wide: reducing curvature alone does not minimize the distance/time through a bend. The planner now also searches a **minimum-time proxy**, using local distance divided by the feasible corner speed, plus a penalty for physically impossible curvature. Its final objective uses the same two-metre spatial filter as the reference tangent/curvature; isolated raster/chord kinks no longer dominate that optimization. Existing curvature, smoothing and center candidates remain available.

The speed envelope now inverts the actual speed-dependent steering reduction analytically. The old loop reduced speed by 10% at a time and could undershoot the feasible result. Lateral reference utilization rises from 0.68 to 0.88; acceleration/braking use the canonical shared traction budget rather than independent constant grip budgets. Drive utilization is 0.90 and braking utilization 0.82. These are **planner margins**, not vehicle changes. The final optimized line's surfaces are re-evaluated before its speed profile is built. The cyclic forward/backward passes still propagate braking through the lap seam.

Higher speed exposed a standing-start qualification flaw on Speedy: a candidate looked good on lap one and repeatedly touched barriers on later laps. Every candidate now drives **two diagnostic laps**, recording the standing and flying times. Selection considers `standing + 4*flying`, and rejects candidates with more than four recorded contacts during those two diagnostic laps. Isolated contacts incur a 36-tick **selection cost**; this never alters actual race/leaderboard timing. This is a bounded heuristic, not proof of an optimal or universally safe line. Ordinary generated races still complete five ordered laps.

The follower also clipped steering using only the linearized yaw gain. Its affine bias was omitted from the input-bound transformation. Bounds now use `(allowed_yaw - bias)/gain` on each side. Linearization is centered on a feasible steer/yaw, including inversion of progressive grip saturation; excessively fast entries cannot create an empty admissible input interval. The prediction horizon, update rate, skill parameters and canonical car model remain intact.

Derived cache v3 invalidates older trajectory caches. Normalization through the persisted numeric representation preserves exact fresh/cached quantized controls. The cache schema records standing/flying diagnostics explicitly. Previously committed v4 uploads, personal records and player files are preserved by the existing recovery flow.

## Actual comparison

Benchmark: compact, seed 27, skill 0.5, consistency 1.0, aggression 0.5, learning 0.5, pace scale 1.0; the same 27 original local track documents. Before/after manifests are exactly equal on every circuit. Evidence began on October 7 and was completed on October 8.

| Measurement | Actual result |
| --- | --- |
| Completed and independently verified | 27/27 five-lap recordings |
| Average of per-track time reductions | **10.1001%** |
| Median reduction | **8.4342%** |
| Combined race-time reduction | **11.1517%** |
| Circuits faster | **27/27** |
| Individual reductions | **5.4423%-28.8027%** |
| Recorded contacts | **5 before, 8 after** |

The strongest improvements are Saw (28.8%), Dust cloud (22.7%), Narrow night (18.4%) and Knit (16.1%). The final eight contact counter entries are on Over and under, Ellipse and Ajorata. This is a small contact increase, not an improvement in contact count; repeated-contact candidates were rejected. Contacts are not counts of distinct crashes or physics ticks.

Actual artifacts:

- [Inspected comparison chart](evidence/trajectory-pace-2026-10-08/comparison.png) and [SVG](evidence/trajectory-pace-2026-10-08/comparison.svg).
- [Verified summary](evidence/trajectory-pace-2026-10-08/verified-summary.json) and [per-track CSV](evidence/trajectory-pace-2026-10-08/comparison.csv).
- [Complete final inputs/documents](evidence/trajectory-pace-2026-10-08/verified-recordings.json.gz), [reference/actual telemetry](evidence/trajectory-pace-2026-10-08/final-telemetry.json), and the preserved v4 baseline/inputs in the same evidence directory.
- [Task-start source snapshots](evidence/trajectory-pace-2026-10-08/before-hashes.json), [scoped source hashes](evidence/trajectory-pace-2026-10-08/source-hashes.json), [Git patch](evidence/trajectory-pace-2026-10-08/task.patch) and [checkpoint description](evidence/trajectory-pace-2026-10-08/checkpoint.json). Existing unrelated workspace work is preserved. The scoped patch passes `git apply --reverse --check --ignore-space-change`; the flag handles Windows CRLF working files.

## Actual validation and commands

| Command/check | Actual outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_predictive_driver.gd` | **1,424 checks, zero failures**. Exact steering inverse, shared traction, affine yaw endpoints, numerical MPC derivatives, cache identity/round trip, cyclic braking, and all five vehicles recovering a 1.1 m / 0.12 rad disturbance without contacts. |
| `BMT_DRIVER_REPLAYS=1`; same entry point with `res://tests/benchmark_test_drivers.gd -CommandTimeoutSeconds 900` | Real final 27-track five-lap input/telemetry capture; all finished. |
| `...python.exe backend/tools/report_predictive_drivers.py --report build/driver-benchmark.json --evidence docs/evidence/trajectory-pace-2026-10-08 --godot 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --project game` | **27 independently verified**, exact recorded/verified ticks, five laps and equal before/after manifests. |
| `...python.exe -m pytest backend/tests/test_predictive_drivers.py backend/tests/test_test_drivers_integration.py::test_profiles_generate_repeatable_distinct_verified_five_lap_races -q --tb=short --show-capture=no` | **8 passed**. Includes exact cold/warm oval and bridge recordings, stale/corrupt cache recovery, packaged worker, skill ordering, and the sharp Star / five-point spline fixtures. |
| `...python.exe -m pytest backend/tests/test_test_drivers.py backend/tests/test_automatic_test_drivers.py backend/tests/test_worker_lifecycle.py backend/tests/test_rivalry.py -k 'not postgres' -q --tb=short --show-capture=no` | **41 passed, four skipped, 15 deselected**. Actual idle generation/upload/verification and loss-of-cache recovery, development isolation, matching and shutdown. |
| Same native entry point with `res://tests/test_script_parse.gd` | **349 scripts, zero failures**. |
| Ruff on affected controller/tests/report Python | Passed. |
| `backend/tools/render_driver_comparison.ps1 -Evidence docs/evidence/trajectory-pace-2026-10-08` | Final PNG generated and inspected. |

The existing Starlette deprecation warning remains. The intermediate 0.82 envelope gained only 6.8% at the median; it was not reported as the final 10% result. The faster standing-only candidate accumulated 865 Speedy contacts; it was rejected after warm-lap qualification. A too-strict zero-contact selection discarded a fast line for a 22% slower alternative; bounded contact eligibility and an explicit selection cost replaced that experimental policy. A newly added test's variable-shadow parse error was corrected before the final passes. No failing physical/gate/replay invariant was removed.

## Changed files and limits

- `game/input/racing_trajectory.gd`: time objective, exact steering limit, shared acceleration/braking budget, revised margins, final-line surfaces and cache v3.
- `game/input/trajectory_planner.gd`: standing/flying qualification and contact eligibility/cost.
- `game/input/trajectory_mpc.gd`: feasible nominal steer, progressive saturation inverse and complete affine yaw-bound transformation.
- `game/input/profiled_route_driver.gd` and `backend/bmt_backend/test_driver_generator.py`: controller version 5.
- `game/tests/test_predictive_driver.gd` and `benchmark_test_drivers.gd`: meaningful envelope/model checks and candidate diagnostics.
- `backend/schemas/racing-trajectory-v3.schema.json`: new derived-cache contract; v2 retained.
- `backend/tools/report_predictive_drivers.py`, `render_driver_comparison.ps1`: mean/aggregate counts and accurate chart notes.
- This document, current status/plan and historical driver follow-up links; scoped checkpoint/evidence.

No cloud/backend rollout, database migration, player-file deletion, production deployment, phone/emulator test, Android export/install or full `Validate` was performed. Phone attachment was not checked. This task has no visible app UI change. The currently deployed cloud worker still needs the validated controller update before these gains appear there.

The 10.1% result is the arithmetic mean of per-track reductions for the specified neutral compact profile, not a guarantee of 10% on every circuit/driver/car. Other profiles retain their actual skill ordering and all five vehicle recovery checks pass, but a full fleet/population, every car on every circuit, physical-device/cloud CPU throughput and matching against actual human PBs remain untested. Cold planning costs more because of four candidates and flying-lap checks; subsequent drivers reuse the bounded cache. Trajectory spacing/progress still use the canonical route parameter, and the time solver remains a local proxy with pilot qualification rather than a global minimum-lap-time solver.
