# Super rally — 2026-11-08

> Exterior presentation in this original delivery is superseded by [the complete C3-inspired coupe revision](SUPER_RALLY_C3_2026_11_08.md). The faster-car tune and separate gameplay identity remain.

Implemented locally for the owner's request: a new **Super rally** car with handling similar to Rally and more speed. Restart/rebuild the client to use it. Owner driving-feel acceptance, tablet testing and matching service rollout remain.

## Requirements and behavior

- **SR01 — Separate car:** `super_rally` is appended to playable and historical catalogues. Existing car IDs and achievement positions retain their identities. The car is freely selectable through the existing Garage/header flows.
- **SR02 — Rally handling, more speed:** `super-rally-1` copies the complete production Original+ Rally tune, increasing engine force from 16,500 to 19,800 N and maximum speed from 46 to 55 m/s. Steering, grip, mass, brakes, handbrake, collision dimensions, surface behavior and recovery remain equal. The original Rally resource and shared simulation/configuration files are byte-exact to task start.
- **SR03 — Presentation and saves:** red factory paint distinguishes the car. It shares the approved reduced Rally chassis, both prepared quality/reference tiers, shadow geometry, lamps, livery projection and fitted parts. Paint, condition, selection, PB rules and replay identity remain separate. Existing Rally cosmetic ownership applies to its shared parts. Four new native pictures cover artwork, header, news and catalogue; all six catalogue photographs have current provenance. No external asset was introduced.
- **SR04 — Integration:** appearance admission/authorization, statistics, achievement/telemetry IDs and per-car ranking accept the new identity. The ranking selector and Circuit request retain a separate Super rally scope. No service was deployed or contacted.

Measured straight-line behavior on the pinned desktop engine:

| Metric | Rally | Super rally |
| --- | ---: | ---: |
| Top speed | 165.6 km/h | 198.0 km/h |
| 0–100 km/h | 2.125 s | 1.708 s |
| Distance after five seconds | 146.562 m | 175.340 m |

These are controlled simulation measurements, not optimal lap times or hardware performance claims. Forty-eight matched-speed coast/brake/handbrake maneuvers reproduce Rally's complete state exactly. More powered acceleration naturally changes its driven trajectory.

## Changes and checkpoint

The complete authored source list and hashes are in [source-receipt.json](evidence/super-rally-2026-11-08/source-receipt.json). The [55-file source-only patch](evidence/super-rally-2026-11-08/source-only.patch) passes `git apply --check --reverse` against the final sources; no staging or commit was performed.

The main changes are the new car resource/catalogue, an explicit presentation alias in `CarVisual`, alias-aware prepared caches and picture provenance, Rally-compatible customization/livery/audio routing, additive backend admission/ranking IDs, twelve translated descriptions and focused acceptance tests. Model masters and other canonical car resources are preserved. Generated bases, modules, Garage/header templates, pictures and build metadata were refreshed from current sources.

## Actual validation

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Every game check uses a task-owned profile with an empty backend URL. [Command receipts and logs](evidence/super-rally-2026-11-08/) record executable arguments, exit status, elapsed time and owned process IDs where applicable.

| Check | Result |
| --- | --- |
| New-car physics, separate saves, mutable materials, serialized/full/resumed replay and actual prepared base/module hits | **3,677 checks, 0 failures** |
| Existing car structural checks plus three Super rally five-lap races, zero contacts and exact full replay | **126/0** |
| Driving | **72/0** |
| Handling | **88/0** |
| Rewind | **61/0** |
| Actual App Garage selection/save/reload/artwork/local race, Compatibility | **13/0** |
| Same actual App check, desktop Mobile | **13/0** |
| Ranking UI, including separate Super rally Circuit request | **27/0** |
| Production script compilation | **552 scripts, 0 failures** |
| SQLite appearance/ranking/new-car backend suites | **30 passed; 9 PostgreSQL cases deselected** |
| Targeted backend Ruff | **Passed** |
| New descriptions | **12 valid Unicode translations** |
| Final prepared assets | **551 resource inspections, 2,267 checks, 0 failures** |
| Catalogue provenance | **6 exact native images, 156 current source hashes** |

