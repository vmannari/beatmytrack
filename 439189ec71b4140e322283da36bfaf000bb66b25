# Electric acceleration-and-steering drift — 2026-10-26

EPD01: Owner requests some drift while accelerating and turning. EPD02: Extend the slide beyond the existing launch-only aid, retaining grip when lifting or straightening. EPD03/R01/Q01: Preserve the corrected steering, 190 km/h, braking, replay, other cars and concurrent work.

Electric-16 adds optional `power_lateral_response_scale=0.55`. Rear-drive acceleration with actual steering retains a little more lateral momentum at all forward speeds. The effect smoothly follows accelerator pressure above 0.46 and steering strength above 0.1. It shares the lower lateral-response value with the existing launch aid, rather than multiplying the two reductions. Lift/light pedal, straight wheels, reverse and the default scale of 1 retain the old arithmetic. No yaw impulse, steering-angle increase or motor-force bonus is added.

Physics becomes `arcade-planar-0.74`. HandlingConfig defaults to 1 and omits that default from its snapshot. All six other configuration hashes remain exact; each other car also passes 1,200 tick-exact comparisons against the actual task-start physics. Only the global physics identity and electric fixture entry change. Electric config hash: `0906641afb7ed6eea118584ec7002530d22cb224cdaa03167ce773ef19dd9b2a`.

Every pre-existing electric resource field except its version remains exact, including 0.78 rad lock, 6/s buildup, 40/s unwind, the continuous `2.5+speed²/70` envelope and the 0.16 launch-response scale. All 18 measured ordinary held circles match the preceding electric-15 result dictionaries exactly. Straight propulsion/release/hold remains exact for 2,400 ticks in each direction. No model, camera, binding, track or RouteDriver change is made.

## Measured drift

Actual simulation, one second of 65% steering and full accelerator, compared with the task-start physics/configuration:

| Initial speed | Previous peak slip | New peak slip |
| --- | --- | --- |
| 36 km/h | 2.356° | 4.738° |
| 72 km/h | 2.033° | 4.091° |
| 108 km/h | 1.652° | 3.352° |

The 36 launch/moving/pedal/steering cases peak at 7.326°, retaining the existing 8° ceiling. Lowest final speed relative to the previous powered case is 97.62%, within the retained 95% traction bound. Lift reduces slip, and straightening recovers below 0.1°. Left/right symmetry and exact input replay pass. Light/neutral pedal, reverse and straight-wheel cases retain exact previous snapshots.

The actual App/Game fixture adds an optional isolated `--powered-drift` review on its existing ellipse. Both runs use the actual full accelerator and steering input path. With the new aid disabled/enabled, the native 0.3-second turn peaks at 3.568°/6.891°, accelerates with zero contacts and settles after release. Separate Compatibility and desktop Mobile/Vulkan captures include `power-slide.png`; each passes75checks, retaining the original70 keyboard/controller/Garage/D/R guards. Native captures are desktop observations, not physical-device feel or performance acceptance.

Over and under completes five ordered diagnostic laps with zero contacts and both bridge layers. Its actual36,278 inputs independently pass the server reader:302,310ms, lap ticks `[7309,7245,7244,7239,7241]`. `canonical-race.json` is a byte copy of that recording. Five production Storm tracks each complete one diagnostic lap and three retained legacy circuits each complete five diagnostic laps, with zero contacts and exact replay. Production races remain five laps; artificial drivers do not certify human driving feel or every track.

## Actual checks and commands

Evidence: `docs/evidence/electric-powered-drift-2026-10-26`. Pinned engine: `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Headless suites use `--headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=res://../docs/evidence/electric-powered-drift-2026-10-26`.

| Final suites | Passing counts |
| --- | --- |
| powered_drift / consistent_handling / held_authority / corner_authority |275 /530 /53 /32 |
| launch_drift / low_speed_steering /190 /car /brake_release /one_pedal |111 /87 /57 /60 /38 /63 |
| power /power_balance /steering_response /turn_radius /turning |19 /18 /86 /64 /61 |
| over_under /normal_tracks /power_laps /handling /rewind |7 /20 /6 /88 /61 |
| script_parse |1281 |

All final suites have zero failures. Import through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` passes. Six direct task-start arithmetic/default-snapshot checks were subsequently added to the focused test and compiled/executed in its final275-check run. The 190 km/h cap and 30-second hold, 0–100 time1.4917s, release braking, exact stopped holds and original corner alignment/lane bounds remain.

Native commands use the existing `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical`, with `-RenderingMethod gl_compatibility` or `-RenderingMethod mobile -RenderingDriver vulkan`, and `-TestArgument @('--evidence-root=OUT/native-RENDERER','--over-and-under','--powered-drift')`, launched through `powershell -NoProfile -ExecutionPolicy Bypass`. The helper temporarily disables/enables the aid only in its isolated test process and restores the configured value. Owner processes and saves are not touched.

Independent replay: `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-powered-drift-2026-10-26/verify_canonical.py`. From backend/: `..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-powered-drift-pytest` gives72passed, two existing explicit deselections and six warnings in177.53s. PostgreSQL and the archived physics-050 rejection fixture remain the only exclusions; the actual new requested-track recording is independently accepted.

## Retained initial findings

The first focused269-check run has three failures at nominal pedal0.45: input quantizes to115/255, just above the initial0.45 activation threshold. Raising the threshold to0.46 preserves exact light-pedal behavior. That initial0.50-response candidate also peaks at8.107° in the recorded metrics; the final0.55 value retains the existing8° ceiling. Initial logs, JSON, resource and physics source remain in the evidence. No previous steering, traction, recovery, braking or replay assertion is relaxed.

The first native launch stops on an unavailable concurrent `header_cars_v1/compact.png` resource. A later fresh test process loads normally and passes all75 checks; the interrupted log remains. Header assets are not edited by this task. Manual-step hitch messages are not performance measurements.

Exact before sources, actual results, hashes, changed files and a task-scoped `checkpoint.patch` are retained in `report.json`. The checkpoint is checked with `git -c core.autocrlf=false apply --reverse --check --ignore-space-change`, without staging/commit or unrelated source restoration. Historical geometry comparison fixtures remain immutable; test output writes are directed to this task's evidence.

Reload/rebuild, matching client/verifier rollout and owner driving acceptance remain. No physical-device attachment check or device test, APK, purchase, live mutation, deployment, merge or owner-process restart is performed. Concurrent work is preserved.
