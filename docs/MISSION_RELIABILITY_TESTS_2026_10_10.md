# Mission-reliability failure tests â€” 2026-10-10

Requirements **MR01â€“MR13**, B05/B07/R01/Q01/HOPT06â€“HOPT07/SC06â€“SC07. The owner asks for tests of the thirteen unusual failure scenarios discussed in chat. This local slice creates **22 backend test functions / 25 scenarios per database engine**, plus an actual Godot outbox test with **11 checks**. It fixes three defects found by the tests. It does not promise 100% availability or perform destructive cloud drills.

## Scenarios and evidence boundaries

| Requirement | Automated coverage | Boundary |
| --- | --- | --- |
| MR01: commit succeeds, acknowledgement disappears | Real SQL commit followed by injected transport-equivalent error for upload, verification, resume spending and Rivalry points. Exact retries preserve one run/receipt/effect; computed results are not reverified. | Lost acknowledgement is injected after commit; not a physical packet-drop proxy. |
| MR02: database transition/failover | PostgreSQL becomes transaction-read-only; an owned idle connection is terminated; a paused worker loses its connection, its lease is reassigned, then it reconnects with observably stale output. | Real connections/processes, but not a managed HA standby promotion or zonal outage. |
| MR03: simultaneous service restarts | Two API processes and a paused worker are killed before replacements start. Six acknowledged jobs, sessions, PBs and lap minima recover from the shared durable database/objects. | Explicit lease expiry in the disposable fixture models recovery after the expiry deadline. |
| MR04: existing objects readable, new writes fail | Actual local publication fails with EACCES/ENOSPC while retained track data remains readable. Readiness must fail, upload is not acknowledged, saved submission recovers after repair. | Filesystem publication failure is injected; no real host disk is filled. |
| MR05: slow dependency | One real API's storage stalls. Concurrent readiness requests are bounded, one probe thread remains, liveness and the second API stay responsive, and recovery needs no process restart. | A controlled storage boundary stall, not an uncontrolled network blackhole. |
| MR06: reconnect wave | **32 distinct players, two API processes, two workers, two races each, three identical successful submissions per race: 64 distinct verified runs / 192 successful upload responses.** Explicit validation-busy responses use bounded backoff/jitter with original keys/bodies. A separate eight-player/four-slot case proves 429 does not discard saved attempts. | Functional burst/retry test, not a thousands-of-players capacity or uptime claim. |
| MR07: outage crosses expiry/competition end | Accepted ticket can recover its exact verified result after expiry; a never-admitted expired ticket remains 410 without publication. A pre-deadline accepted Rivalry job verified after rollover produces exactly one outcome. | Existing admission/eligibility policy is preserved; no new grace policy for never-accepted late races. |
| MR08: suspended/skewed worker | Replacement finishes after lease expiry; the old worker resumes with its clock one hour ahead/behind and a deliberately better fake time. It cannot overwrite either PB. | Clock/lease logic simulation, not OS suspend or NTP manipulation. |
| MR09: corrupt shared track object | Four jobs using a damaged track do not starve four jobs using another track. Failure is infrastructure/retryable, not cheating rejection; original evidence is retained and jobs recover after repair. | Test-only blob corruption in an owned directory. |
| MR10: mixed builds/schema | A changed verifier cannot claim/rescore an old pinned ticket; the matching verifier later completes it. Unknown schema makes readiness unavailable and never silently compatible. | Does not prove a zero-downtime rolling schema migration; that requires the compatibility rollout from the previous plan. |
| MR11: restore looks successful but evidence is missing | SQLite backup restores into another database/object directory; a referenced object is deliberately missing and detected before starting the restored API. After object repair, pending work/retries/PBs recover without duplication. A crashed backup guard continues blocking GC across a new factory while races progress; only its owner token releases it. | SQLite restore drill, not live PostgreSQL PITR or regional restoration. The semantic object audit is part of this test, not a newly deployed restore service. |
| MR12: account changes during upload | Actual `CloudTracks` disk outbox receives a delayed response after switching Alice to Bob. Bob gains no job/result; Alice's original ticket/key/evidence survive adapter restart and recover the same accepted run. | Pinned Godot engine with controlled transport responses; no real account/device/network. |
| MR13: hot-track PBs and maintenance | 24 players submit two improving races each. Two verifier threads run while background snapshots and online retention inspect the same field. Every accepted job verifies, the queue drains, and race/flying PBs are exact. | Recent records are retained; this case runs concurrent maintenance, not a full concurrent backup export or destructive pruning of those recent jobs. |