Shared chassis resources are inspected for both identities; the inspection count does not imply duplicated meshes. The final parallel refresh records **367 stable source inputs and no changed input**. Prepared-cache hits are explicitly required by the final new-car test. [Final source receipt](evidence/super-rally-2026-11-08/final-assets-source-receipt.json), [bake/check commands](evidence/super-rally-2026-11-08/final-assets-commands.json), [prepared result](evidence/super-rally-2026-11-08/final-assets-prepared.log) and [picture result](evidence/super-rally-2026-11-08/final-assets-picture-preflight.log) are retained.

Representative commands, run from the repository root:

```powershell
python docs/evidence/super-rally-2026-11-08/run_check.py prepared-variant res://tests/test_super_rally.gd --headless -- --prepared
python docs/evidence/super-rally-2026-11-08/run_check.py final-cars res://tests/test_cars.gd --headless -- --car=super_rally
python docs/evidence/super-rally-2026-11-08/run_check.py garage-race-gl res://tests/test_super_rally_ui.gd --rendering-method gl_compatibility
python docs/evidence/super-rally-2026-11-08/run_check.py garage-race-mobile res://tests/test_super_rally_ui.gd --rendering-method mobile
python docs/evidence/super-rally-2026-11-08/final_assets.py
```

Backend checks use `.tools/backend-secure-venv/Scripts/python.exe`, `PYTHONPATH=backend`, and `pytest backend/tests/test_super_rally.py backend/tests/test_appearance_sync.py backend/tests/test_world_ranking_cars.py -q -k 'not postgres'`. Individual command receipts provide the remaining checks.

## Native captures

| View | Compatibility | Desktop Mobile |
| --- | --- | --- |
| Catalogue | [Picture](evidence/super-rally-2026-11-08/gl_compatibility/catalogue.png) | [Picture](evidence/super-rally-2026-11-08/mobile/catalogue.png) |
| Garage customization | [Picture](evidence/super-rally-2026-11-08/gl_compatibility/garage.png) | [Picture](evidence/super-rally-2026-11-08/mobile/garage.png) |
| Actual local race | [Picture](evidence/super-rally-2026-11-08/gl_compatibility/race.png) | [Picture](evidence/super-rally-2026-11-08/mobile/race.png) |

## Retained findings and limits

- The first full car run was **156/1**: the proposed 55.2 m/s cap rounded upward in float32 and failed the original strict speed-cap assertion. The authored cap is now the exactly representable 55 m/s. The assertion remains intact; the final focused run passes it and all existing structural checks.
- An initial picture bake rejected changed inputs while the tune/catalogue was being finalized. The final refresh passes its unchanged-source fence and both original preflights. Initial logs remain under `build/super-rally-assets`; final receipts are linked above.
- The broad audio suite remains **1,701/2** on Electric reverse/pause expectations. A task-start audio-source control covering the established cars reproduces both failures (**1,454/2**). No audio assertion was relaxed. The first control's renamed-node lookup artifact was corrected and its earlier log retained.
- The broad parser retains archived test/fixture errors, including obsolete App override signatures and `parking_hall_before/garage_page.gd`. Production compilation passes separately; the broad suite was not changed to hide the failures.
- A full backend invocation passes 30 tests but cannot connect to local PostgreSQL on port 55439 for nine parameterized cases. The final SQLite run explicitly excludes those unavailable cases. PostgreSQL execution and scale are unqualified.
- Sandbox certificate-store diagnostics occur during engine initialization. An initial `dev.ps1` test wrapper stalled; only the verified superseded task-owned Godot PID 35752 was stopped. Replacement pinned-engine checks finish with receipts. No owner process was stopped or restarted.
- No phone/tablet query or test, APK export/install, owner-save edit, live backend request or deployment was performed. Cold native timings are uncontrolled and make no loading/FPS claim. Concurrent work is preserved. Owner feel and coordinated client/verifier/API rollout remain acceptance work.
