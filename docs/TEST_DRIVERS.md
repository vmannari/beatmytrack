2026-10-07 follow-up: automatic development membership/backend driving and the five-track Overview supersede the manual test-rival switch and older Overview guidance below. See [current behavior and actual verification](RIVALRY_HUB.md).

# Artificial test drivers — 2026-10-04

PC Development logout follow-up: session renewal could reuse an obsolete credential after another client restored the same saved session. The client now coordinates renewal and uses the latest saved credential. Canonical rivalry races with Test Rivals ON pass expiry, same-process and separate-process restoration regressions while retaining identity. See [repair, actual verification and restart instructions](RIVALRY_SESSION_FIX.md). No test-driver population or server authentication rule changed in this repair.

The owner explicitly approved implementing development test drivers for Weekly Rivalry. They drive the unchanged canonical car simulation, record normal quantized inputs, upload with server-issued tickets and obtain times, PBs, points and ghosts through the normal verification worker. No AI service, fabricated completion time, special physics, teleport or checkpoint bypass is used.

| Requirement | Behavior |
|---|---|
| TD01 / B01–B07 | Persistent operator-created identities have a server-owned `is_test_driver` flag. Profiles pin `test-driver-1`, seed, skill, consistency, aggression, activity, preferred UTC hour, learning and five surface strengths. Repeating a fleet request returns the same profiles. Changing its parameters requires a new seed. |
| TD02 / T01–T04 | The offline controller changes steering, throttle and braking only. It uses correlated form variation, occasional hesitation, different surface pace and diminishing learning across attempts. A missed gate causes a physical return; stalled drives record a noncompletion. All five laps and the ordinary car/build/checkpoint contracts apply. |
| TD03 / WR03–WR07 | `fill` creates an explicitly marked test rivalry with 14 total drivers by default, including the target human. The other 13 profiles have a narrow skill range. Available verified human PBs calibrate the controller per circuit by actually driving; an optional JSON reference overrides them. Unreachable target pace is reported and retained as calibration error. |
| TD04 / WR04 | `fleet` creates 150 profiles across skill levels by default. Three shared, isolated history boards receive normal verified uploads first. Then each profile uses the existing percentile matcher with random group assignment and five random eligible tracks. Declared profile skill never substitutes for verified matching history. Insufficient successful history retains the placement pool. |
| TD05 / Q01 | A durable operator scheduler spreads 1–5 attempts per track through each UTC week around each profile's preferred hour. Quiet drivers can leave tracks unplayed. Later attempts can improve, tie or lose to the PB; points still use best performance only. Atomic plan writes, cached recordings, stable HTTP idempotency keys, bounded retries and an OS file lock support restart and prevent concurrent plan writers. |
| TD06 / WR05 | Test drivers cannot enter normal rivalries, request normal race tickets or rate tracks. Test boards have separate IDs and are unavailable through public leaderboard routes. Normal public populations, matching and distinct-finisher eligibility exclude test identities and test boards, including human finishes on those boards. Official provenance is unchanged. |
| TD07 / V03–V05 | The development menu exposes **TEST RIVALS: OFF / ON** only when the server advertises the capability. Test championships show a permanent notice and driver rows have a fixed **TEST** badge that remains visible when names are clipped. Switching population/account fences old snapshots and tickets. An unranked human sees a first-finish prompt instead of a points gap to the last driver. |

## Run on the local PC backend

The feature is off by default. Migration `0012_test_drivers` is required in addition to the existing rivalry migration. `BMT_TEST_DRIVERS_ENABLED=true` is valid only with `BMT_ENVIRONMENT=development` and explicitly enabled development authentication. The operator API also requires the private development key. Disabling the feature rejects existing test-driver login, access and refresh sessions, hides the selector and rejects queued test finalization.

Use the pinned `scripts/dev.ps1` entry point from the repository root:

```powershell
# Build/migrate/restart the isolated local PC API and worker, enabling test drivers.
./scripts/dev.ps1 -Action BackendStart -TestDrivers

# Create a 14-driver field for the fixed developer account. First attempts are due now.
./scripts/dev.ps1 -Action BackendDriversFill -DriverPlan build/rivalry-drivers.json -DriverSeed 27 -InstantDrivers

# Generate/upload due races and poll verification. Stop with Ctrl+C; this plan resumes.
./scripts/dev.ps1 -Action BackendDriversWatch -DriverPlan build/rivalry-drivers.json
```

Reopen the game's account menu, choose Development, open the trophy in Race and switch **TEST RIVALS: ON**. The test field and normal weekly membership remain separate. The watch process must run for later scheduled attempts to arrive. `BackendDriversTick` does one bounded pass. The server worker must also be running; pending uploads award no points.

For the larger field, use a different seed and plan:

