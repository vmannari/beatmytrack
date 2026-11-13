# Electric driving character, with Compact as a reference — 2026-10-26

EDC01: Owner finds electric-16 unfun, while Compact feels excellent. EDC02: Owner selects **planted and punchy, with controllable power slides**. EDC03: Use Compact as the response reference without copying it or modifying Compact. EDC04/R01/Q01: Keep usable tight corners, rear-motor one-pedal identity,190km/h, canonical replay, other cars and concurrent work.

The keyboard comparison exposes a strong stop-start cycle. A shared50km/h-entry manoeuvre—accelerate, steer, briefly lift, then power out—loses29.214km/h during the electric's0.3s lift but only3.538km/h in Compact. Electric steering also filters input for158ms to95% lock, then turns the body with a38ms nominal yaw response. Its very fast30/s lateral response rapidly aligns the car again off power. The selected balance reduces that pedal discontinuity and distributes response more evenly between input, body and tyres.

## Selected electric-17 balance

| Resource field | Electric-16 | Electric-17 |
| --- | --- | --- |
| regeneration |26 |12 m/s² |
| steering_rate |6 |9/s |
| rotational_inertia |450 |600 |
| lateral_response |30 |22/s |
| launch_lateral_response_scale |0.16 |0.30 |
| power_lateral_response_scale |0.55 |0.70 |

Version changes to electric-17. These are the only seven electric resource changes. Full power remains tick-exact for2,400ticks in each direction; force/mass,190km/h cap, steering geometry, collision dimensions,40/s unwind and continuous2.5m+speed²/70 envelope remain. Body response now has about51ms nominal settling time. Useful95% lock arrives in108ms, and the car retains a finite buildup instead of Compact's33ms lock.

The resulting short-lift speed loss is14.642km/h: about half the previous electric loss, while still clearly braking on lift instead of Compact coasting. Automatic stopping is intentionally gentler:72km/h now stops in1.65s/16.368m rather than0.767s/7.563m. From190km/h it takes4.267s/111.001m rather than2.008s/52.285m. Drivers must lift earlier than with electric-16. Stops remain monotonic, exact at zero, without unintended reverse or creep; D/R, partial regeneration and no-handbrake rules remain.

## Similar usefulness, different identity

The reference is the actual default Compact profile (`original_slide.tres`, catalogue profile4), not the optional Drift+ resource. Both resources and their selection/catalogue/input sources remain byte-exact task start.

| Measured or authored characteristic | Compact | Electric-17 |
| --- | --- | --- |
| mass |1050 |1680kg |
| top speed |165.6 |190km/h |
| actual0–100km/h |2.125 |1.492s |
| useful95% steering lock |33.3 |108.3ms |
|30km/h course change after100ms |1.919° |1.539° |
|30km/h course change after200ms |9.141° |9.975° |
| shared keyboard manoeuvre peak slip |9.617° |7.727° |

The electric keeps instant rear-drive power, stronger off-power tyre response/grip, higher mass, longer wheelbase, one-pedal regeneration and its higher cap. It gives up some immediate alignment for a weighted body response and power-controlled rear movement. It does not adopt Compact's coast/brake/handbrake controls, original steering model or whole configuration. Maximum ordinary held-circle radius change versus electric-16 is only0.2694% across18measured speeds; full-range monotonicity remains. The tight-turn correction is preserved.

The readonly comparison retains lift-only, weighted and sharper-input alternatives. The initial weighted trial slides8.337° in the shared manoeuvre; adjusting the launch/power response produces the selected7.727° result. The sharper alternative is retained in the comparison rather than silently discarded. These are measured design targets, not a claim that automation establishes fun.

## Actual validation

The character regression compares Compact, actual task-start electric-16 and electric-17 under identical keyboard pulses, input phases, launches and recovery. It requires materially stronger electric launch, less violent lift, finite weighted input, useful corner response and a bounded power slide. All75checks pass.

Over and under completes five ordered diagnostic laps with zero contacts and both bridge layers. Its actual34,582inputs independently pass the server reader:288,182ms, lap ticks `[6974,6903,6901,6900,6904]`. Five production Storm circuits each complete one diagnostic lap, and three retained legacy circuits each complete five diagnostic laps with zero contacts and exact replay. Production race rules remain five laps; artificial drivers do not establish human feel or competitive performance.

