# Sharp road joins and checkpoints — 2026-09-30

Requirements: R01/R03/R07/G01/T01–T04/V03/Q01. Owner reported a missed checkpoint while the whole car remained on the road at a steep straight-piece join.

## Correction

Rules `standing-5-road-gates-v13` use the connected physical road chain to find sharp corners. The automatically resampled racing route can split a physical apex into smaller turns or move it between samples; it is still used for progress and timing, but no longer defines the physical junction geometry alone.

The mandatory corner gate uses the incoming/outgoing angle bisector and the corresponding mitred cross-section, bounded by the existing surface sampling. Nearby straight gates inside the corner's mitre reach are omitted: their planes could intersect within the drivable road and a legal inside line could cross them in reverse order. Sharp corners retain their own mandatory gate. Existing forward-order crossing, swept movement, finish bounds and off-road recovery allowances remain. Direction follows the placed start line, including reversed starts. Geometry is prepared once; the per-tick crossing loop is unchanged.

Shared tracks published under v12 can issue v13 tickets when all other pinned engine/content/handling fields still match. This creates a new board identity. Track documents and publication manifests, historical boards and PBs are retained; old and new results are not mixed. The worker verifies the new board against the exact original track manifest with only this explicitly allowed rules transition. Other build mismatches still reject tickets. An already-issued v12 ticket is not upgraded: restart the race to obtain a v13 ticket. Queued old-rule runs still require their original verifier and are not reinterpreted as v13.

## Actual verification

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. Commands from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRouteValidation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestTracks
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestStartLine
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCheckpoints -Screen sharp-join
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py -q -k sqlite
```

- Checkpoints: 266 checks pass. Compiled straight-piece parallelograms cover 60°, 90° and 120° deflections, both windings, reversed starts, centre/inside/outside lines and 0.1/0.5/2 m sweeps. Path samples independently verify drivable cells. Six explicit corner cuts block completion and recover after returning; the existing 16 real hairpin shortcuts, circular bends, reverse/stationary and high-speed cases still pass.
- Native track/replay suite: 167 checks pass. Start line: 27; records: 53; rewind: 51. Vehicle simulation and authored road content are unchanged.
- Graphical sharp-join capture: 15 checks pass, including an on-road inside crossing 7.6 m from the apex centre, marker endpoints, warning removal and restart. Both desktop images inspected.
- Real canonical verifier tests: 32 pass, including the unchanged five-lap 12,757-tick golden replay. Only its expected rules key changed. Existing Starlette/httpx deprecation warning remains.
- SQLite domain suite: 18 pass, five expected PostgreSQL-only skips, 23 deselected. New test verifies old/new leaderboard isolation, unchanged publication manifest, successful v13 verification and rejection of an unrelated physics mismatch.
- Full backend suite, `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q`: 183 pass, six expected skips, one existing Starlette/httpx warning; 109.35 seconds. Includes PostgreSQL domain/concurrency tests and the new transition test on both databases. [Log](evidence/sharp-join-checkpoints-2026-09-30/backend-tests.log).

PostgreSQL verification used the documented disposable `bmt-backend-test` container, started with `wsl -d Ubuntu -- docker start bmt-backend-test` and stopped afterward. The first full run was interrupted because each `localhost` connection incurred a five-second resolution delay. The successful run loaded `.tools/backend-postgres.env` privately and overrode only the URL host to `127.0.0.1` in the child process's `BMT_TEST_DATABASE_URL`; measured connection setup fell from 5.020 to 0.017 seconds. No persisted credentials or application connection settings changed.

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendStart` rebuilt and restarted the local PC API/worker after the correction. Image-build checks passed the pinned Linux engine, five-lap 12,757-tick replay and retained rewind replay. `GET /v1/manifest` and an existing shared track's leaderboard both return v13; `/readyz` returns 200. No public track was uploaded for this test. Python lint on the three changed backend files passes.

The old checkpoint implementation failed twelve legal sharp-join sweeps in the initial reproducer. Test-fixture setup was corrected before final acceptance: String keys are required by the document validator, and an outer path must follow the raster road rather than decorative miter tips. A too-steep automatically resampled fixture failed the existing neighbouring-point validation and is excluded from the accepted angle matrix. The sparse square's former gate-count assertion was updated to account for deliberately removed intersecting neighbours; its full-lap and shortcut requirements remain. Initial PostgreSQL tests found the disposable test container stopped; no player database was used for those tests.

## Files and evidence

Runtime: `game/race/track_session.gd`, `race_rules.gd`, `backend/bmt_backend/runs.py`, `worker.py`. Tests/tooling: `game/tests/test_checkpoint_rules.gd`, `capture_checkpoints.gd`, `scripts/dev.ps1`, `backend/tests/test_domains.py`, `backend/tests/fixtures/verified_oval.json`. Documentation: this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

[Accepted inside line](evidence/sharp-join-checkpoints-2026-09-30/checkpoint-sharp-join-cleared.png), [deliberately missed gate showing corrected span](evidence/sharp-join-checkpoints-2026-09-30/checkpoint-missed.png). The evidence folder includes the generated creator document and native test logs. The capture intentionally pauses and positions the car; it is not a physical-device driving recording.

`adb devices` returned no attached devices. No Android export/install or phone test was performed. Owner driving acceptance on the reported track and physical-device testing remain. Arbitrary overlapping junctions, very short compound corners and every possible creator layout are not exhaustively covered. No production deployment or player-file deletion.
