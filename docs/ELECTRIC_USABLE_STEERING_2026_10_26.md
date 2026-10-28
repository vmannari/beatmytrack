# Restore usable electric steering ? 2026-10-26

EUS01: Owner rejects electric-12 as extremely stiff and unable to turn on many tracks. EUS02: Check the named Over and under track and ordinary 90-degree corners with keyboard/controller input. EUS03/R01/Q01: Preserve continuous speed behavior, 190 km/h, straight propulsion/release braking, small launch slip, exact replay, six other cars and track geometry.

The preceding tune overcorrected steering authority and input timing. Electric-13 changes only six resource fields: version12to13; steering_rate2to6; countersteering_rate6to12; steering_angle0.26to0.38 radians; continuous base radius9to6.5m; and radius acceleration scale18to36. Full lock now builds in about0.167 seconds instead of0.5. The first100ms remains progressive, and input response stays uniform across speeds. The continuous radius equation remains active through190:6.5m+speed-squared/36. There is no return of the old40?60km/h tight-turn fade.

VehicleSimulation and RouteDriver bytes remain identical to task start; physics stays arcade-planar-0.73. HandlingConfig changes only its inspector range hint to allow36 (maximum20to80), without runtime value/behavior changes. The final manifest confirms all seven expected configuration identities after that metadata change. Propulsion, braking, speed cap, controls/bindings, collision dimensions, model, camera and roads remain. In particular, no further diagnostic steering/planning change is used to obtain these results.

## Measured turning authority

Full held circles, ordinary quantized pedal feedback and exact input replay:

| Speed | Electric-12 radius | Electric-13 radius |
| --- | --- | --- |
| 5 km/h | 9.53 m | 6.55 m |
| 20 km/h | 10.72 m | 7.36 m |
| 30 km/h | 12.86 m | 8.43 m |
| 40 km/h | 15.86 m | 9.93 m |
| 60 km/h | 24.44 m | 14.22 m |
| 190 km/h | 163.75 m | 83.88 m |

The primary530-check suite now requires materially more useful steering than the rejected stiff tune, usable lock within200ms, a non-instant first100ms, monotonically widening turns and uniform input slew across1?190km/h. It retains controller partial strengths, real mapped synthetic keyboard/controller events, reversal/release, task-start-exact straight propulsion/braking in both directions and exact other-car driver inputs.

## Direct 90-degree steering test

A fixed analytic road has a6m centreline radius and10m width. Steering uses only a full left/right key press, followed by release at87degrees; analog pedal feedback holds repeatable20/30km/h comparison speeds. This isolates digital steering authority, not a claim that a human drove the recorded inputs. The test never uses RouteDriver, resets velocity during the turn, changes road dimensions or supplies steering assistance. Its limit covers the configured collision envelope, not a triangle-level visual-body fit certification.

The exact rejected resource produces16checks/eight failures: all four left/right corner cases exceed road bounds and are too slow. The corrected resource passes the same16checks with all limits unchanged, exits aligned/moving and replays exactly:

| Entry speed | Old time to unwind at 87 deg | New | Old maximum lane-centre error | New |
| --- | --- | --- | --- | --- |
| 20 km/h | 3.242 s | 2.158 s | 6.384 m | 2.103 m |
| 30 km/h | 2.650 s | 1.683 s | 9.363 m | 3.544 m |

The accepted centre-error bound is the5m road half-width minus the retained1.4m collision radius, with2cm numerical tolerance. Left/right results are symmetric.

## Over and under

The named cached source is game/resources/cloud_tracks/ecde9782d147738d3ab50d94a4a14255dd1e79069d96823960c77c46a394c948.json, document track_2428fcd33a076ea8. Parsed data matches the retained over_and_under.json bridge fixture exactly. It contains ordinary tight curves/hairpins and three bridges; the document is unchanged.

The new seven-check native test drives all five ordered laps with the unchanged diagnostic driver:35027 inputs, zero contacts,5493 upper-level ticks and29534 lower-level ticks. Full JSON input replay is exact. The independent server reader accepts the actual named-track recording at291885ms with lap ticks[7070,6990,6987,6990,6990], electric-13 hash d2b013ffe9efdd773ab9a0d30e6189c5ab5ed3999f1d4c6d436c5adef5eeae4a and distinct electric board identity. This is Over and under itself, not a substitute oval recording.

