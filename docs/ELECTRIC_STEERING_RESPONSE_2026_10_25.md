# Faster electric steering response — 2026-10-25

The owner reports that the electric car still turns too slowly. ESR01/ESR02 deliver `electric-4`: quicker steering input, faster chassis rotation and a tighter actual path, while retaining the preceding calmer rear breakaway. ESR03 preserves the stronger launch, strict one pedal, complete-stop regeneration and D/R controls.

| Actual flat-road measurement | Electric-3 | Electric-4 |
| --- | ---: | ---: |
| Saved touch actions to 95% steering lock | 83.3 ms | 41.7 ms |
| Travel-direction change after 100 ms, 86.4 km/h / 45% pedal | 2.30° | 7.95° |
| Chassis yaw reverses after opposite steering | 100 ms | 50 ms |
| Travel direction responds to opposite steering | 133.3 ms | 75 ms |
| Peak slip in the established 72 km/h-entry, one-second, 0.65-steering/full-pedal corner | 17.58° | 16.54° |
| Same corner at 45% pedal | 5.35° | 5.67° |

At full steering and 45% pedal, actual velocity-path quarter turns improve as follows. These are game measurements, not claims about real cars or device feel.

| Entry speed | Time before → after | Effective radius before → after |
| --- | --- | --- |
| 43.2 km/h | 0.658 → 0.533 s | 5.96 → 4.74 m |
| 86.4 km/h | 0.775 → 0.608 s | 12.59 → 9.82 m |
| 129.6 km/h | 1.050 → 0.867 s | 24.87 → 20.52 m |
| 172.8 km/h | 1.292 → 1.092 s | 39.01 → 33.15 m |

All twelve speed/pedal combinations finish the turn at least 12% sooner with at least 12% smaller radius than the actual preceding accepted electric-3 tune. The representative 45%-pedal cases finish 15–22% sooner. Initial travel direction responds more than twice as far in the first 100 ms across all cases, with symmetric left/right onset. Equal-time speeds stay within the retained five-percent lower bound.

`game/resources/cars/electric.tres` changes steering rate 12→28, countersteering rate 22→32, rotational inertia 1050→450, steering angle 0.70→0.82, high-speed reduction 0.40→0.25, maximum yaw 3.2→3.4, lateral response 22→30 and lateral grip 65→75. Throttle rotation falls 0.50→0.35 to keep the sharper response from exaggerating rear rotation. Existing corner-energy retention rises from 0.50 to 0.60 to reduce scrubbing in the tighter turn; it redirects a greater fraction of removed lateral energy rather than adding energy. Engine force, acceleration limits, mass, speed limits, regeneration and driven axle remain.

Simulation arithmetic and physics `arcade-planar-0.68` are unchanged. The independent verifier confirms all six other competitive car entries match task start. Electric-4's hash is `f70168e47f9d940b98b8acd84b97921ba75ef397dbd355ec7d1ddc57be84b3c7`; the backend fixture changes only that entry and retains historical rules-v22. Equal-track electric-3/electric-4 boards remain distinct. The corrected model, cameras and shared handling defaults are byte-identical to task start.

## Validation and corrections

From the repository root, use pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_steering_response.gd` | 86 checks: actual before/after touch onset, steering lock, path/time/radius, equal-time speed, symmetry, bounded slip and opposite-steering response. |
| `-Action TestScript -ScriptPath res://tests/test_electric_turning.gd -TestArgument --evidence-root=res://../docs/evidence/electric-steering-response-2026-10-25` | Existing 61 checks, zero failures after the time-comparison correction described below. |
| Same output argument with `res://tests/test_electric_power.gd` | Existing 19 checks, zero failures. All launch, moderate-slip, recovery, no-handbrake, stop/hold and other-car integrator assertions remain. Only the expected handling version and output destination change. |
| Same output argument with `res://tests/test_electric_car.gd` | Existing 60 checks, zero failures, including exact replay and rewind. |
| Same output argument with `res://tests/test_electric_one_pedal.gd` | Existing 63 checks, zero failures. Stop from 72 km/h remains 1.8 s / 17.842 m, with immediate approximately 11 m/s² regeneration and exact-zero hold. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_laps.gd` | Six completion/exact-replay assertions; three circuits × five laps. All three report zero contacts. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-steering-response-2026-10-25/native` | Actual Garage/race 59 checks, zero failures. |
| Same UI test with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-native` output | Actual Garage/race 59 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/export_electric_power_replay.gd -TestArgument --output=res://../docs/evidence/electric-steering-response-2026-10-25/canonical-race.json` | Actual electric-4 five-lap recording. |
| `-Action Import`, then `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Clean import; 1,163 scripts, zero failures. |

The initial quarter-turn regression compared exit speeds reached at different times. Three low-speed cases failed because the sharper car finished its turn sooner and therefore accelerated for less time. It now compares speed at the identical elapsed tick, retaining the same five-percent bound; the original failed measurements remain in `initial/`. This is a measurement correction, not relaxed speed tolerance. That fairer check then exposed one real full-power 86.4 km/h corner-speed failure. The final bounded-yaw, lower throttle rotation and reduced-scrub tune fixes it without changing the threshold. The new response suite also compares against the actual accepted electric-3 tune, instead of relying solely on the older oversteering baseline. Exploratory calibration output is retained and is not counted as acceptance checks.

From `backend/`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-response-pytest
```

Result: **72 passed / two explicit deselections / six existing warnings**, retained in `backend.log` and the report. The two established exclusions are unavailable PostgreSQL and the documented archived physics-050 ghost defect. No new test exclusion was added.

From the root:

```powershell
.tools\backend-secure-venv\Scripts\python.exe docs/evidence/electric-steering-response-2026-10-25/verify_canonical.py
```

The actual server reader accepts 13,103 inputs / five laps / 109,188 ms, with lap ticks `[2676,2607,2606,2607,2607]`. It confirms the electric-4 hash and distinct same-track boards without uploading or changing earlier records.

## Evidence and remaining acceptance

[Response measurements](evidence/electric-steering-response-2026-10-25/response.json), [independent replay receipt](evidence/electric-steering-response-2026-10-25/canonical-verification.json), [native race](evidence/electric-steering-response-2026-10-25/native/race.png) and [report/checkpoint](evidence/electric-steering-response-2026-10-25/report.json) retain commands, outcomes, source hashes, native views and the scoped Git-checkable patch. Existing power/turning scripts accept separate evidence destinations, so completed historical evidence is preserved.

Reloading the client, matching online verifier/configuration rollout and owner/device steering-feel acceptance remain. Desktop Mobile is the desktop Vulkan path, not a phone test. No phone/tablet attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Manual-stepping native hitch diagnostics are not a performance benchmark. Concurrent model, translation, Garage and backend work is preserved.