Both actual App/Game runs pass75checks in Compatibility and desktop Mobile/Vulkan. Native input uses configured regeneration, exact D/R stops/holds, keyboard/controller steering and the powered-slide comparison. Native power slide is5.156°/7.439° with the aid disabled/enabled;20km/h keyboard heading after200ms is10.677°. Both desktop shutdown logs report two ObjectDB instances; this warning is retained without attributing its cause or making a memory/performance claim. No unrelated ownership fix is attempted.

| Final suites | Passing checks |
| --- | --- |
| character /consistent_handling /held_authority /corner_authority |75 /529 /53 /32 |
| launch_drift /powered_drift /low_speed_steering /190 |111 /270 /87 /54 |
| car /brake_release /one_pedal /power /power_balance |60 /38 /63 /19 /16 |
| steering_response /turn_radius /turning |86 /64 /61 |
| over_under /normal_tracks /power_laps /handling /rewind |7 /20 /6 /88 /61 |
| script_parse |1307 |

All final assertions have zero failures. Import passes. Local backend verification gives72passed, two existing explicit deselections and six warnings in131.97s. PostgreSQL and the archived physics-050 rejection fixture remain the only exclusions; the new requested-track recording is independently accepted. Physics/HandlingConfig/RouteDriver/DriverInput remain byte-exact at `arcade-planar-0.74`. All six other configuration identities remain exact. Only the EV fixture entry changes: electric-17 / `4ce920bc320196a5556c6e11407b299aac6c2078fecd8ac221e5a4a612750359`.

## Commands, changed expectations and retained findings

Evidence: `docs/evidence/electric-driving-character-2026-10-26`. Headless runs use the pinned `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe` with `--headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=res://../docs/evidence/electric-driving-character-2026-10-26`. Readonly candidate comparison uses `res://tests/probe_electric_character.gd`.

Native commands use `powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=OUT/native-compatibility','--over-and-under','--powered-drift')"`; Mobile uses `-RenderingMethod mobile -RenderingDriver vulkan` and a separate output directory. Import uses `scripts/dev.ps1 -Action Import`. Independent replay uses `.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-driving-character-2026-10-26/verify_canonical.py`.

From backend/: `..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-driving-character-pytest`.

Original-contract runs and their JSON are retained, including corner32/8, launch111/4, powered275/48, speed57/5, release38/15, one-pedal63/2, consistency530/13, car60/1, power19/3, balance18/5 and response86/13. These include old identity checks and intentionally superseded26m/s² braking, unchanged-response and fixed input-time expectations. Original stopping times and exact entire release trajectories cannot remain requirements when making lift gentler. New explicit stopping windows replace them; exact powered propulsion, zero/reverse fences and six other cars remain. The old26m/s² automatic brake-blend mechanism is retained as a separate stress fixture.

The old direct-corner test released at87° of travel regardless of body/tyre response. It is replaced by one common finite-response release estimate using current heading, yaw and unwind time. All32 original lane, timing, moving-exit,7° alignment and replay bounds remain. This is a synthetic binary-steering test policy, not runtime steering assistance. Runtime RouteDriver and player input are untouched. The old exact-braking low-speed comparison also retains its one initial failure; parameter-matching regeneration to12 proves the unchanged integrator arithmetic. Native waits cover the longer stop, while exact-stop assertions remain. New character targets supersede old input floors/heading ceilings; none of the lane, slip8°, traction95%, recovery, replay or other-car protections is removed.

Initial legacy tests wrote seven JSON results into the preceding evidence folder because of constant output paths. Those runs are retained under `original-scenarios/`. An isolated RefCounted archival runner restores the prior records using exact archived test sources/configuration without reverting production files. All102previous evidence hashes then match exactly (`evidence-restoration.json`, runner/log retained). Current output paths are isolated to this task. This harness mistake and correction are preserved rather than treating the first run as clean.

`report.json` records source hashes, actual outcomes and the source-scoped `checkpoint.patch`. Reverse check: `git -c core.autocrlf=false apply --reverse --check --ignore-space-change`. No staging/commit, unrelated restoration or Compact/other-car modification occurs.

Reload/rebuild, matching verifier configuration rollout and owner driving-feel acceptance remain. No physical-device attachment check or test, APK, purchase, live mutation, deployment, merge or owner-process restart is performed. Concurrent work is preserved.
