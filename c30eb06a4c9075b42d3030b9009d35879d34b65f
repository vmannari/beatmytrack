# Calmer electric steering at very low speed — 2026-10-25

The owner accepts higher-speed turning and rejects the electric car's overly fast turning at very low speed. ELS01 softens parking-speed steering; ELS02 preserves accepted normal/high-speed response; ELS03 preserves softened acceleration, strong release braking, RWD, 158.4 km/h cap and one-pedal/D/R behavior. ELS04 versions and independently verifies the competitive change.

Electric-7 adds an opt-in steering-angle scale of 0.60 at speeds up to 2 m/s (7.2 km/h), smoothly rising to 1.0 at 8 m/s (28.8 km/h). The curve uses total travel speed in both directions. It reduces wheel angle instead of delaying input; the earlier fast input response and countersteering remain. Above the fade, the new simulation branch performs no steering multiplication, retaining the old arithmetic exactly.

Actual touch input, measured after 0.2 seconds with full steering and a light 25% accelerator:

| Entry speed | Old travel-direction change | New change | Reduction |
| --- | ---: | ---: | ---: |
| 3.6 km/h | 3.019° | 1.548° | 48.7% |
| 10.8 km/h | 8.643° | 4.736° | 45.2% |
| 18.0 km/h | 13.889° | 10.245° | 26.2% |
| 25.2 km/h | 18.772° | 17.982° | 4.2% |

The new 63-check regression also covers 35% and 65% steering, forward/reverse and exact left/right symmetry. All 135 high-speed single-tick cases match the actual accepted physics0.69/electric-6 source exactly, including sideways states and released/partial/full accelerator. Four additional full-second variable-steering runs at 43.2/86.4/129.6/158.4 km/h match every state. Straight launch and released-pedal stopping match every tick through the low-speed fade. Each of the six other cars, including kart-5, matches all 2,400 sampled power/coast/brake/handbrake ticks.

The strong 72 km/h release stop remains exactly 0.767 seconds / 7.563 metres, with immediate 26.219 m/s² braking and exact-zero hold. Launch to 100 km/h remains 1.525 seconds. Existing normal/high-speed response86, turning61, power19 and balance22 assertions retain their tolerances.

## Implementation and identity

`HandlingConfig.low_speed_steering_scale` defaults to 1.0, which is omitted from configuration snapshots so other car hashes remain unchanged. `VehicleSimulation` applies the curve only below 8 m/s and when the scale is less than 1. The shared physics version becomes `arcade-planar-0.70`. The electric resource changes only its version to `electric-7` and adds `low_speed_steering_scale = 0.60`; every previous power/braking/steering field remains.

The corrected electric model, car presentation, driver input and kart-5 resource remain byte-identical to task start. The new EV hash is `7d10eaf9039220940f398ae9145dc141c08cd79b5086a00db3281afc4045cc38`. The backend replay fixture changes only its physics version and electric entry; all six other entries, including kart-5, historical rules key, track and recording remain. The shared physics version changes competitive board identity even for cars whose arithmetic remains exact. Matching client/verifier rollout is required; earlier records are not rewritten.

Expected versions in existing EV tests follow the new tune. The earlier release suite's exact low-speed powered-turn comparison is deliberately superseded by this owner request: it now retains exact straight power in both directions, while the new suite proves the intentionally changed low-speed turns and exact accepted high-speed turns. No braking, grip, high-speed response or speed-cap threshold is weakened. Release tests now accept a separate evidence root, preserving completed historical evidence.

## Actual validation

Run pinned Godot 4.7.2 using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. `OUT` below expands to `res://../docs/evidence/electric-low-speed-steering-2026-10-25`.

| Arguments | Actual checks |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_low_speed_steering.gd` | 63: low-speed touch response, forward/reverse/symmetry, 135 exact high-speed cases, four full-second exact high-speed runs, unchanged straight power/braking and six-car exact comparison. |
| `-Action TestScript -ScriptPath res://tests/test_electric_brake_release.gd -TestArgument --evidence-root=OUT` | 38: immediate braking, six stop speeds/directions, monotonic exact zero hold, proportional release, rear-ceiling reproduction and exact straight acceleration. |
| Same evidence argument with `test_electric_car.gd` / `test_electric_one_pedal.gd` | 60 / 63, including exact replay/rewind, touch layouts, strong released-pedal stopping and D/R. |
| Same evidence argument with `test_electric_power.gd` / `test_electric_power_balance.gd` / `test_electric_steering_response.gd` / `test_electric_turning.gd` | 19 / 22 / 86 / 61, retaining earlier normal-speed power/steering/grip bounds. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_laps.gd` | Six completion/exact-replay checks across three circuits × five laps; zero contacts on every circuit. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/native` | 60 actual-App Garage/race assertions. |
| Same UI command with `-RenderingMethod mobile -RenderingDriver vulkan`, using `OUT/mobile-native` | 60 actual-App checks on desktop Vulkan Mobile. |
| `-Action TestScript -ScriptPath res://tests/export_electric_power_replay.gd -TestArgument --output=OUT/canonical-race.json` | Actual current five-lap recording for independent verification. |
| `-Action Import`, then `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Clean import; 1,172 scripts parse with zero failures. |

From `backend/`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-low-speed-pytest
```

Result: **72 passed / two explicit deselections / six existing warnings**, retained in `backend.log`. The existing explicit exclusions remain unavailable PostgreSQL and the archived physics-050 ghost defect; no new exclusion is added.

From the root, `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-low-speed-steering-2026-10-25/verify_canonical.py` independently accepts 13,270 inputs / five laps / 110,579 ms, with lap ticks `[2728,2635,2636,2636,2635]`, the new hash/version and distinct board identity. This conservative race's time remains unchanged; the new suite measures the low-speed correction separately. Nothing is uploaded.

[Low-speed measurements](evidence/electric-low-speed-steering-2026-10-25/low-speed.json), [independent receipt](evidence/electric-low-speed-steering-2026-10-25/canonical-verification.json) and [task report/checkpoint](evidence/electric-low-speed-steering-2026-10-25/report.json) retain actual sources, commands, results, hashes and the scoped Git-checked patch. Native captures retain the real controls and model. Manual-stepping native hitch diagnostics are not a performance benchmark.

Client reload, matching client/verifier rollout and owner/device steering-feel acceptance remain. No phone/tablet attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Concurrent work is preserved.