```powershell
./scripts/dev.ps1 -Action BackendDriversFleet -DriverPlan build/driver-fleet.json -DriverSeed 88 -DriverCount 150 -InstantDrivers
./scripts/dev.ps1 -Action BackendDriversWatch -DriverPlan build/driver-fleet.json
```

The initial 150-driver history requires 450 genuine races and verifications. It is deliberately bounded work spread across scheduler passes, not an instant leaderboard insertion. This fleet exercises matching independently of the focused fill fixture. Fleet-created cohorts do not automatically insert a human; normal test joining uses that human's available verified test history or an honest placement group.

Advanced CLI options are available through `.tools/backend-venv/Scripts/python.exe -m bmt_backend.test_population_tool --help`: HTTPS/loopback API URL, vehicle, target development subject, pinned engine/project, pass size/interval and `--pace-reference`. That reference maps immutable `version_id` to a verified five-lap `time_ticks` value. All five current vehicles use their ordinary server configurations. The compact was the vehicle exercised in this task.

Use a new state path for a new week. Profiles can persist with the same seed and parameters, while attempts and memberships have distinct week keys. Existing ended plans expire unused jobs and continue polling already submitted results. Plans and recording caches contain no authentication keys/tokens. Never publish the private `.tools/bmt-pc.env` file.

The focused `fill` endpoint is an operator fixture: it explicitly inserts chosen profiles into the target test group. The 150-driver flow is the path for exercising automatic skill matching. A controller's absolute skill range is a prototype; calibration reports a mismatch above 5% and cannot guarantee elite human pace on every complex circuit.

## Contracts and changed files

- Backend identity/configuration/gates: `config.py`, `identity_models.py`, `auth.py`, `security.py`, `app.py`, `test_population.py`, `test_driver_models.py`, `test_drivers.py` and `migrations/versions/0012_test_drivers.py`, with the migration environment import.
- Competition isolation: `rivalry.py`, `rivalry_models.py`, `runs.py`, `tracks.py` and `worker.py`.
- Offline generation and scheduling: `backend/bmt_backend/test_driver_generator.py`, `test_population_tool.py`, `game/input/profiled_route_driver.gd`, `game/backend/generate_test_driver.gd`, `backend/deploy/stage_verifier.py`, local Compose/PC launcher and `scripts/dev.ps1`.
- Client presentation: `game/backend/weekly_rivalry_client.gd`, `game/race/weekly_rivalry.gd`, `game/ui/weekly_rivalry_page.gd` and the small integration in `game/core/app.gd`. Native HTTP regression also exposed a stale neighbor page in menu cleanup; a validity check prevents calling `hide()` on a freed page.
- Tests/contracts: `backend/tests/test_test_drivers.py`, `test_test_drivers_integration.py`, `fixtures/test_driver_profile_v1.json`, `game/tests/test_test_driver_menu.gd`, [profile schema](schemas/test-driver-profile-v1.schema.json) and optional test markers in the [weekly snapshot schema](schemas/weekly-rivalry-v1.schema.json).
- Documentation/evidence: this file, rivalry/deployment notes, AGENTS/status/plan entries and [scoped Git checkpoint](evidence/test-drivers-2026-10-04/test-drivers.patch). Existing unrelated work is preserved; no mixed-tree commit was made.

The hidden development API supplies fleet registration/listing, eligible tracks and a member-authorized fixture fill. Normal race ticket requests and rivalry joins accept an optional `test_population` flag, default false. Test membership/build hashes and board manifests include that discriminator. Rivalry snapshots/rows carry `test_population` / `is_test_driver`. Profiles are immutable within a versioned fleet.

## Actual verification

Python used `.tools/backend-venv/Scripts/python.exe`; Godot used exact **4.7.2 stable ed1daf0bf** through `scripts/dev.ps1`, or the backend adapter's exact-version check. Actual commands and outcomes:

