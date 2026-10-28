# Gentler electric turn-in and small launch drift ? 2026-10-25

ELD01: The owner still finds slow-speed turning aggressive. ELD02: Add a little drift when accelerating from rest with steering held. ELD03/R01: Preserve controlled recovery, higher-speed handling, straight propulsion/release braking, exact replay and the six other cars. Q01: actual validation and remaining owner/device acceptance.

Electric-9 uses low_speed_steering_scale 0.29 instead of 0.35, low_speed_steering_rate_scale 0.12 and launch_lateral_response_scale 0.02. The steering-angle fade remains 2?8 m/s. Steering buildup uses the low rate through 4 m/s and smoothly restores the accepted rate by 8 m/s; releasing or initially opposing steering retains the accepted unwind rate. This softens the first movement while retaining sustained lock. At 1 m/s full lock takes about 0.3 seconds instead of 0.042 seconds. No input layout changes.

Rear-drive powered forward turns retain a small amount of lateral momentum: smooth activation between 0.35?0.65 pedal and 0.1?0.35 actual steering; full low-speed effect through 4 m/s, fading completely at 8 m/s. This changes lateral response, with no extra yaw impulse or drive boost. Straightening/lifting restores ordinary response without a latch; reverse does not receive this launch aid. The aid depends on current low-speed powered turning rather than a clock or stored launch flag.

Actual 0.2-second full-lock touch course response falls another 74.94% at 3.6 km/h, 74.19% at 10.8, 41.57% at 18 and 2.82% at 25.2 compared with rejected electric-8. At full steering/65% pedal, slip at 0.3 seconds rises from 0.49 to 1.24 degrees and at 0.5 seconds from 1.69 to 4.73. Full-pedal slip at 0.3 seconds rises from 1.27 to 2.55 degrees. Maximum measured slip across all six launch cases is 4.745 degrees; all recover below 0.1 degree after straightening. These are isolated dry-road simulation measurements, not owner/device feel acceptance.

Shared physics becomes arcade-planar-0.71. New opt-in fields are omitted from default config snapshots, preserving all six other vehicle hashes. The EV hash is f82b2f9f70a69ad2c4ed719ba5809dabe0a9b9734515e1ae8d15b0652e4afc0b. Only the physics version and electric entry change in the backend fixture. Historical recordings/rules are retained; matching client/verifier rollout remains necessary. Model, production cameras, controls and six other car resources are untouched.

## Actual validation

Pinned Godot: C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe. OUT below is res://../docs/evidence/electric-launch-drift-2026-10-25. Headless command: --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=OUT.

| Suite | Final outcome |
| --- | --- |
| test_electric_launch_drift.gd | 111 checks, zero failures: softer onset, held steering authority, quick unwind/countersteer onset, extra slip versus actual electric-8 and same-tune aid-off, symmetry, bounded slide, recovery, inactive cases and exact replay. |
| test_electric_low_speed_steering.gd | 87 checks, zero failures; 135 exact higher-speed single ticks, four exact full-second high-speed runs, straight propulsion/braking and 2400 exact ticks for each other car. |
| test_electric_brake_release.gd / test_electric_car.gd / test_electric_one_pedal.gd | 38 / 60 / 63 checks, zero failures. Exact 72 km/h release stop remains 0.7667 seconds / 7.5626 metres. |
| test_electric_power.gd / test_electric_power_balance.gd / test_electric_steering_response.gd / test_electric_turning.gd | 19 / 22 / 86 / 61 checks, zero failures. |
| test_electric_power_laps.gd | Six checks, zero failures; three circuits times five laps with exact replay and zero contacts. |
| test_handling.gd / test_rewind.gd / test_script_parse.gd | 88 / 61 / 1204 checks/scripts, zero failures. |
| test_electric_car_ui.gd | 60 Compatibility and 60 desktop Vulkan Mobile actual Garage/race checks pass. |

Native App command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/final-native. Second run uses -RenderingMethod mobile -RenderingDriver vulkan and OUT/final-mobile-native. Captures retain the actual model/controls; manual-step hitch diagnostics are not performance measurements.

Actual recording: pinned headless Godot --script res://tests/export_electric_power_replay.gd -- --output=OUT/canonical-race.json. Independent verification: .tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-launch-drift-2026-10-25/verify_canonical.py. Accepted 13270 inputs/five laps/110579 ms, lap ticks [2728,2635,2636,2636,2635], distinct board identity and unchanged other-car config entries. This conservative oval recording alone does not measure the launch drift; dedicated launch tests do.

Final backend: 72 passed, two existing explicit deselections (PostgreSQL and archived physics-050 ghost rejection), six existing warnings; no new exclusion. Command from backend/: ..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-launch-drift-accepted-pytest.

## Retained failures and review boundary

The initial stronger angle reduction (0.22 held through 4 m/s) made turns too wide: hiekka failed completion, and arto4 recorded contacts. That exact rejected tune and log are retained under rejected-hold-tune/. The final solution keeps more sustained steering angle and slows buildup instead; the same unmodified lap suite now passes all three circuits with zero contacts. No diagnostic driver, completion timeout, replay assertion or contact accounting was changed.

Initial launch fixtures incorrectly compared a full second dominated by normal-speed handling; they now compare the first 0.2 seconds for nose response and the under-4-m/s phase for launch slip. An invalid VehicleState.restore call was corrected to explicit initial-state assignments. Raw initial logs and subsequent unsuccessful tune logs remain. The owner-requested further softening supersedes the old minimum response ratio against electric-6: its floor changes from 0.2 to 0.05, while all stronger upper bounds, symmetry, high-speed exactness and braking assertions remain. Dedicated held-lock checks guard against loss of turning authority. Launch-slip bounds were tightened to 8 degrees; every firm-steering launch must exceed rejected electric-8 slip by 30% without a spin.

Initial sandbox launches report certificate-store access diagnostics; approved local Godot runs provide the final results. One backend invocation started from the wrong working directory before the fixture update and was interrupted after two tests; it is not counted as a passing final run. Earlier backend/UI passes precede the final tune and are not substituted for final results.

Changed sources: game/resources/cars/electric.tres; game/vehicle/handling_config.gd; game/vehicle/vehicle_simulation.gd; game/tests/test_electric_launch_drift.gd and its UID; game/tests/test_electric_low_speed_steering.gd; current version expectations in test_electric_brake_release.gd, test_electric_power.gd, test_electric_power_balance.gd and test_electric_steering_response.gd; backend/tests/test_verifier.py; backend/tests/fixtures/verified_oval.json; AGENTS.md; this document and task evidence. Task-start before/ snapshots and checkpoint.patch isolate this work from concurrent changes.

No physical-device test or attachment check, APK, live mutation, purchase, deployment, merge or owner-process restart. Client reload/rebuild, matching verifier rollout and owner/device steering/drift acceptance remain.