New files: `backend/tests/test_mission_reliability.py`, `backend/tests/test_mission_processes.py`, `game/tests/test_mission_outbox.gd`.

Existing test-only process helpers now support continuous workers and record an owned PostgreSQL backend PID at the pause barrier: `backend/tests/test_replica_failures.py`, `backend/tests/replica_process_probe.py`. These helpers remain outside the deployment package. No new dependencies or runtime AI calls were added.

## Defects found and changes

1. **Accepted ticket recovery after expiry returned 410.** `backend/bmt_backend/runs.py` checked expiry before looking for an existing accepted run. It now checks ownership/scope/content and returns the stored run before applying expiry to first admission. Changed replay content still conflicts; never-admitted expired tickets still fail; no replacement attempt is minted.
2. **Storage readiness could be green on full/read-only storage.** The constant immutable probe object was reused, so local storage only read the existing object. `backend/bmt_backend/readiness.py` now creates, verifies and removes a unique reserved-format probe. `backend/bmt_backend/storage.py` releases its ephemeral pin. Repeated checks do not accumulate successful probe objects/pins; failed cleanup can fall back to expiry/age-based maintenance and is logged.
3. **Database readiness tested reads but not commit capability.** A schema-only refresh could succeed during a read-only primary transition. Readiness now commits a small upsert to one existing `OperationState` row, `readiness-write`, after strict schema validation. It never touches player/results data. PostgreSQL probe timeouts remain transaction-local; existing cache/coalescing/deadline/liveness checks pass.

Readiness still has the existing bounded request deadline, one IO thread, caching and deep-probe cadence. The extra work occurs at probe cadence, not inside trajectory computation. The database write and optional object/pin cleanup introduce small bounded operational IO; live-provider latency/permissions should be checked before rollout. No new IAM privileges were granted.

The initial suite had five failures: four represented the three defects above; the upload-ack injection initially missed ORM's unset pre-flush status default. That fixture now intercepts the actual committed upload. The slow-storage fixture explicitly invalidates cached storage health before forcing a stall. Burst fixtures retry only advertised admission pressure rather than treating every initial request as guaranteed 202. Unexpected database/storage errors in the healthy burst remain failures. No integrity assertion was weakened.

The four defect assertions also fail against frozen pre-fix source, with no mutation of the shared runtime. [Frozen-source receipt](evidence/mission-reliability-2026-10-10/frozen-before.log), [initial SQLite receipt](evidence/mission-reliability-2026-10-10/sqlite-initial.xml). The native fixture's initial incorrect mock method was corrected to the adapter's real `submit_run` signature; the game runtime needed no change.

## Actual verification

Python: `.tools/backend-venv/Scripts/python.exe`, `PYTHONPATH=backend`, `PYTHONUTF8=1`. Each PostgreSQL runner creates a unique local container/fixture schema, checks ownership before stopping and leaves deployed services untouched. Actor credentials/database configuration stay in disposable private fixtures, not evidence files.

