# Tighter electric held steering — 2026-10-26

EHT01: Owner still finds electric-14 stiff. The follow-up explicitly identifies prompt response but too wide a curve. EHT02: Tighten sustained steering while retaining prompt input buildup and smooth speed progression. EHT03/R01/Q01: Preserve 190 km/h, braking, modest launch slip, exact replay, other vehicles and concurrent work.

Electric-15 keeps steering buildup at 6/s: about 0.167 seconds to full lock. Each steering sample in the first 24 ticks remains task-start exact. Maximum wheel angle increases 0.60→0.78 rad; high-speed steering reduction changes 0.50→0.40. The continuous radius envelope becomes `2.5 + speed²/70` instead of `3.5 + speed²/60`, in metres and metres/second. Measured held circles widen monotonically through 190 km/h, including the 1 km/h curvature sweep. No speed threshold restores sudden tight lock.

Stronger lock initially overshot the unchanged outgoing-corner alignment bound at 30 km/h. Unwind/countersteer rate increases 20→40/s to catch the release; steering buildup remains unchanged. Stronger launch rotation initially exceeded the existing 8-degree slip ceiling. Launch lateral-response scale changes 0.02→0.16 to retain a small slide with the stronger steering: six launch cases peak at 7.235 degrees, retain traction and recover below 0.1 degrees. No motor, brake, speed, collision, input-binding, model or camera field changes.

Production scope is the electric resource. Physics remains `arcade-planar-0.73`; shared VehicleSimulation, HandlingConfig and RouteDriver are byte-exact task start. Manifest identity is electric-15 / `ec52cbce257e3552996e8515894b985c976cd4e8586c1ef11810607779b661c3`. Only the electric entry changes in the backend fixture; the other six vehicle identities remain exact.

## Actual steering measurements

Full simulated travel circles use quantized analog pedal feedback to maintain speed, with symmetry and exact recorded replay checks.

| Speed | Electric-14 | Electric-15 | Tighter |
| --- | --- | --- | --- |
| 5 km/h | 3.866 m | 2.682 m | 30.6% |
| 10 km/h | 4.014 m | 2.780 m | 30.8% |
| 20 km/h | 4.336 m | 2.988 m | 31.1% |
| 30 km/h | 4.695 m | 3.497 m | 25.5% |
| 40 km/h | 5.563 m | 4.272 m | 23.2% |
| 60 km/h | 8.136 m | 6.478 m | 20.4% |
| 90 km/h | 13.928 m | 11.440 m | 17.9% |
| 140 km/h | 28.716 m | 24.120 m | 16.0% |
| 190 km/h | 49.939 m | 42.307 m | 15.3% |

The original 32 direct 90-degree corner assertions remain, including 8 m road width / 4 m centreline radius and 10 m width / 6 m radius, both steering directions at 20/30 km/h. Steering is a binary hold then release at 87 degrees of travel direction; throttle uses analog speed feedback. All 32 pass. On the narrow bend, time to release is 0.967/0.783 seconds, maximum centreline error is 0.861/0.708 m, and outgoing course is 94.13/96.69 degrees. The unchanged 1.40 m gameplay collision envelope fits the lane, with exact replay. This measures the configured collision envelope, not every rendered body vertex or physical full-throttle keyboard driving.

Over and under completes five ordered diagnostic laps with zero contacts, traversing both bridge layers. Its actual 36,278 recorded inputs independently pass the server reader: 302,313 ms, lap ticks `[7312,7238,7242,7243,7243]`. `canonical-race.json` is a byte copy of this track's `over-under-race.json`. Five production Storm tracks each complete one diagnostic lap, and three retained legacy circuits each complete five diagnostic laps, all with zero contacts and exact replay. Production race rules remain five laps. Artificial drivers do not establish human feel acceptance or certify every track.

Actual Game keyboard/controller tests in Over and under pass 70 checks in Compatibility and 70 in desktop Mobile/Vulkan. Both keep their D/R, exact-stop, Garage, partial-controller and release guards. Keyboard steering reaches 1.0 in 200 ms, with an actual heading change of 8.813 degrees. Native screenshots are retained separately for each renderer. Hitch logs from manual physics stepping are not performance measurements.

