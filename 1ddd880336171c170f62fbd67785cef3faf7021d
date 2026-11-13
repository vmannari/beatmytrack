# Stronger Electric lift-off regeneration — 2026-10-27

The owner requests faster slowing when releasing the Electric's accelerator. ERG01 increases the authored regeneration from 15 to 20 m/s². ERG02 gives this car-only tune the handling identity `electric-19`, retaining shared physics `arcade-planar-0.75` and the six other cars' identities. ERG03 verifies stopping, progressive pedal control, D/R, stationary hold, powered handling, replay and backend compatibility.

Only two runtime values change in `game/resources/cars/electric.tres`: version and regeneration. The shared simulator, HandlingConfig and input sources stay byte-exact. Acceleration, 190 km/h limit, steering and powered slide settings remain exact. Existing one-pedal braking continues to blend automatic friction braking with regeneration; the requested game deceleration is not a claim about real electric vehicles.

| Lift from | Electric-18 stop time / distance | Electric-19 stop time / distance |
| --- | --- | --- |
| 25.2 km/h, D or R | 0.467 s / 1.593 m | 0.350 s / 1.190 m |
| 72 km/h | 1.325 s / 13.112 m | 1.000 s / 9.839 m |
| 100 km/h | 1.833 s / 25.241 m | 1.383 s / 18.969 m |
| 190 km/h | 3.433 s / 89.497 m | 2.592 s / 67.636 m |

At 72 km/h the first released-pedal tick decelerates at 20.219 m/s² including resistance. Stopping distance decreases by about 25%. All sampled forward/reverse release cases slow monotonically, reach exact zero and hold without creep. All 62 quantized pedal positions below the neutral point progress smoothly. Powered turning trajectories in both directions stay tick-exact against the task-start tune for 2,400 ticks each.

The local canonical fixture changes only Electric's handling version and hash (`4a6003cae32137af7d3e64b714fa89d7be290259d78262f5749b0dac579dd4f0`). Independent server-adapter replay verification accepts five ordered Over and under laps: 35,034 inputs, 291,944 ms, lap ticks `[7065,6991,6994,6993,6991]`, zero contacts and both bridge levels. With equal track identity, all six other selected-car board identities remain exact and Electric's board changes.

The focused task-start run has 151 checks / eight expected failures before the tune; the final test adds an explicit first-tick force check and has 152 / zero. Retained suites cover one-pedal63, brake release38, top-speed53, car60, character74, slide518, power19, balance16, powered drift269, launch111, held authority53, low-speed87, response86, turning61, radius64, direct corners32, consistent handling529, normal tracks20, handling88, rewind61 and five-lap bridge7. Full receipts, diagnostics and final parser/backend outcomes are in [report.json](evidence/electric-regen-2026-10-27/report.json).

The final parser checks 1,353 scripts with no failures. The local backend selection passes 104 tests, including both staged native-worker acceptance and tampered-path rejection, with 33 explicit deselections and 161 warnings. PostgreSQL cases and the historical Over and under contract fixture are deselected; no PostgreSQL execution is claimed. The final focused, parser, car and rewind reruns have no engine errors. Earlier sandbox runs retain the certificate diagnostic.

The stopping windows intentionally change to 0.95–1.05 s / 9.5–10.2 m from 72 km/h and 2.5–2.7 s / 65–70 m from 190. Historical lift-pulse and stopping-ratio expectations change to reflect the owner's stronger-regen request. No zero-crossing, hold, powered handling, exact replay or other-car invariant is removed. Existing tests update current Electric version assertions and expected regeneration/stopping values; the slide suite now respects its inherited evidence output override instead of overwriting historical evidence.

Actual commands (repository root except pytest):

```powershell
# The normal entry point was attempted first; sandbox user:// log access failed.
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_regen.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-regen-2026-10-27/baseline'

# The runner uses the exact pinned Godot 4.7.2 executable with absolute task logs.
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-regen-2026-10-27/run_checks.py
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-regen-2026-10-27/run_checks.py electric_over_under
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-regen-2026-10-27/verify_canonical.py

# The final reruns used Windows certificate-store access and this separate profile.
$env:APPDATA = [System.IO.Path]::GetFullPath('build/electric-regen-profile')
$env:BMT_API_URL = ''
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-regen-2026-10-27/run_checks.py --phase=final electric_regen electric_one_pedal electric_car rewind
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-regen-2026-10-27/run_checks.py --phase=accepted electric_regen script_parse

# From backend/, repeated with certificate-store access and a separate basetemp:
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py tests/test_car_compatibility.py tests/test_car_compatibility_native.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-regen-pytest-unsandboxed
```

Initial findings remain recorded. The sandbox backend run reports 28 failures / 76 passes / 33 deselections because the strict verifier rejects Godot's certificate-store errors. Independent verification succeeds with normal certificate-store access; production error handling is unchanged. The first rewind run has ten failures and a denied cache write; all original 61 assertions pass with a workspace-owned profile and normal certificate access. A first one-pedal test edit accidentally changed its lower tick bound to 200; the retained failed run exposed this and the corrected explicit 114–126 tick range passes. Early focused-test shutdown resource warnings disappear after preloading NativeTrack in the test harness. A concurrent coachwork array-type error appeared in the first car suite; the concurrent author corrected that source, and the identical suite passes without any coachwork change by this task. The development wrapper regenerated build metadata; that and other concurrent work are excluded from the task checkpoint.

Review scope is the resource, local fixture, Electric regression tests and this task's evidence/documentation. The task-only patch is checked against scoped before/after files; no main-index staging or commit is performed.

Reload/rebuild the client to use Electric19. A matching backend rollout and current Electric track contracts are required before online use of the tune; no rollout is performed here. Owner driving-feel and physical-device acceptance remain. No physical-device attachment query or device test, APK, live submission, real authentication/purchase, owner-save mutation, owner-process restart or deployment is performed.
