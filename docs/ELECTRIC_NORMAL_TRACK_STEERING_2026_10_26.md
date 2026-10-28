# Electric turning authority for normal tracks — 2026-10-26

ENS01: The owner still finds electric-13's turning radius too long to drive normal tracks. ENS02: Restore usable keyboard/controller steering on ordinary 90-degree bends, including the named Over and under circuit. ENS03/R01/Q01: Retain smooth speed progression, the 190 km/h cap, braking, modest launch slip, canonical replay and the other six cars.

Electric-14 changes six resource fields, including its version. Steering angle rises from 0.38 to 0.60 radians. The continuous radius envelope changes from `6.5 + speed² / 36` to `3.5 + speed² / 60`, with metres and metres/second. High-speed steering reduction changes from 0.25 to 0.50 so wheel angle reduces progressively with speed. Unwind/countersteer rate rises from 12 to 20 per second to straighten promptly after releasing the stronger lock. Steering buildup remains 6 per second, about 0.167 seconds from centre to full lock. There is no 40–60 km/h restoration of tight lock.

Production scope is `game/resources/cars/electric.tres`. Shared VehicleSimulation, HandlingConfig, RouteDriver and the actual Game UI test remain byte-identical to task start. Physics remains `arcade-planar-0.73`. The electric manifest entry becomes electric-14 / `d1821d975b06d2b1b90afd8234da019415b1f2b557b09ffcbdbed648dcb0b38c`; the other six vehicle identities remain exact. Motor/braking/collision dimensions, input bindings, models, cameras and track documents are not edited by this task.

## Measured held circles

These are actual simulated travel paths with quantized pedal feedback to maintain the stated speed, rather than a calculation from steering angle alone. Both directions and exact recorded replay are checked.

| Speed | Electric-13 radius | Electric-14 radius | Reduction |
| --- | --- | --- | --- |
| 5 km/h | 6.55 m | 3.87 m | 41.0% |
| 10 km/h | 6.71 m | 4.01 m | 40.2% |
| 20 km/h | 7.36 m | 4.34 m | 41.1% |
| 30 km/h | 8.43 m | 4.70 m | 44.3% |
| 40 km/h | 9.93 m | 5.56 m | 44.0% |
| 60 km/h | 14.22 m | 8.14 m | 42.8% |
| 190 km/h | 83.88 m | 49.94 m | 40.5% |

The primary 530-check suite retains a monotonically widening measured path from 5 through 190 km/h, one-km/h curvature checks from 1 through 190, uniform steering buildup, progressive first 100 ms, useful held lock by 200 ms, controller partial strengths, mapped synthetic keyboard/controller events and immediate release/reversal. Straight propulsion/release/hold remains task-start exact for 2,400 ticks in each direction. Six other diagnostic drivers retain exact input sequences.

## Corners and circuits

The direct corner test retains its original 16 checks on a 10 m wide, 6 m centreline-radius 90-degree bend. Sixteen new checks cover an 8 m wide, 4 m centreline-radius bend at 20 and 30 km/h, left and right. Steering is a binary hold then release at 87 degrees of actual travel direction, without RouteDriver steering. Speed is maintained by synthetic analog pedal feedback; this is not a physical keyboard full-throttle test.

The task-start electric-13 produces 32 checks / 8 failures: both narrow-corner timing and collision-envelope bounds fail in each direction at each speed. Electric-14 passes all 32. On the narrow bend, maximum centreline error falls from 4.103 to 1.102 m at 20 km/h and from 5.544 to 1.835 m at 30 km/h. Adding the unchanged 1.40 m collision radius fits the 4 m lane half-width. Time to steering release falls from 2.158 to 1.333 seconds and from 1.683 to 1.008 seconds respectively. Exits remain moving and within 7 degrees of the outgoing road, with exact replay. These bounds cover the configured gameplay collision envelope, not every rendered body vertex.

The unchanged diagnostic RouteDriver completes five ordered laps of the actual bundled Over and under document with zero contacts, crossing both bridge layers. Its 35,408 recorded inputs independently pass the local server reader: 295,062 ms, five lap ticks `[7137, 7068, 7065, 7067, 7071]`. The recording is the requested track itself; `canonical-race.json` is a byte copy of `over-under-race.json`. The electric board identity changes while the six other vehicle entries remain exact.

The five current production Storm tracks also complete one diagnostic ordered lap each, with zero contacts and exact replay: Thunder Freight, Blackout Switchyard, Rainbreak Ridge, Slatewater Quarry and Eye of the Storm (20 checks). Three retained legacy circuits each complete five diagnostic laps with zero contacts and exact replay (6 checks). These artificial drivers supplement the direct corner and input checks; they do not establish human driving acceptance or certify every track.