| Actual command/run | Outcome |
| --- | --- |
| `python -m pytest backend/tests/test_mission_reliability.py -k 'not postgres' -q --tb=short` | **15 passed, 1 skipped** before the later no-probe-leak and crashed-backup cases. |
| Broader selected SQLite run below | **140 passed, 12 skipped**, before the final combined-process and crashed-backup additions. |
| `python build/mission-reliability-2026-10-10/owned_postgres.py` | Corrected mission domain/process cases **17 passed**; broader final selected PostgreSQL run **77 passed**. Includes real 32-player HTTP retries and worker recovery. Owned containers removed. |
| `python build/mission-reliability-2026-10-10/test_image.py` | Exact candidate main suite **87 SQLite passed, 8 skipped; 77 PostgreSQL passed**. |
| Additional exact-candidate tests | Combined connection-loss/reassignment and crashed-backup cases: [PostgreSQL receipt](evidence/mission-reliability-2026-10-10/image-extra.log); crashed-backup SQLite **1 passed**; extra PostgreSQL **2 passed**. Combined final candidate totals are **88 SQLite passed / 8 skipped and 79 PostgreSQL passed**, because these extra cases were absent from the main-run collection. |
| Pinned native outbox command below | **11 checks, zero failures**. |
| Scoped Ruff and whitespace/patch checks | Passed; existing Starlette/httpx deprecation and CRLF normalization notices remain. |

Broader command actually run:

```powershell
$env:PYTHONPATH='backend'; $env:PYTHONUTF8='1'
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_mission_reliability.py backend/tests/test_readiness.py backend/tests/test_mission_processes.py backend/tests/test_exception_recovery.py backend/tests/test_histogram_recovery.py backend/tests/test_lap_bests.py backend/tests/test_histogram_snapshots.py backend/tests/test_population_batch.py backend/tests/test_test_drivers.py backend/tests/test_worker_lifecycle.py backend/tests/test_maintenance.py backend/tests/test_loadtest.py -k 'not postgres' -m 'not godot' -q --tb=short --junitxml=build/mission-reliability-2026-10-10/sqlite-final.xml
```

Native command actually run, with isolated application data:

```powershell
$env:APPDATA=(Join-Path (Get-Location) 'build/mission-outbox-user')
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_mission_outbox.gd -CommandTimeoutSeconds 90
```

Engine: **Godot 4.7.2 stable ed1daf0bf**, exact pinned executable through `scripts/dev.ps1`. No phone attachment check, phone/device test, APK/export or full Godot validation. Backend verification uses declared synthetic adapters in these reliability tests; this does not establish new native trajectory/anti-cheat coverage. No visible UI change or screenshot requirement. Counts overlap across runs; no line/branch coverage percentage was measured and the complete backend/native suite was not claimed green.

## Candidate, checkpoint and outstanding drills

Fresh deployment inspection remains development image `d16a4a17â€¦`, schema **0023**, readiness 200; no account/race/schema changes were made. Local candidate **`bmt-mission-recovery:20261010`**, image ID **`sha256:58a44db0afd1547aceb0515d725b6bb2dbd6e1613729674ce29fa1154249a107`**, includes the previous undeployed lap-PB/reset fixes plus this slice. It changes **ten backend files** on the exact development parent and preserves every unrelated backend file and all **114 canonical game files byte for byte**. [Image proof](evidence/mission-reliability-2026-10-10/image-proof.json). The prior `ad0ace93â€¦` candidate is superseded; schema 0024 remains undeployed.

This task does **not** perform real zone/region loss, managed database failover/PITR, restoration of the deployed backup, long-duration soak, live DNS/certificate/identity outages or an actual mixed-schema rolling deployment. Those require an explicitly authorized isolated infrastructure drill, defined availability/recovery/data-loss objectives and measured production resource/connection limits. Local passing tests do not imply a 100% uptime guarantee. The rollout/backfill/rollback preflight from [the lap-PB document](LAP_PERSONAL_BESTS_2026_10_10.md) still applies; readiness now also needs live write/create/delete-cleanup permission and latency acceptance. No image upload, migration or deployment was performed.

Task-only [patch](evidence/mission-reliability-2026-10-10/scoped-change.patch), [exact-parent server patch](evidence/mission-reliability-2026-10-10/server-image.patch), sanitized test/build receipts and local runner source are retained. The shared worktree contains unrelated changes; they are not included in this checkpoint or image.
