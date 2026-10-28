# Consistent electric keyboard/controller handling ? 2026-10-26

ECH01: Owner still finds slow handling too agile. ECH02: Faster handling must progress consistently from slower handling. Owner specifies keyboard/controller. ECH03/R01/Q01: Retain 190 km/h, accepted straight propulsion/release braking, a small launch slide, exact replay and six other cars; validate actual input paths and circuit usability.

The old profile stacked three transitions: steering angle restored by 28.8 km/h, input buildup restored over 14.4?28.8, and the radius envelope disappeared over 40?60. That last fade made turns tighten sharply as speed increased. Simply slowing turn-in did not fix it.

Electric-12 removes both electric-only low-speed steering scale overrides, uses a fixed 2.0/s buildup and 6.0/s unwind/initial countersteer rate, and changes maximum wheel angle from 0.82 to 0.26 radians. Continuous radius mode applies at every speed: radius envelope = 9 m + speed squared / 18 m/s squared, scaled by actual steering input. The existing wheel/traction demand may require a wider radius. Power/lift yaw shares the envelope; actual yaw still follows inertia/response. There is no high-speed fade restoring tight lock. Other vehicles default to the unchanged legacy branch; the new false flag is omitted from their snapshots.

Full input builds over 0.5 seconds at all speeds. Partial controller input reaches its smaller target proportionally. The existing controller deadzone and keyboard/controller bindings remain. Release and initial countersteer use the same faster unwind rate at every speed.

## Actual input and circle measurements

The 200 ms comparison uses DriverInput action sampling, the exact task-start electric-11 resource/simulation and the new one, with identical full keyboard input and near-neutral accelerator:

| Speed | Old 200 ms course change | New | Reduction |
| --- | --- | --- | --- |
| 5 km/h | 0.299 deg | 0.194 deg | 35.2% |
| 10 km/h | 0.652 deg | 0.379 deg | 41.9% |
| 20 km/h | 5.535 deg | 0.692 deg | 87.5% |
| 30 km/h | 7.893 deg | 0.864 deg | 89.1% |

Held circles use ordinary quantized feedback pedal input, with no velocity reset during measurement, three seconds of settling and accumulated actual travel-direction angle. Both original and current simulations run, with input replay checked:

| Requested speed | Old full-lock radius | New full-lock radius |
| --- | --- | --- |
| 5 km/h | 10.42 m | 9.53 m |
| 20 km/h | 6.00 m | 10.72 m |
| 30 km/h | 7.72 m | 12.86 m |
| 40 km/h | 13.72 m | 15.86 m |
| 50 km/h | 5.53 m | 19.72 m |
| 60 km/h | 4.90 m | 24.44 m |

Parking lock is deliberately usable: the 5 km/h held radius is slightly smaller, while the actual keyboard onset is 35% calmer. The rejected first proposal made parking lock over 12 m and could not navigate the tight regression circuits cleanly. The final curve instead combines slower input buildup with wider turns at normal low speeds. Radius increases continuously through 40?60 and onward; the new 90/190 km/h circles measure about 43.7/163.8 m while holding the requested speeds. The old profile could not sustain those nominal speeds in its full-lock circle, so its higher-speed radii are not presented as matched-speed comparisons.

The primary 525-check suite covers eighteen full-circle speed pairs, partial controller strengths, symmetry/replay, one-km/h curvature and input-rate sweeps through 190, actual mapped keyboard and controller-axis events, ten unchanged power/braking fields and 2400 exact straight propulsion/release/hold ticks in each direction against task-start physics. Six other diagnostic drivers retain exact inputs across 600 ticks each. Physical keyboard/controller hardware was not tested; the events are synthetic native events.

## Circuit and runtime integration

The conservative diagnostic RouteDriver now plans earlier only for the continuous profile and inverts its effective curvature for a pure-pursuit steering request. It still emits ordinary quantized input. Keyboard/controller gameplay remains directly sampled by DriverInput. The old three-point aim assumed nearly instant steering; with a finite ramp it cut bends too late. Other cars retain their exact driver inputs.

Final unmodified five-lap completion/replay assertions pass on all three legacy circuits, with zero contacts: arto4, hiekka and ovaali3. Initial wide-lock runs and the first planning attempt retain incomplete hiekka/contact failures. No roads, gates, lap budget or collision accounting are changed.

Actual-App tests add mapped keyboard full input, calm 200 ms steering and release, plus partial controller-axis input/release through Game._physics_process. 67 checks pass in Compatibility and 67 in desktop Vulkan Mobile, alongside the retained Garage/race checks and production model captures. No camera/model/art source is changed.

