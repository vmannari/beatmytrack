# Electric launch, tighter turning and calmer rear grip — 2026-10-25

The owner requests faster electric acceleration, tighter turning especially at higher speeds, and less exaggerated grip/sliding after the first power tune. EP01–EP04 deliver the final `electric-3` configuration through established handling parameters. Canonical simulation arithmetic remains `arcade-planar-0.68`; the new configuration hash separates this tune's competitive records from electric-2.

| Requirement | Final behavior |
| --- | --- |
| EP01: faster acceleration | Flat-road 0–100 km/h falls from 1.892 to 1.017 seconds; 0–72 falls from 1.300 to 0.733 seconds. The 48 m/s speed cap and rear-axle traction ceiling remain. |
| EP02: calmer rear-wheel power | In the same one-second, 72 km/h entry, 0.65-steering corner, full-pedal peak slip is 17.58°, down from the initial power tune's 44.23°. At 45% pedal it is 5.35°. Lift/unwind and subsequent power recover with negligible residual slip. |
| EP03: strict one-pedal controls | No brake or handbrake action; D/R stays at the saved brake location. Release still brakes immediately at approximately 11 m/s², stops from 72 km/h in 1.8 seconds / 17.842 metres and holds exact zero. |
| EP04: tighter high-speed turns | Actual velocity-path quarter turns are at least 20% tighter across 24/36/48 m/s entry speeds and 45/65/100% pedal. Left/right paths agree. Exit speed is retained or improved; the smaller radius does not rely on extra slowing. |

These are game-physics measurements, not real-vehicle specifications or device feel acceptance. At full steering and 45% pedal:

| Entry speed | Before steering correction | Final radius | Reduction |
| --- | ---: | ---: | ---: |
| 86.4 km/h | 18.22 m | 12.59 m | 30.9% |
| 129.6 km/h | 35.29 m | 24.87 m | 29.5% |
| 172.8 km/h | 54.73 m | 39.01 m | 28.7% |

`game/resources/cars/electric.tres` raises engine force 29,000→60,000 N and longitudinal traction 28→46. Steering angle is 0.70, high-speed reduction 0.40, yaw cap 3.2, lateral grip 65 and lateral response 22. Rear grip returns to 1.05, sliding grip rises to 0.84, slip threshold returns to 0.26, throttle rotation is a modest 0.50 and throttle grip loss returns to 0.12. This removes the abrupt breakaway of the first power tune. Slide drive loss is 0.25. Mass, speed limits, regeneration and continuous front light/model retain their previous values.

`game/vehicle/handling_config.gd` only expands editor engine-force/longitudinal-grip ranges; defaults and simulation calculations are unchanged. `vehicle_catalog.gd` describes responsive steering and a controlled slide. Existing electric tests accept a separate evidence directory to preserve history. Four new scripts measure power/turning, reuse the existing five-lap helper and export a real recording. The backend fixture changes only the electric entry relative to concurrent work.

## Corrections and retained failures

The first power tune produced 44.23° slip. An initial steering experiment used angle 0.80, high-speed reduction 0.32 and lateral grip 78. Its gentle corner reached 24.48° and failed the controllability assertion; full pedal reached 62.32°. Those measurements and the failing log remain in `initial/`.

The owner then explicitly rejected exaggerated grip/sliding. This supersedes the proposal to require more than 25° full-pedal slip: the final test requires a moderate 12–24° slide, at least twice electric-2, and tightens the gentle-pedal bound from 12° to 8°. Stop, recovery, replay and other established assertions remain. The final tune also passes the previously failing gentle-pedal assertion.

A broad verifier run passed 72 checks on the initial power candidate. During final regression, concurrent localization introduced `GameFonts` and three unimported fonts. Parser/import checks failed; the server suite reported 27 failed / 45 passed / two deselected with engine-error rejection. An isolation assertion also detected independently updated forklift-3. No localization, forklift or verifier assertion was changed. A diagnostic recovery import populated the font cache, followed by normal pinned import, parser and server rerun. Initial errors/outcomes remain recorded.

## Validation

From the root, use pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Final result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_power.gd` | 19 checks, zero failures: launch, bounded slip, gentle control, recovery, stop/hold, driven axle, speed cap, ignored handbrake and exact integrator states for the six other current cars. |
| `-Action TestScript -ScriptPath res://tests/test_electric_turning.gd` | 61 checks, zero failures: actual turns at four speeds/three pedal levels, radius, speed preservation, bounded slip and symmetry. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car.gd -TestArgument --evidence-root=res://../docs/evidence/electric-power-2026-10-25` | Existing 60 checks, zero failures, including quantized replay and rewind. |
| Same output argument with `res://tests/test_electric_one_pedal.gd` | Existing 63 checks, zero failures; all touch methods/handedness, D/R and complete stop. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_laps.gd` | Six existing completion/exact-replay assertions, zero failures, three circuits × five laps. All three logs report zero contacts. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-power-2026-10-25/native` | Actual Garage/race 59 checks, zero failures. |
| Same UI command with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-native` output | 59 checks, zero failures on desktop Mobile. |
| `-Action TestScript -ScriptPath res://tests/export_electric_power_replay.gd -TestArgument --output=res://../docs/evidence/electric-power-2026-10-25/canonical-race.json` | Final real five-lap input recording. |
| `-Action Import` then `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Clean import; 1,153 scripts, zero failures. |

From `backend/`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-power-after-import-pytest
```

The final outcome is in [backend-final.log](evidence/electric-power-2026-10-25/backend-final.log) and [report.json](evidence/electric-power-2026-10-25/report.json). The two explicit exclusions are unavailable PostgreSQL and the previously documented archived physics-050 ghost defect. No exclusion was added for font failures.

From the root:

```powershell
.tools\backend-secure-venv\Scripts\python.exe docs/evidence/electric-power-2026-10-25/verify_canonical.py
```

The actual server reader accepts **13,115 inputs / five laps / 109,289 ms**, with lap ticks `[2678,2608,2609,2610,2610]`. Electric-3's hash is `866d2886bdd38f3f75865b8fc10be838ad644a6b3bd0ea06f93321823e2b3cc7`. Same-track electric-2/electric-3 boards remain distinct. The fixture retains its historical rules-v22 key and concurrent forklift-3 entry. Five other configuration hashes match task start exactly; all six other cars retain exact integrator states under sampled inputs.

## Evidence and limits

[Power](evidence/electric-power-2026-10-25/power.json), [turn paths](evidence/electric-power-2026-10-25/turning.json), [server receipt](evidence/electric-power-2026-10-25/canonical-verification.json), [native race](evidence/electric-power-2026-10-25/native/race.png) and [report/checkpoint](evidence/electric-power-2026-10-25/report.json) retain commands, sources, outcomes and native evidence. Desktop/manual-stepping hitch logs are not a frame-time benchmark. The task-only patch preserves concurrent account, Garage, localization, forklift and backend work.

Client reload, matching online configuration/verifier rollout and owner/device driving acceptance remain. Desktop Mobile is the Vulkan rendering path, not a physical-device test. No attachment/device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Earlier tune hashes and measurements remain historical evidence.
