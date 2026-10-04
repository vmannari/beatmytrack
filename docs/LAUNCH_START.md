# Launch start (2026-10-03)

Owner request; requirements R01/G01/G03/T01?T04/Q01. Adds start reaction to ordinary timed races for all five local vehicles. Creator practice remains immediate and unassisted.

## Behavior

Gas is sampled during the three-second countdown and reaches the existing pedal/car presentation while canonical position, velocity and race tick remain stationary. Any nonzero gas during red lights latches an early start, even if released before lights-out. Lights extinguish on the countdown boundary. First nonzero quantized gas after lights-out selects one result; releasing/repressing cannot renew assistance.

| Input | Result | Forward acceleration effect |
| --- | --- | --- |
| Any gas during red lights | Jumped start | No bonus; drive withheld until 0.6 s after lights-out |
| 0?80 ms after lights-out | Jumped start | No bonus; 50 ms drive delay from press |
| 80?180 ms | Perfect start | +12% for 0.7 s from press |
| 180?300 ms | Great start | +8% for 0.6 s from press |
| 300?450 ms | Good start | +4% for 0.4 s from press |
| 450 ms or later | Normal | No bonus |

Windows are half-open and sampled at 120 Hz (8.33 ms resolution): perfect starts at tick 10, great at 22, good at 36 and normal at 54. A short warm-yellow text cue fades away by race tick 180. Boost affects positive forward engine acceleration only, after the normal traction limit; no boost during braking/reverse/coasting, and existing top speed stays bounded. Durations expire in race ticks even if gas is released. The pre-lights penalty is an actual delay, not a time added at finish; the final time difference depends on the player's subsequent driving.

## Canonical and online contract

Physics `arcade-planar-0.50`; rules `standing-5-road-gates-v18`. Existing three/four-channel frames retain their behavior. Only frame zero may optionally carry five channels: `[steer, gas, brake, handbrake, launch_start]`, where `1` enables clean reaction evaluation and `2` identifies early countdown gas. Later fifth channels, fractional inputs and other marker values are rejected. `bmt-replay-v1` and rewind envelope v2 remain supported with this explicitly versioned input extension. Client, Python admission and standalone Godot verifier agree. The marker records observed local input, not proof of human reaction or a trusted physical timestamp.

Launch pending/result/expiry/delay/gain are canonical vehicle state and the appended snapshot field at index 21. Both client and verifier initialize the tick-zero rewind checkpoint before stepping; resuming to zero preserves launch timing and cannot append another marker. Diagnostic HandlingRecorder schema 10 records the appended state. State snapshots now have 22 fields; the contamination fixture asserts the new default launch state while retaining all old checks. Ordinary no-countdown diagnostic/legacy recordings do not acquire launch effects. Historical board rows remain pinned; current manifest transformation upgrades v17/.49 to the new versions. API and verifier must be rebuilt together before new online client acceptance. No running service was rebuilt or deployed by this task.

## Files

- `game/vehicle/launch_start.gd`, `vehicle_simulation.gd`, `vehicle_state.gd`: canonical classification and temporary drive assistance.
- `game/persistence/handling_recorder.gd`: diagnostic schema 10.
- `game/input/drive_frame.gd`, `game/core/game.gd`: countdown sampling, early latch, replay marker, restart and cue.
- `game/race/race_rules.gd`, `game/backend/{runner,backend_client}.gd`: pinned rules and replay admission/reconstruction.
- `backend/bmt_backend/{contracts,verifier}.py`, `backend/deploy/stage_verifier.py`: version upgrade, validation and complete standalone source bundle.
- `game/tests/{test_launch_start,capture_launch_start,test_checkpoint_rules,test_bridge_exit_checkpoints,test_editor_practice,test_tracks,test_kerbs,test_storm}.gd`, `backend/tests/test_verifier.py`, `backend/tests/fixtures/verified_oval.json`: windows, actual acceleration, exact replay, countdown, early penalty, rewind/reset and contract fixtures.
- `scripts/dev.ps1`: launch checks included in full validation; `backend/deploy/README.md`, development status and Phase 0 plan link this record. `docs/schemas/bmt-replay-v1.schema.json` specifies the first-frame-only extension.

## Actual verification

Commands use the pinned Godot via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.

