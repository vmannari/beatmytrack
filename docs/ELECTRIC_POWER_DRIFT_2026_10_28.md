# A little more Electric power drift — 2026-10-28

EPD01: The owner requests a little more drifting while accelerating and turning. EPD02: Retain the stronger regeneration, planted light-pedal handling, steering, useful acceleration, bounded slide and prompt recovery. EPD03: Give the tune an Electric-only identity and verify replay/other-car compatibility.

The only runtime changes are `version = "electric-20"` and `power_lateral_response_scale = 0.265` (previously 0.28) in `game/resources/cars/electric.tres`. This slightly reduces lateral momentum recovery during forward powered turns. Launch response, pedal onset, high-speed fade, yaw/steering, motor force, slide drive loss, tyres, 190 km/h cap and 20 m/s² regeneration remain exact. Shared physics stays `arcade-planar-0.75`; simulator, HandlingConfig, input and other-car resource bytes remain exact.

At 50 km/h, full steering and 65% pedal, peak slide angle increases **19.450° → 20.423° (+5.00%)**. Sliding starts **300 → 291.7 ms**, and straightening recovers in the same **183.3 ms**. Over the same 1.5-second powered turn, final speed is 72.879 versus 74.030 km/h. Across 84 speed/steering/pedal cases, maximum angle is 20.908°, recovery at most 191.7 ms, and final speed retains at least 98.425% of Electric19. Every sampled powered turn still accelerates. Both-direction straight acceleration/release/hold paths and light-pedal/released turns remain tick-exact against the actual task-start resource.

The new 416-check suite fails four intended checks against Electric19 and passes all 416 against Electric20. Four candidate response values were measured before selecting the final intermediate 0.265. The stronger 0.25/0.26 candidates would cross the retained historical 78% acceleration floor; the chosen value passes the unchanged 518-check slide suite and its original speed floor. No existing angle, speed, recovery, lane, high-speed-turn, zero-crossing or replay bound is relaxed.

Current-version assertions update in existing Electric tests. The regen regression deliberately matches the later power-response field in its preceding reference before comparing powered turns; it still preserves every braking check. The new focused suite separately requires the entire Electric19 configuration to match except version and power response, and proves that straight power, lift, hold and light-pedal turns remain exact. The prior blanket equality of that one power field is superseded by this request, not removed to hide an unrelated failure.

The local backend fixture changes only Electric's handling version and configuration hash, now `b51534ece02975f60d5fb0ced5d9225ad6946d5af13ea054d656de2530024f58`. The compatibility selection passes 35 tests with 32 PostgreSQL deselections and 161 retained SQLAlchemy warnings, including actual staged worker acceptance and tampered-path rejection. No PostgreSQL execution is claimed. Five Storm laps and a five-lap Over and under recording retain ordered gates, zero contacts and exact replay. Per-suite counts, strict independent verification and parser results are recorded in [report.json](evidence/electric-power-drift-2026-10-28/report.json).

Independent unchanged server-adapter verification accepts the 35,035-input Over and under recording at 291,952 ms, with lap ticks `[7068,6991,6991,6992,6993]`. All six other selected-car hashes and board identities remain exact at equal track identity; Electric's board identity changes. The final parser passes 1,359 scripts. All 22 selected client suites pass their assertions with no final engine diagnostics.

Actual commands from the repository root, with the exact pinned Godot 4.7.2 executable and absolute task logs:

```powershell
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/electric-power-drift-2026-10-28/probe.log' --script res://tests/probe_electric_power_increment.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/electric-power-drift-2026-10-28/baseline.log' --script res://tests/test_electric_power_increment.gd -- --evidence-root=res://../docs/evidence/electric-power-drift-2026-10-28/baseline

# Final checks use normal Windows certificate access and a workspace-owned profile.
$env:APPDATA = [System.IO.Path]::GetFullPath('build/electric-power-drift-profile')
$env:BMT_API_URL = ''
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-power-drift-2026-10-28/run_checks.py --phase=final
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-power-drift-2026-10-28/run_checks.py --phase=retained electric_brake_release electric_held_authority electric_low_speed_steering electric_power electric_power_balance
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-power-drift-2026-10-28/verify_canonical.py

# From backend/:
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_car_compatibility.py tests/test_car_compatibility_native.py tests/test_electric_car.py -q -k 'not postgres' --tb=short --basetemp ../build/electric-power-drift-pytest
```

The initial sandbox probe/baseline/first-tune logs retain the environment's certificate-store diagnostic. Final regressions run with certificate access and an isolated test profile. Historical evidence stays unchanged; every new measurement has its own destination. No production simulation or verification error handling changes.

The task-scoped review patch includes only this resource/fixture/test/documentation work and passes a Git reverse-apply check without touching the main index. Concurrent exterior rebuild, Garage, backend and editor work is preserved. Reload/rebuild the client and roll out matching backend/current Electric track contracts before online use. Owner driving-feel acceptance remains, including keyboard/controller initiation and recovery on normal corners. No physical-device attachment query or device test, APK, real authentication/purchase, owner-save mutation, live submission, deployment or owner-process restart is performed.