- `pytest backend/tests/test_test_drivers.py -q --tb=short --show-capture=no`: **11 passed**, including 150 persistent profiles, observed skill-band matching, gates/session disabling, isolation, idempotent fills/uploads, scheduler crash recovery, file locking, calibration and the versioned profile fixture.
- `pytest backend/tests/test_test_drivers_integration.py -q -s ...`: profile determinism/variation and three distinct skill levels each produced canonically verified five-lap races. The initial full-field assertion incorrectly equated fractional ghost finish with an integer final tick; the corrected field test passed on rerun in 285.68 seconds. It drove and verified **61 races for 13 artificial rivals**, with a 14th human entrant, at least ten distinct times on a circuit, real derived ghosts and **zero public leaderboard population**. Summary/data: [verification summary](evidence/test-drivers-2026-10-04/verification-summary.json), [verified field](evidence/test-drivers-2026-10-04/verified-field.json).
- `pytest backend/tests/test_test_drivers.py backend/tests/test_domains.py backend/tests/test_auth.py backend/tests/test_maintenance.py backend/tests/test_rivalry.py backend/tests/test_rivalry_concurrency.py -q -k 'not postgres' ...`: **74 passed**, one recorded-practice verifier failed under the filesystem sandbox. That same publishing test passed outside the sandbox. Later profile-lock/calibration/golden additions are covered by the final 11-test run above.
- `pytest backend/tests/test_rivalry_http.py -q ...`: native rivalry flow passed after fixing the freed-page cleanup; **25 native checks, zero failures**, no script errors. The earlier failed run is retained in the work log description above.
- `pytest backend/tests/test_verifier.py -q -k standalone ...`: standalone package verification passes with the new offline files included. The HTTP service runner still exposes no generation operation.
- `TestScript res://tests/test_test_driver_menu.gd -Graphical`: **419 checks, zero failures**; twelve inspected captures across Overview/Tracks/Detail/Standings at 1280×720, 960×540 and 1600×720. A first harness run leaked an orphaned client node; ownership was fixed and the final command exits cleanly. [Compact standings](evidence/test-drivers-2026-10-04/standings-960x540.png), [duel detail](evidence/test-drivers-2026-10-04/detail-1280x720.png).
- Existing rivalry UI: **791 checks, zero failures**. App regression: **96 checks, zero failures**. Full script parse: **280 scripts, zero failures**. Ruff passes for the new Python tools/tests.
- Offline probes completed all five laps on eight existing official circuits: Dusty, Ringroad, Over and under, Slippery, Knot, Easy night, Stormy slalom and Ajorata. Those probes used ordinary compact handling and produced varied hesitations; [actual ticks](evidence/test-drivers-2026-10-04/official-circuit-probe.json). They are completion probes, separate from the full HTTP verification fixture.

Godot/ADB needed Windows certificate/user-directory access outside the filesystem sandbox. Initial denied certificate reads and the first ADB-directory error were corrected by running the same authorized checks with normal desktop access. No automatic approval rejection occurred.

Doctor detects the physical **DN2103** and an emulator. **No test-driver phone export, installation or device driving test was performed.** The implementation verification above used disposable services; the subsequent authorized PC rollout is recorded below. PostgreSQL concurrency, NAS rollout, human visual acceptance, long-lived weekly scheduling, throughput for a fully verified 150-driver seed and pace calibration against real player records remain acceptance checks. No canonical physics/rules change was made, so a full physics regression/Android build was not required for this slice.

## Local PC rollout (2026-10-04)

TD01–TD07 / WR03–WR07 / B01–B07 / Q01: the owner authorized enabling the existing local development instance. `BackendStart -TestDrivers` now persists the opt-in in the private local configuration and explicitly forwards the nonsecret flag into WSL. Windows process environment alone did not reliably reach Compose. Before migration, the launcher builds the pinned verifier image, starts/checks the database, stops the PC API/worker writers and saves a PostgreSQL custom dump plus an object archive. Completed backups have SHA-256 checksums and a completion marker. A failed backup/migration leaves writers stopped for inspection; it does not proceed to startup. Only the isolated `bmt-pc-dev` Compose project is targeted.

Actual commands used the pinned `scripts/dev.ps1` entry point:

```powershell
./scripts/dev.ps1 -Action BackendStart -TestDrivers
./scripts/dev.ps1 -Action BackendDriversFill -DriverPlan build/rivalry-drivers-live-2026-10-04.json -DriverSeed 27 -InstantDrivers
./scripts/dev.ps1 -Action BackendDriversWatch -DriverPlan build/rivalry-drivers-live-2026-10-04.json
./scripts/dev.ps1 -Action TestScript -Script res://tests/test_test_driver_live.gd -Graphical
./scripts/dev.ps1 -Action Doctor
```

The live client check requires explicit `BMT_API_URL=http://127.0.0.1:18181`, the private key in `BMT_DEV_AUTH_KEY` and optional `BMT_CAPTURE_CLOUD`. Credentials are read locally, never printed or placed in process arguments. It authenticates the fixed developer account with isolated client storage, reads the actual field, downloads a derived rival ghost, captures menus and requests one race ticket. It does not submit a human time or alter membership.

Actual outcomes:

- Readiness advanced from `0011_weekly_rivalry` to **`0012_test_drivers`**. Live bootstrap advertises the test capability. API/worker verifier manifests match; five laps, rules v18 and physics 0.50 remain pinned. Both services are healthy.
- Backup `build/pc-backups/20261004T143115008964Z` is complete. Both checksums pass, PostgreSQL can read its archive and the object tar contains 80 regular files. The original two ordinary players and 27 tracks remain present.
- The developer's Week 40 compact championship has **14 entrants: one human and 13 test drivers**, on Over and under, Curvy, My way, Spiral and Knit. **61 initial races were verified**, none rejected or failed; each circuit has 11–13 distinct verified rival times. Quiet profiles leave some circuits unplayed. There are 86 later scheduled attempts at the recorded checkpoint.
- Aggregate live PostgreSQL checks show **zero** test-driver PBs on public boards, test-driver ratings or test-driver memberships in normal groups. Normal populations remain separate.
- `pytest backend/tests/test_pc_test_driver_rollout.py backend/tests/test_test_drivers.py -q --tb=short --show-capture=no`: **14 passed**. Following the stopped/new-database ordering correction, the three rollout tests also pass independently. Ruff passes. The mocked launcher test covers database startup order; a fresh empty PC instance was not manually created.
- `TestScript res://tests/test_test_driver_live.gd -Graphical`: **26 checks, zero failures** on both actual runs. Eight refreshed screenshots at 1280×720 and 960×540 were inspected. [Live overview](evidence/test-driver-rollout-2026-10-04/live-overview-1280x720.png), [compact duel](evidence/test-driver-rollout-2026-10-04/live-detail-960x540.png), [tracks](evidence/test-driver-rollout-2026-10-04/live-tracks-1280x720.png), [aggregate evidence](evidence/test-driver-rollout-2026-10-04/rollout-summary.json).

The watch process was moved to a hidden background process after its initial jobs completed, preserving the same atomic plan. Its launcher PID/start time and log locations are in `build/rivalry-drivers-live-2026-10-04-watch.json`; output goes to the adjacent `-watch.log` / `-watch-error.log`. It continues on this PC until this plan finishes. This is a development operator process, with no automatic Windows startup or next-week plan creation. After a reboot, resume with `BackendDriversWatch` and this plan. The OS plan lock prevents duplicate writers. For the next UTC week, create a new dated plan with the same seed/parameters and run its watch process.

To stop this specific background scheduler from PowerShell, select only Python processes whose command lines contain both its module and this exact plan name:

```powershell
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" |
    Where-Object {
        $_.CommandLine -like '*bmt_backend.test_population_tool watch*' -and
        $_.CommandLine -like '*rivalry-drivers-live-2026-10-04.json*'
    } | ForEach-Object { Stop-Process -Id $_.ProcessId }
```

Pace remains a controller prototype. Real developer PB calibration on two selected circuits reported closest neutral five-lap times **69% and 53% slower** than those PBs, even at the allowed pace ceiling. The tool retained actual driven times. This populated fixture exercises results, points, ghosts and scheduled variation; human-level pace matching on these complex circuits still needs controller improvement. The 150-driver verified-history flow was not run against this live service.

Changed source files in this rollout: `backend/deploy/pc_development.py`, `backend/tests/test_pc_test_driver_rollout.py`, `game/tests/test_test_driver_live.gd` and its Godot UID. Documentation/status and [rollout-only Git patch](evidence/test-driver-rollout-2026-10-04/test-driver-rollout.patch) record this follow-up separately from the earlier feature implementation. No mixed-workspace commit was made. The initial sandbox CIM query was denied; the same narrowly scoped process check succeeded with normal desktop access. No automatic approval rejection occurred.

Doctor currently lists **DN2103 and emulator-5554**. **No phone/emulator driving test, APK export or installation was performed for this rollout.** NAS/production deployment, a restored-service rehearsal, multi-week unattended scheduling, 150-driver throughput, PostgreSQL concurrency stress and human visual/pace acceptance remain unperformed. The live migration and aggregate isolation checks above were performed on PostgreSQL.


## Google Cloud faster population (2026-10-06)

The owner-requested retained-cloud rollout, faster controller, compact 200-driver/all-27-track history plan and labeled private histograms are recorded in [Cloud test drivers](CLOUD_TEST_DRIVERS_2026_10_06.md). The 5,400-finish population is still running; consult its authoritative progress report. Earlier local pace limitations above are historical, not proof that the final controller is human-calibrated on every track.


## Predictive follow-up ? 2026-10-07

New local generation now uses cached constrained trajectories and bounded Frenet LTV MPC. The final corpus finishes 27/27 verified five-lap races, with median 21.1% improvement; four circuits remain slower. Old committed uploads can recover after a controller upgrade without regenerating their inputs. Actual architecture, tests, telemetry, cache timings and limitations are in [Predictive test drivers](PREDICTIVE_TEST_DRIVERS.md). This task has not rolled the new controller into the active cloud worker.


## Further pace improvement - 2026-10-08

The owner-requested follow-up improves the v4 neutral-profile benchmark by 10.1% on average, with all 27 circuits faster and independently verified. Controller5/trajectory3/MPC2 use time-aware geometry, exact steering/shared traction and standing/flying qualification. Recorded contacts rise slightly from5 to8. See [Trajectory pace follow-up](TRAJECTORY_PACE_2026_10_08.md) for actual tests, evidence, scoped changes and rollout/device limits.
