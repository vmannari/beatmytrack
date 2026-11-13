# Sustained electric turn radius below 40 km/h ? 2026-10-25

ETR01: The owner still rejects an unrealistically tight sustained turning radius below 40 km/h. ETR02: Change held cornering, preserve the small powered launch slide and gentle steering buildup. R01/Q01: retain deterministic replay, straight power/braking, six other cars and documented validation. The newest owner correction supersedes the old exact steering requirement from 29 km/h upward; the 40?60 km/h transition must change to avoid a steering cliff.

The cause was the existing steering-angle fade reaching full lock by 8 m/s (28.8 km/h). Slower buildup did not limit the eventual turn. Actual rejected electric-9 full-lock circles measure about 3.9 m at 20 km/h, 2.8 m at 30 and 3.3 m at 40, with ordinary feedback pedal input holding each requested speed.

Electric-10 adds an opt-in low_speed_turn_radius of 6.0 m and low_speed_turn_acceleration of 9.0 m/s squared. Through 40 km/h the sustained yaw demand is limited by the larger of that radius and speed squared divided by the cornering-acceleration limit. Steering input scales the allowed curvature, retaining wider paths for partial input. Existing powered/lift rotation shares the bound, preventing the pedal from bypassing it. Actual yaw still follows the accepted response and inertia; no heading snap or direct state clamp is added. The bound fades smoothly from 40 km/h to 16.66 m/s (59.976 km/h), then performs no arithmetic. The rounded endpoint avoids float32 boundary values executing residual blend arithmetic at nominal 60 km/h.

The earlier low-speed angle/rate curve, launch lateral-response effect, propulsion, release braking, controls, model and cameras remain. This is a sustained dry-road cornering correction, not a claim that every transient slide or collision has a fixed instantaneous path radius.

## Matched held-circle measurements

Each simulation starts once at the requested speed, holds steering, warms up for three seconds and completes a full travel-direction circle. A feedback driver uses ordinary quantized pedal input, including D/R for reverse; velocity is never reset during the measurement. Distance divided by accumulated travel-direction angle measures the actual path radius. Both the rejected simulation/resource and the corrected one are run, including exact replay of the measured inputs.

| Requested speed | Rejected electric-9 radius | Electric-10 radius |
| --- | --- | --- |
| 5 km/h | 10.42 m | 10.42 m |
| 10 km/h | 9.50 m | 9.50 m |
| 15 km/h | 6.10 m | 6.10 m |
| 20 km/h | 3.94 m | 6.00 m |
| 25 km/h | 2.94 m | 6.00 m |
| 30 km/h | 2.76 m | 7.72 m |
| 35 km/h | 2.86 m | 10.50 m |
| 39.9 km/h | 3.26 m | 13.65 m |
| 40 km/h | 3.26 m | 13.72 m |

At the 40 km/h target the old car holds 39.88?39.99 km/h and the new one 39.99?40.00. Exact speed ranges, all nine full-circle pairs, left/right symmetry and replay outcomes are in circles.json. Partial-steering and reverse checks also pass. The dedicated suite has 64 passing checks, including 135 exact high-speed single-tick states and smooth boundary checks around 40 and 60 km/h.

Shared physics is arcade-planar-0.72; EV config hash is 750a9964bffb12b2d46012b0ca7186adaa4c4a250dc06674707e5cba8ef94ca7. Both new fields are omitted from default vehicle snapshots, retaining six other car identities. The backend fixture changes only physics version and electric identity; historical recordings/rules remain. Matching client/verifier rollout is still required.

## Actual commands and checks

Pinned Godot executable: C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe. OUT is res://../docs/evidence/electric-turn-radius-2026-10-25. Native headless command: --headless --path game --log-file ABSOLUTE_TASK_LOG --script res://tests/SUITE.gd -- --evidence-root=OUT.

- test_electric_turn_radius.gd: 64 checks, zero failures (final matched-speed run in circles-final-matched.log).
- test_electric_launch_drift.gd: 111; test_electric_low_speed_steering.gd: 87; test_electric_brake_release.gd: 38; test_electric_car.gd: 60; test_electric_one_pedal.gd: 63. All pass. The 72 km/h release stop remains 0.7667 seconds / 7.5626 m.
- test_electric_power.gd: 19; test_electric_power_balance.gd: 22; test_electric_steering_response.gd: 86; test_electric_turning.gd: 61. All pass, retaining the original comparison tolerances at normal/high speeds.
- test_electric_power_laps.gd: six checks pass across three circuits times five laps, with exact replay. All three circuits have zero contacts, retained in the native log.
- test_handling.gd: 88; test_rewind.gd: 61; test_script_parse.gd: 1206. All pass. The low-speed suite retains 2400 exact ticks for each other car and four full-second exact high-speed runs.

App command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=OUT/native. Second run uses -RenderingMethod mobile -RenderingDriver vulkan and OUT/mobile-native. 60 Compatibility and 60 desktop Vulkan Mobile checks pass; desktop native captures retain actual model and controls. Manual-step hitch logs are not device performance measurements.

Race recording: pinned headless Godot --script res://tests/export_electric_power_replay.gd -- --output=OUT/canonical-race.json. Independent server reader: .tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-turn-radius-2026-10-25/verify_canonical.py. Accepted 13817 actual inputs / five laps / 115140 ms, lap ticks [2832,2746,2747,2745,2747], distinct board identity and exact six other config entries. The wider-turn tune legitimately changes this race's time from the preceding 110579 ms.

Backend command from backend/: ..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-turn-radius-pytest. 72 passed, two existing explicit deselections (PostgreSQL and archived physics-050 ghost rejection), six existing warnings. No new exclusion.

## Retained regressions and evidence corrections

The exact rejected model produces 62 checks / 17 failures in original-circles.log/json, including radius bounds at 20?40 km/h and reverse at 20. An initial proportional speed controller leaves a small steady speed error under the old tight turns; the final measurement uses an integral term to match speeds more closely without changing production code or relaxing bounds. The first curvature implementation produces one high-speed exactness failure at the float32 fade endpoint. The rounded endpoint fixes it; both failure logs remain.

Original current-source retained suites produce turning 61/1 failure, response 86/7, low-speed 87/3 and launch 111/1 after the production change. Identity guards and the old faster/tighter 43.2 km/h comparison conflict with the new contract. Version guards now require electric-10/physics0.72. Original comparison bounds remain at speeds starting 72 km/h; exact high-speed single ticks start at 60, with sustained full-second runs starting 72. The new full-circle checks directly replace the superseded tight-turn behavior below 40. Braking, speed, slip/recovery, symmetry, other-car, replay and rewind bounds are retained. No lap timeout or diagnostic driver is changed.

Two original suites have fixed historical output paths and initially rewrote the previous task's measurement JSON. Those new outputs were archived here as original-suite-*.json; restore_historical_metrics.gd reruns the exact task-start simulation/resource and archived test bodies only in isolated process memory. Its identity guard reads the reloaded script constant map to avoid the process's stale compiled physics constant; all original identity values/expectations remain. The final restoration log records 87/111 checks with zero failures and restores historical metrics. Initial restoration attempts with duplicate-resource/stale-constant identity errors remain. Production files are never swapped for this restoration. Both suites now separate immutable baseline roots from their new output roots.

Changed files and task-start hashes are in report.json; before/ retains the actual task-start sources. checkpoint.patch isolates this work from existing concurrent changes, including Storm tracks and Garage camera work. No physical-device attachment check/test, APK, purchase, live mutation, deployment, merge or owner-process restart. The running/editor/device client needs reload/rebuild; matching verifier/config rollout and owner/device radius/drift acceptance remain.