Straight propulsion/braking is tick-exact versus task start, including D/R. The retained 190 test reaches 190 in 3.2667 seconds, holds 30 seconds, and stops on release in 2.0083 seconds / 52.285 m. The accepted 72 km/h stop remains 0.7667 seconds / 7.5626 m. The launch-slip suite retains extra sideways momentum versus the same new tune with its launch aid disabled, bounded slide and recovery.

Physics is arcade-planar-0.73, electric version 12, hash a5c04a5a2037ed8005324fc42952d267b4ee90ff428444cdfdb3b4ebc67d6353. Six other configuration entries are exact; their simulation/driver comparisons pass. The backend fixture changes only physics identity and electric entry. A shared physics identity changes competitive board identity even where arithmetic is unchanged; historical recordings/rules are not rewritten and matching rollout is still required.

## Actual commands and results

Pinned engine: C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe. OUT = res://../docs/evidence/electric-consistent-handling-2026-10-26. Headless suites use --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=OUT.

| Final suite | Passing checks |
| --- | --- |
| test_electric_consistent_handling.gd | 525 |
| test_electric_190.gd / test_electric_turn_radius.gd / test_electric_launch_drift.gd / test_electric_low_speed_steering.gd | 59 / 64 / 111 / 87 |
| test_electric_brake_release.gd / test_electric_car.gd / test_electric_one_pedal.gd | 38 / 60 / 63 |
| test_electric_power.gd / test_electric_power_balance.gd / test_electric_steering_response.gd / test_electric_turning.gd | 19 / 19 / 86 / 61 |
| test_electric_power_laps.gd / test_handling.gd / test_rewind.gd / test_script_parse.gd | 6 / 88 / 61 / 1217 |

All final suites have zero failures. Native App command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/native. Second run uses -RenderingMethod mobile -RenderingDriver vulkan and OUT/mobile-native. Manual-step hitch diagnostics are not device performance measurements.

Actual recording: pinned headless engine --script res://tests/export_electric_power_replay.gd -- --output=OUT/canonical-race.json. .tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-consistent-handling-2026-10-26/verify_canonical.py independently accepts 17354 inputs/five laps/144613 ms, lap ticks [3542,3453,3453,3453,3453], the new identity and six unchanged config entries. The calmer turn profile legitimately makes this diagnostic oval slower than the previous 115122 ms.

Backend from backend/: ..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-consistent-handling-pytest. 72 passed, two existing explicit deselections (PostgreSQL and archived physics-050 ghost rejection), six existing warnings in 134.14 s. No new exclusion.

## Superseded expectations and retained failures

Task-start profile testing records 498 checks / 62 failures, including speed-dependent restoration of tight curvature and abrupt input changes. The first proposed wide-lock profile passes its initial sweep but fails legacy circuit usability; it is retained under rejected-wide-lock/. Its blanket parking-radius target was replaced by actual keyboard-onset bounds while retaining monotonic radius and wider 15?30 km/h turns. Final physical-key events need two settled frames; the first fixture sampled too early and reused a key object, both retained and corrected. A first incomplete run produced no completion report; subsequent direct runs provide the final results. The primary JSON was renamed continuous-handling.json after colliding with the existing car suite's handling.json in this new evidence folder; final outputs are separate.

The owner's consistency correction supersedes the original faster/tighter high-speed targets, minimum drift against an older aggressive tune, fixed fast input timing and unchanged-steering-field expectations. Exact before sources and *-superseded.log retain speed 66/7 failures, radius64/1, launch111/8, low87/13, power19/2 and balance22/3. The superseded response fixture also hits its old five-second quarter-turn limit and accesses missing completion data; the interrupted log is retained. Its eight-second measurement window and safe dictionary access now accommodate the intentionally wider/slower high-speed turn without changing the lap budget.

Current assertions require slower/wider turns and gentler onset, monotonic curvature across the entire range, half-second lock buildup, recovery and quick initial reversal. The old minimum low-speed response floor changes from0.05to0.02 for the further owner-requested softening; actual keyboard onset, held circles and controller-strength checks directly guard usable response. Power yaw must share the continuous envelope, replacing the old expectation that full throttle adds extra normal-speed heading. The power-balance suite retains exact comparisons for unchanged fields; three deliberately changed steering fields move to the new handling contract. Braking, speed cap, zero hold, power authority, replay/rewind, collisions and six-other-car bounds remain.

Changed files/hashes and task-start sources are in report.json and before/. checkpoint.patch isolates this task, including diagnostic planning and test-contract replacements, while retaining concurrent vehicle quality, track, Garage and other work. No physical-device attachment check/test, APK, purchase, live mutation, deployment, merge or owner-process restart. Reload/rebuild, matching client/verifier rollout and owner keyboard/controller feel acceptance remain.