- `-Action Import`: succeeds.
- `-Action TestScript -ScriptPath res://tests/test_launch_start.gd`: final 13,328 checks, zero failures, all five cars; JSON replay exact on every tick. Final run has no shutdown warning; an earlier run reported four leaked instances.
- `-Action TestScript -ScriptPath res://tests/capture_launch_start.gd -Graphical`: exits 0, six real desktop captures. Red-lights, Jumped, Perfect, Great and Good captures inspected. [Perfect start](evidence/launch-start-2026-10-03/launch-12.png), [held gas under red lights](evidence/launch-start-2026-10-03/red-lights-held.png).
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q`: 56 passed before the final real-launch test was added. `-k early_launch -q`: one passes; actual full-race verifier time is exactly baseline +72 ticks.
- `-Action Doctor`: succeeds; DN2103 attached. No APK export/install or physical-device driving test performed.
- Final selected backend command: `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py backend/tests/test_review_followups.py -q`: **71 passed, 13 PostgreSQL setup errors** (connection to the existing local test database timed out). Includes all 57 verifier tests with real launch/full-race integration. Rerun `backend/tests/test_review_followups.py -k "not postgres" -q`: **14 passed, 13 deselected**. No assertion failures in that selection; PostgreSQL acceptance is not claimed.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd`: final **261 scripts, zero failures**. `res://tests/test_rewind.gd`: **57 checks, zero failures**.
- Full `-Action Validate` was actually run and stopped at stale rules/snapshot expectations described below. Its full domain/UI list was completed in order through `python build/run_launch_regression.py` (each action uses `dev.ps1 -Action TestScript`). Logs are under `build/logs/Validate-31972/` and `build/launch-regression/`. All **51 full-validation script actions** now pass across these documented runs, including handling 88, checkpoints 266, bridge layers 259, bridge entry 258, bridge exit 2527, notices 281, tracks 167, practice 54, refinement 32, kerbs 31, Storm 91, app 96, records 54, camera 1332, menus 48, cars 105 and balance one. [Per-action result evidence](evidence/launch-start-2026-10-03/regression-results.json). A single final uninterrupted Validate invocation is not claimed.
- Creator refinement initially reported 32 checks/zero failures but crashed natively at shutdown (exit -1073741819); unchanged rerun exits 0 with 32 checks and a three-instance shutdown leak warning. This is recorded separately from assertion results.
- `git apply --reverse --check docs/evidence/launch-start-2026-10-03/launch-start.patch`: passes, confirming scoped changes apply to the current shared workspace.

Initial failures were corrected: test used nonexistent throttle action (changed to accelerate); versioned rules/physics fixture expectations and standalone bundle needed updating; JSON marker comparison needed integer normalization after strict numeric checks; snapshot/recorder schema fixtures needed the explicitly appended launch state; countdown gantry fixture now asserts all-red before tick 360 and lights-out at its boundary. Full regression also exposed the pre-existing Storm daytime expectation (1.20); updated it to the owner-approved Grass 1.32 documented in GRASS_CLOUD_CONTRAST.md, preserving exact weather cleanup/daylight assertions and changing no lighting code. An attempted pytest selection named nonexistent `test_runs.py`; no tests ran in that invocation.

## Remaining acceptance

Owner launch feel/tuning, touch reaction on the physical phone, pedal/cue readability on additional phone aspect ratios, Android latency/performance and rebuilt matched online services remain untested. No phone test or production acceptance is claimed. Reviewable scoped patch retained in `docs/evidence/launch-start-2026-10-03/launch-start.patch`; shared workspace changes prevent a mixed-tree commit.


## Checkpoint-style labels (owner correction, 2026-10-03)

G03/V03/Q01: replaced large outlined yellow words with checkpoint-style 26 px uppercase light text, a dark translucent angled panel, amber outline/twin trailing bars and a circular icon. Perfect/Great/Good use a check; Jumped uses the same warning mark as missed checkpoints. Existing timing/fade and canonical launch behavior retained. `game/ui/launch_notice.gd` draws the banner and only redraws when text/alpha changes; `game/core/game.gd` supplies the original Label; the capture script writes a separate evidence directory.

Actual `dev.ps1 -Action TestScript -ScriptPath res://tests/capture_launch_start.gd -Graphical` exits 0; six desktop captures saved, Perfect inspected. [Updated Perfect label](evidence/launch-start-style-2026-10-03/launch-12.png). `test_launch_start.gd` passes 13,328 checks; four shutdown instance leaks reported. Scoped `style.patch` reverse-apply check passes. No Android export/install/device test or full regression/backend rebuild performed for this presentation-only correction. Phone layout and owner visual acceptance remain.


## Success versus warning (owner correction, 2026-10-03)

G03/V03/Q01: only Jumped Start uses the amber warning badge and trailing warning bars. Perfect/Great/Good now use a soft green outline/check badge (`#79d4aa`) and omit warning bars, retaining the compact dark checkpoint-style panel and white typography. `game/ui/launch_notice.gd` and capture output path changed; launch mechanics unchanged.

Actual `dev.ps1 -Action TestScript -ScriptPath res://tests/capture_launch_start.gd -Graphical` exits 0 with six saved desktop screenshots. Perfect success and Jumped warning inspected. [Success appearance](evidence/launch-start-success-2026-10-03/launch-12.png), [warning appearance](evidence/launch-start-success-2026-10-03/launch--1.png). `git apply --reverse --check docs/evidence/launch-start-success-2026-10-03/success-style.patch` passes. No new simulation/full regression, Android export/install, physical-phone test or backend deployment; owner visual/mobile acceptance remains. Scoped patch retains this correction separately from prior work.
