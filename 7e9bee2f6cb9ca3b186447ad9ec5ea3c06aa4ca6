# Braking-strength electric pedal release — 2026-10-25

The owner still finds accelerator release too weak and requests a braking-like slowdown. EBR01/EBR02 replace rear-motor-only lift braking with traction-limited automatic friction/regen blending for the single-pedal electric car. Full release now requests 26 m/s² rather than 14, beginning on the first canonical tick and stopping completely. EBR03 preserves softened acceleration, quicker steering, controlled RWD power slip, 158.4 km/h cap, stopped D/R selection and no brake/handbrake pedal. EBR04 versions and independently verifies the changed canonical behavior.

| Actual flat-road release | Electric-5 / physics 0.68 | Electric-6 / physics 0.69 |
| --- | ---: | ---: |
| Initial deceleration at 72 km/h | 14.219 m/s² | 26.219 m/s² |
| 72 km/h to exact zero | 1.417 s / 14.044 m | 0.767 s / 7.563 m |
| 100 km/h to exact zero | 1.967 s / 27.025 m | 1.067 s / 14.601 m |
| 158.4 km/h to exact zero | 3.083 s / 67.068 m | 1.675 s / 36.489 m |
| Reverse 25.2 km/h to exact zero | 0.500 s / 1.708 m | 0.275 s / 0.910 m |

Stopping takes about 46% less time and distance. Actual saved touch release is sampled with zero throttle on the first tick, with no brake or handbrake command; all six tested forward/reverse speeds stop monotonically, never reverse, and hold exact zero for another five seconds. Partial release retains progressive braking. These are native game measurements, not real-car or physical-phone claims.

## Implementation and identity

The prior rear-only traction ceiling was `32 × 0.48 = 15.36 m/s²` on clean straight asphalt, before rolling/air resistance. Increasing the requested regeneration above that ceiling could not produce the intended force. Single-pedal release now uses the existing four-wheel longitudinal/cornering traction budget, like automatic blended braking. Full release requests 26 m/s², below the electric car's 32 m/s² clean-road ceiling; turning and reduced surface grip still limit the force. RWD propulsion and ordinary rear-only regeneration keep their original rear-axle limits. No new control is introduced.

`game/vehicle/vehicle_simulation.gd` changes that one-pedal-only traction gate and versions the shared simulation to `arcade-planar-0.69`. `handling_config.gd` widens the regeneration editor range to 30 without changing defaults, properties or other car hashes. `electric.tres` changes only handling version `electric-6` and regeneration 14→26. Engine force 38,000, longitudinal grip 32, cap 44 m/s and every steering field remain.

The actual old 0.68 source is reloaded only in the isolated test's memory for before/after comparisons. Powered electric state snapshots match it exactly for 1,200 variable-steering/pedal ticks in each direction. The softened launch milestones remain exactly 1.058/1.525/2.383 seconds to 72/100/144 km/h. Each of the six other cars matches every old state over 2,400 power/coast/brake/handbrake ticks. The corrected model and input source stay byte-identical. No historical asset evidence is overwritten.

The new EV hash is `d3ea4b2ab70bfaa977543de9c8e0f8dece558a796c3b9e4aadc14697937c041b`. The backend replay fixture changes only the physics version and electric vehicle entry; the six other vehicle hashes, historical rules key, track and recording stay exact. The shared physics version changes board identity even for unchanged car arithmetic; matching client/verifier rollout is required for online use. Earlier records are not rewritten.

## Actual commands and validation

Use pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. `OUT` below expands to `res://../docs/evidence/electric-brake-release-2026-10-25`.

| Arguments | Acceptance |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_brake_release.gd` | 38 checks: old-source/old-tune comparison, actual touch release, first-tick deceleration, six stop speeds/directions, exact zero hold, proportional braking, rear-ceiling reproduction, unchanged launch and exact other-car ticks. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car.gd -TestArgument --evidence-root=OUT` | 60 checks: exact replay/rewind, drive/reverse and regeneration. |
| Same output argument with `test_electric_one_pedal.gd` / `test_electric_power.gd` / `test_electric_power_balance.gd` | 63 / 19 / 22 checks. First-tick threshold strengthens to 26 m/s²; the 72 km/h stopping deadline strengthens to 0.8 s. Earlier power/steering/slip/cap bounds remain. |
| Same output argument with `test_electric_steering_response.gd` / `test_electric_turning.gd` | 86 / 61 checks, retaining earlier response/radius/time/speed/slip tolerances. |
| `-Action TestScript -ScriptPath res://tests/test_electric_power_laps.gd` | Six completion/exact-replay assertions across three circuits × five laps; zero contacts on all three. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/native` | 60 actual-App Garage/race assertions; first-release-tick braking and shortened forward/reverse stop windows strengthen earlier checks. |
| Same UI command with `-RenderingMethod mobile -RenderingDriver vulkan` and `OUT/mobile-native` | 60 actual-App assertions on desktop Vulkan Mobile, zero failures. |
| `-Action TestScript -ScriptPath res://tests/export_electric_power_replay.gd -TestArgument --output=OUT/canonical-race.json` | Actual current five-lap recording. |
| `-Action Import`, then `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Clean import; 1,167 scripts parse with zero failures. |

From `backend/`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-release-pytest
```

Result: **72 passed / two explicit deselections / six existing warnings**. The established exclusions are unavailable PostgreSQL and the archived physics-050 ghost defect. No additional exclusion is introduced. Actual output is retained in `backend.log` and the report.

From the repository root:

```powershell
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-brake-release-2026-10-25/verify_canonical.py
```

The independent server reader accepts 13,270 inputs / 110,579 ms / five laps with lap ticks `[2728,2635,2636,2636,2635]`, the new hash/version and distinct same-track board identity. Nothing is uploaded.

The first new regression interrupted on its own assumption that zero-handbrake replay frames always have four channels. The established compact encoding omits a zero fourth channel. The test now accepts that valid three-channel form and still explicitly checks zero throttle and no handbrake; all 38 checks pass. The original failure remains in `initial/packed-frame-test.log`. No production behavior or acceptance threshold was relaxed to fix the test.

[Release measurements](evidence/electric-brake-release-2026-10-25/release.json), [independent receipt](evidence/electric-brake-release-2026-10-25/canonical-verification.json) and [task report/checkpoint](evidence/electric-brake-release-2026-10-25/report.json) retain source hashes, commands and outcomes. Native captures show the real one-pedal race controls on both desktop renderers. Manual-stepping hitch diagnostics are not a performance benchmark.

Client reload, matching client/verifier rollout and owner/device braking-feel acceptance remain. No phone/tablet attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Concurrent work is preserved.