Actual App/Game tests retain their original D/R, exact-stop and Garage checks, then exercise keyboard/controller input in a fresh Over and under Game. Compatibility and desktop Mobile/Vulkan each pass 70 checks. The test source remains exact; no input assistance or track change is introduced. Native logs and final desktop Mobile screenshots are retained under the evidence directory. Manual-step hitch diagnostics are not performance measurements.

## Actual commands and results

Evidence directory: `docs/evidence/electric-normal-track-steering-2026-10-26`. Engine: `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Each headless suite uses:

```text
GODOT --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=res://../docs/evidence/electric-normal-track-steering-2026-10-26
```

| Suite | Passing checks |
| --- | --- |
| electric_corner_authority / electric_over_under / electric_normal_tracks | 32 / 7 / 20 |
| electric_consistent_handling / electric_190 / electric_turn_radius | 530 / 58 / 64 |
| electric_launch_drift / electric_low_speed_steering / electric_brake_release | 111 / 87 / 38 |
| electric_car / electric_one_pedal / electric_power / electric_power_balance | 60 / 63 / 19 / 18 |
| electric_steering_response / electric_turning / electric_power_laps | 86 / 61 / 6 |
| handling / rewind / script_parse | 88 / 61 / 1259 |

All final suites have zero failures. Import through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` also passes. Two leaf test assertions were subsequently strengthened and re-executed: explicit new continuous-radius floors and a 25% minimum onset reduction versus original electric-6. Source syntax is compiled by those runs.

The 190 km/h cap is held for 30 seconds; 0–100 remains 1.4917 seconds, 190 km/h release stop remains 2.0083 seconds / 52.285 m, and the accepted 72 km/h release stop remains 0.7667 seconds / 7.5626 m. Launch aid strength remains 0.02. Peak slip in the six accelerating launch-turn cases is 7.255 degrees, below the retained 8-degree ceiling; traction, aid-off comparison and recovery below 0.1 degrees pass.

```text
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/electric-normal-track-steering-2026-10-26/native-final','--over-and-under')"
```

The second native run uses `-RenderingMethod mobile -RenderingDriver vulkan`. Both use separate test processes; the second run refreshes the same screenshot directory. The independent canonical command is `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-normal-track-steering-2026-10-26/verify_canonical.py`.

From `backend/`:

```text
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-normal-track-steering-pytest
```

Result: 72 passed, two existing explicit deselections, six warnings, 254.47 seconds. The exclusions are PostgreSQL and the archived physics-050 rejection fixture; the new actual Over and under recording is independently accepted. No new exclusion is introduced.

## Superseded targets and retained failures

The owner's latest request supersedes the earlier deliberately wide radius and slow-turn minimums. Raw task-start tight-corner failures are retained in `original-tight-corners.log/json`. Initial current-tune checks also retain the obsolete wide-radius expectation failure (64/1), response slow/wide minimum failures (86/4) and turning wide-path minimum failures (61/12). Their logs and response/turning JSON remain in the evidence.

The sustained-circle floor now checks `3.5 + speed²/60`, including reverse, and still excludes the original tiny circles. Response and turning comparisons now require at least 20% tighter paths than actual electric-13; response additionally requires completion at least 10% sooner. Historical 100 ms onset, slip, speed-at-equal-time, symmetry, countersteer and replay bounds remain. Low-speed onset permits the requested restored authority while retaining at least 25% less response than original electric-6. The 190 and balance suites no longer assert that the deliberately changed high-speed steering reduction is unchanged, accounting for their one-check count reductions. No propulsion, braking, replay or other-car assertion is removed.

An initial direct graphical launcher was blocked by PowerShell execution policy; rerunning the existing launcher in a process with `-ExecutionPolicy Bypass` succeeds. One headless loop used a relative log path and emitted Godot's reserved `user://..` directory error. Final electric logs use absolute paths. No production code was changed for either harness issue.

`report.json` records source hashes, actual results, preserved failures and the source-scoped `checkpoint.patch`. The patch is checked in reverse against the working tree with `git -c core.autocrlf=false apply --reverse --check --ignore-space-change`. No staging or commit is performed. Concurrent Garage, model, track, Rivalry and other work is preserved.

Reload/rebuild and matching client/verifier configuration rollout remain. Owner keyboard/controller feel and physical-device acceptance remain. No physical-device attachment check or device test, APK, purchase, live mutation, deployment, merge or owner-process restart is performed.