## Validation and commands

Evidence: `docs/evidence/electric-tighter-held-steering-2026-10-26`. Pinned engine: `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Headless runs use `--headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=res://../docs/evidence/electric-tighter-held-steering-2026-10-26`.

| Final checks | Passing counts |
| --- | --- |
| held_authority / corner_authority / consistent_handling | 53 / 32 / 530 |
| over_under / normal_tracks / power_laps | 7 / 20 / 6 |
| 190 / turn_radius / launch_drift / low_speed_steering | 57 / 64 / 111 / 87 |
| brake_release / car / one_pedal / power / power_balance | 38 / 60 / 63 / 19 / 18 |
| steering_response / turning / handling / rewind / script_parse | 86 / 61 / 88 / 61 / 1270 |

All final suites have zero failures. Import through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` passes. Straight propulsion/release/hold remains task-start exact for 2,400 ticks in each direction. Six other drivers retain exact input sequences. The 190 km/h hold, 0–100 time 1.4917 s, 190 release stop 2.0083 s / 52.285 m and 72 release stop 0.7667 s / 7.5626 m remain.

Native runs use the existing `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical`, with `-RenderingMethod gl_compatibility` or `-RenderingMethod mobile -RenderingDriver vulkan`, and `-TestArgument @('--evidence-root=OUT/native-RENDERER','--over-and-under')`. The launcher runs in `powershell -NoProfile -ExecutionPolicy Bypass`. Independent verification: `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-tighter-held-steering-2026-10-26/verify_canonical.py`.

From backend/: `..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-tighter-held-steering-pytest` gives 72 passed, two existing explicit deselections, six warnings in 137.33 s. PostgreSQL and the archived physics-050 rejection fixture remain the only exclusions; the actual new requested-track recording is independently accepted.

## Retained failures and changed expectations

The first stronger-lock proposal with the preceding launch aid peaks at 10.459 degrees of launch slip (53 checks / 1 failure). Increasing lateral response retains the original 8-degree ceiling. The first 20/s unwind produces four corner exit-alignment failures (32/4); 40/s corrects them without changing the lane or 7-degree alignment assertions. Raw logs and first-pass JSON remain.

Latest owner feedback supersedes earlier wide-radius and minimum-onset-gain expectations. Initial old contracts retain consistency530/4, launch111/1, low87/32, response86/14, radius64/13 and turning61/9. New contracts require at least 20% tighter measured held circles through 60 km/h and 10% beyond, task-start-exact input buildup, the new independent radius floor including reverse, and unchanged monotonicity/replay/propulsion bounds. Higher-speed accelerating turns compare with electric-14 for at least 10% tighter paths and no slower completion. Historical first-100ms response retains a 25% reduction versus original electric-3; low-speed response retains a 15% reduction versus original electric-6.

The stronger geometry raises full-throttle first-200ms launch heading to 3.845 degrees; its former 3-degree bound becomes 4 degrees while the existing slip, traction, symmetry and recovery ceilings remain. The actual Game fixture initially retains70/1 against the superseded 8-degree onset heading ceiling. Its bound becomes10 degrees for the stronger curve, with the exact original normalized input timing checks retained. The 190 suite skips the deliberately changed launch-response field, reducing its count58→57. These are explicit requested geometry-contract changes, rather than production changes to pass old targets.

`report.json`, exact before sources and a task-scoped `checkpoint.patch` retain commands, measurements, hashes and changed files. The patch is reverse-checked against the working tree with `git -c core.autocrlf=false apply --reverse --check --ignore-space-change`. No staging/commit or unrelated source restoration occurs.

Reload/rebuild, matching verifier configuration rollout and owner keyboard/controller feel acceptance remain. No physical-device attachment check or device test, APK, purchase, live mutation, deployment, merge or owner-process restart is performed. Concurrent work is preserved.