Actual-App keyboard/controller tests run in a fresh Over and under Game, after retained D/R/exact-stop tests on their original flat ellipse. Both Compatibility and desktop Vulkan Mobile pass70checks, including full keyboard steering, bounded but useful heading change, partial controller input and release. Native screenshots show the requested track. Physical keyboard/controller hardware and owner feel were not tested.

## Actual commands and results

Pinned engine: C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe. OUT is res://../docs/evidence/electric-usable-steering-2026-10-26. Headless suites use --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=OUT.

| Final suite | Passing checks |
| --- | --- |
| test_electric_corner_authority.gd / test_electric_over_under.gd / test_electric_consistent_handling.gd |16 /7 /530 |
| test_electric_190.gd / test_electric_turn_radius.gd / test_electric_launch_drift.gd / test_electric_low_speed_steering.gd |59 /64 /111 /87 |
| test_electric_brake_release.gd / test_electric_car.gd / test_electric_one_pedal.gd |38 /60 /63 |
| test_electric_power.gd / test_electric_power_balance.gd / test_electric_steering_response.gd / test_electric_turning.gd |19 /19 /86 /61 |
| test_electric_power_laps.gd / test_handling.gd / test_rewind.gd / test_script_parse.gd |6 /88 /61 /1234 |

All final suites have zero failures. Three retained legacy circuits each complete five laps with zero contacts and exact replay. The190cap,0?100time1.4917s and190release stop2.0083s/52.285m remain;72release stop remains0.7667s/7.5626m. Small launch slip is still measured against the same new tune with its launch aid disabled, with bounded slip/recovery and retained forward traction.

The named-track test writes over-under-race.json; canonical-race.json is a byte copy for the existing independent reader harness. Verification command: .tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-usable-steering-2026-10-26/verify_canonical.py. All six other vehicle entries remain exact; shared physics identity does not change.

Native App command: powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=OUT/native-final2','--over-and-under')". Mobile uses -RenderingMethod mobile -RenderingDriver vulkan and OUT/mobile-final2. These are separate test processes; owner processes are not restarted. Manual-step hitch diagnostics are not performance measurements.

Final backend from backend/: ..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-usable-steering-final-pytest.72passed, two existing explicit deselections (PostgreSQL and archived physics-050 rejection), six existing warnings in110.00s. No new exclusion. The actual new Over and under recording is independently accepted despite the unrelated archived rejection fixture remaining excluded.

## Retained failures and integration corrections

The first launch rerun retains111checks/five failures against the superseded requirement for still less launch heading than electric-8. Restored useful input now uses a bounded positive first200ms heading (<3degrees), with the existing8degree slip, recovery, traction and aid-off comparisons retained. The primary former slower-than-task-start/radius-growth targets are explicitly superseded by the owner's latest usability correction; constant input rate and monotonic speed behavior remain.

Four initial response checks fail only because float32 rotated velocity magnitude is52.7777824401855 versus the52.77778 scalar cap. The speed guard now allows0.00001m/s normalization roundoff; no production cap or physics is changed. Logs/initial JSON remain. The initial Over and under helper also collided with Godot's seed builtin; its name was corrected without changing simulation behavior.

The first graphical test lost OS focus and auto-paused, yielding18 input failures. The harness now waits for preparation and resumes through the real pause action before driving. A later all-on-Over-and-under exact-stop fixture exposed an unchanged rotated-vector residual: the isolated before/after probe gives identical velocity about1.46e-12m/s after40ticks. Original exact-stop assertions remain on their original flat fixture; requested-track keyboard/controller assertions run in a fresh Game. The probe's cleanup warnings remain in its diagnostic log. Production focus handling and stop code are untouched.

Initial backend71pass/one failure reproduces in the standalone test because concurrent attempt_evidence.gd preloads race/input_record.gd, missing from the staging list. Native standalone-engine.log records the exact missing dependency. stage_verifier.py now includes that existing file; the concurrent input-record implementation is untouched. Final full backend72passes with no additional exclusion. One attempted correction command used the wrong working directory and made no source change before the corrected application.

Task-start files, final hashes, commands and scoped checkpoint are in report.json/before/. Source changes require reload/rebuild and matching client/verifier configuration rollout. Owner keyboard/controller feel acceptance remains. No physical-device attachment check/test, APK, purchase, live mutation, deployment, merge or owner-process restart. Concurrent Garage/model/track/replay work is preserved.
