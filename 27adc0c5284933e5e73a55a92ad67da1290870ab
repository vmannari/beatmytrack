# Electric power balance — 2026-10-25

The owner requests softer acceleration, stronger braking when releasing the accelerator and a slightly lower top speed. EPB01–EPB03 deliver `electric-5`; EPB04 preserves the preceding quicker steering, controlled rear breakaway, strict single pedal and D/R selection at the saved brake position.

| Actual flat-road measurement | Electric-4 | Electric-5 |
| --- | ---: | ---: |
| 0–72 km/h | 0.733 s | 1.058 s |
| 0–100 km/h | 1.017 s | 1.525 s |
| 0–144 km/h | 1.533 s | 2.383 s |
| Top speed | 172.8 km/h | 158.4 km/h |
| Immediate lift-off deceleration at 72 km/h | 11.219 m/s² | 14.219 m/s² |
| Released-pedal stop from 72 km/h | 1.800 s / 17.842 m | 1.417 s / 14.044 m |
| Established full-power corner peak slip | 16.54° | 14.34° |
| Same corner at 45% pedal | 5.67° | 4.71° |

Launch to 100 km/h takes 50% longer; the cap falls 8.3%. Lift-off stopping takes 21.3% less time and 21.3% less distance, reaching exact zero and holding without creep. These are canonical game measurements, not real-car or physical-device claims.

Only the versioned electric resource changes production behavior: engine force 60,000→38,000, longitudinal grip 46→32, regeneration 11→14 and maximum speed 48→44 m/s. Its sharper steering fields remain identical to electric-4, including steering/countersteering rates 28/32, inertia 450, angle 0.82, high-speed reduction 0.25, lateral response 30 and yaw cap 3.4. Saved touch actions still reach 95% lock in 41.7 ms; opposite-steering travel response remains 75 ms. Left/right symmetry, bounded sliding and all twelve steering cases pass.

The shared integrator, handling defaults and corrected car model are byte-identical to task start. Physics stays `arcade-planar-0.68`. The new electric configuration hash is `11d9826782c49564ee44553f4dd5e0b7a6442c0d336ebcf46c39477a05ace0dc`. All six other competitive car entries are unchanged. Only the electric entry in the existing historical replay fixture is repinned; its original rules key and other contents remain. Equal-track electric-4/electric-5 boards are distinct.

## Validation

Run the pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. `OUT` below means `res://../docs/evidence/electric-power-balance-2026-10-25`.

| Arguments | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_balance.gd` | 22 checks: actual preceding launch/stop/cap comparisons and unchanged steering fields. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power.gd -TestArgument --evidence-root=OUT` | 19 checks: balanced power, bounded RWD slip, recovery, stronger stop, no creep/handbrake and exact other-car ticks. |
| Same output argument with `test_electric_steering_response.gd` / `test_electric_turning.gd` | 86 / 61 checks: touch onset, actual direction/path/time/radius, equal-time speed, symmetry, slip and opposite steering. |
| Same output argument with `test_electric_car.gd` / `test_electric_one_pedal.gd` | 60 / 63 checks, including replay/rewind, immediate regeneration, exact stop/hold, reverse and every touch layout. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_laps.gd` | Six completion/exact-replay assertions across three circuits × five laps; zero contacts on each. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/native` | Actual Garage/race 59 checks. |
| Same UI command with `-RenderingMethod mobile -RenderingDriver vulkan` and `OUT/mobile-native` | Actual desktop Vulkan Mobile 59 checks. |
| `-Action TestScript -ScriptPath res://tests/export_electric_power_replay.gd -TestArgument --output=OUT/canonical-race.json` | Actual electric-5 five-lap recording for independent verification. |
| `-Action Import`, then `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Clean import; final rerun parses 1,165 scripts with zero failures. |

The owner's correction supersedes the earlier aggressive acceleration target and unchanged-speed-cap assertion. Power tests now assert the new balance; regeneration thresholds strengthen from 11 to 14 m/s² and the stop deadline from 1.875 to 1.5 seconds. Steering tests retain every existing percentage and slip bound, compare at the new actual top speed and give their old-steering reference the current motor/grip/regen/cap values. This isolates steering from the explicitly requested propulsion change. Dedicated balance tests compare the complete, unmodified electric-4 resource. Historical evidence is preserved using separate output paths.

From `backend/`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-balance-pytest
```

Result: **72 passed / two explicit deselections / six existing warnings**. The established exclusions remain unavailable PostgreSQL and the documented archived physics-050 ghost defect; no new exclusion is added. The outcome is retained in `backend.log` and the report.

From the repository root, run `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-power-balance-2026-10-25/verify_canonical.py`. The actual server reader accepts 13,186 inputs / five laps / 109,877 ms, with lap ticks `[2710,2619,2619,2619,2619]`, the pinned new hash and distinct same-track board identity. Nothing is uploaded.

The first whole-project parse encountered a transient closing-parenthesis error in the concurrently edited `capture_desert_rally_dust.gd:14`. The later read already contained its correction; this task does not edit that file. The initial failure and observed source remain under `initial/`, and the final rerun outcome is retained separately.

Three concurrent native runs also recorded failures to open a timestamped user log. Their assertion JSON passed. Sequential steering/turning reruns retain complete console output and pass all 86/61 checks; the original log diagnostics remain in the report. The export's actual race is independently accepted by the server reader.

## Evidence and remaining acceptance

[Measured balance](evidence/electric-power-balance-2026-10-25/balance.json), [actual replay receipt](evidence/electric-power-balance-2026-10-25/canonical-verification.json) and [report/checkpoint](evidence/electric-power-balance-2026-10-25/report.json) retain commands, results, hashes and a task-only Git-checked patch. Native screenshots retain the actual Garage and race controls on both desktop renderers. Manual-stepping hitch diagnostics are not a performance benchmark.

Client reload, matching online verifier/configuration rollout and owner/device driving-feel acceptance remain. No phone/tablet attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Concurrent work is preserved.
