# Further electric low-speed steering reduction ? 2026-10-25

ECS01: The owner reports that the current electric car still turns too quickly at slow speeds. ECS02: Preserve accepted high-speed handling, propulsion, release braking and the six other cars. R01: deterministic replay and versioned competitive identity. Q01: validation and owner/device feel acceptance.

Electric-8 changes only its version and low_speed_steering_scale from 0.60 to 0.35. The existing smooth fade from 2 to 8 m/s remains. Shared simulation, input, model, cameras and other car resources are untouched; physics remains arcade-planar-0.70. Electric configuration hash is c3f99add6732b13dfe168bcb1a9e281bf64fa4f9f43c8452c622cb7d2bc93a13. The backend fixture changes only its electric manifest entry; historical recordings remain.

Actual 0.2-second full-lock touch direction response falls another 43.86% at 3.6 km/h, 39.07% at 10.8, 18.57% at 18 and 2.66% at 25.2 compared with electric-7. Forward/reverse and left/right are checked. At or above 28.8 km/h the steering calculation remains exact. The new 87-check low-speed suite adds 24 direct comparisons against the rejected electric-7 resource. Owner correction supersedes the former minimum response ratio against electric-6; stronger upper response bounds prove the requested further reduction. The original test and source are retained under before/. No braking, high-speed or other-car bound is relaxed.

Changed files: game/resources/cars/electric.tres; game/tests/test_electric_low_speed_steering.gd; version expectations in test_electric_brake_release.gd, test_electric_power.gd, test_electric_power_balance.gd and test_electric_steering_response.gd; backend/tests/fixtures/verified_oval.json; this document; AGENTS.md; task evidence. All modifications are relative to actual task-start sources, preserving concurrent changes.

Commands and results:

- Pinned Godot 4.7.2: --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=res://../docs/evidence/electric-calmer-steering-2026-10-25. Low-speed 87, release 38, car 60, one-pedal 63, power 19, balance 22, response 86, turning 61 and laps 6 pass. The low-speed suite includes 135 exact high-speed single ticks, four full-second high-speed runs, exact straight acceleration/braking and 2400 exact ticks for each other car. Laps cover three circuits, five laps each, zero contacts and exact replay.
- Same invocation for test_script_parse.gd: 1194 scripts, zero failures.
- scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=TASK/native: 60 actual Garage/race checks pass.
- Same actual-App UI test with -RenderingMethod mobile -RenderingDriver vulkan and TASK/mobile-native: 60 checks pass on desktop Vulkan Mobile.
- Direct pinned Godot invocation of res://tests/export_electric_power_replay.gd -- --output=TASK/canonical-race.json records the current race. .tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-calmer-steering-2026-10-25/verify_canonical.py independently accepts 13270 inputs/five laps/110579 ms; distinct board identity is checked.

Backend command from backend/: ..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-calmer-pytest. Result: 72 passed, two existing explicit deselections (PostgreSQL and archived physics-050 ghost rejection), six existing warnings. No new exclusion.

Checkpoint verification: git -c core.autocrlf=false apply --reverse --check --ignore-space-change docs/evidence/electric-calmer-steering-2026-10-25/checkpoint.patch passes. The first ordinary reverse-check failed on Windows line-ending differences; no source discrepancy was present.

Initial scripts/dev.ps1 sandbox execution could not open its user log. Absolute workspace logs allowed native headless suites; Windows certificate-store diagnostics remain in those logs. The independent verifier initially rejected engine startup under sandbox restrictions; approved local execution then passed. PowerShell can report a nonzero pipeline status for these stderr diagnostics despite zero native test failures. Native UI manual-step hitch messages are retained and are not device performance measurements.

No physical-device test or attachment check, APK, deployment, live mutation, purchase or owner-process restart. Client reload, matching online verifier/config rollout and owner/device steering-feel acceptance remain. Task-only checkpoint.patch preserves a reviewable delta without staging concurrent work.
