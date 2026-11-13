# Local backend cost simulation — 26 October 2026

**Yes: the existing storage, caching, archival and retention mechanisms can be exercised on this PC. This task ran them with synthetic data, real PostgreSQL17 and the actual pinned Godot client.** The measurements establish functional behavior and local resource tradeoffs. They do not establish one-million-DAU capacity or a Google Cloud bill.

Requirements: LCS01 isolated local environment, LCS02 packing measurements, LCS03 receipt archival, LCS04 retention, LCS05 native download reuse, LCS06 restore, LCS07 evidence/preservation. Runtime application and deployment sources were not changed.

## Measured results

| Experiment | Actual local result | Implication |
|---|---|---|
| Packing |512 distinct records became16 physical pack writes: **96.875% fewer writes** | Substantial object-operation saving is possible with the existing implementation. Actual pack occupancy matters. |
| Object bytes |32,556,797 individual-object bytes versus32,556,925 packed bytes | Packing preserves independently compressed records; its principal benefit here is fewer operations, not fewer content bytes. The128 extra bytes are16 pack headers. |
| Packing overhead |6.65s individual writes;30.45s durable SQL intake plus6.31s flushing;4,261 top-level SQL statements and48,184,936 WAL bytes | Packing shifts work into PostgreSQL. It should be calibrated before being enabled broadly. This local filesystem/loopback comparison is not a GCS benchmark. |
| Receipt archival |5,000 old synthetic receipts left hot SQL in10 batches, taking5.57s;20 sampled cold replies matched exactly | Existing archival can retain exact retry answers while freeing live SQL rows. |
| Allocated SQL |Receipt table allocation stayed7,577,600 bytes after live rows fell5,000→0 | Deleted rows can become reusable capacity without immediately shrinking existing database files. Storage savings primarily prevent further growth until space is otherwise reclaimed. |
| Retention |For120 synthetic runs aged10/40/100days,7/30/90-day policies selected110/74/37 runs | Retention-policy choices have materially different effects and can be tested without changing the server clock or real data. |
| Protected records |Applying the seven-day policy removed110 runs and retained all10 PB/lap sources | The current reference-aware policy preserved the fixture's protected results. |
| Actual Godot cache |11 successful accesses used **one full recording download and10 cache hits**; a fresh client reused the disk cache | The client-side reuse mechanism works over real loopback HTTP and across client instances. |
| Access withdrawal |The warm cache stopped returning the recording after its source was hidden | Reuse retained the current access check. |
| Logging |10,000 successful request observations produced100 detailed success logs; totals still counted all10,000 requests/4,000,000 response bytes; an error remained logged | Application success sampling cuts detail volume without sampling away aggregate counts. Provider request-log sampling is a separate rollout task. |
| Restore |Real `pg_dump`/`pg_restore` plus source object backup/restore recovered64 sampled packed records, one unflushed pending record and20 exact private archive replies | Database pointers, pending bytes, physical packs and archive keys/objects can survive a coordinated local restore. |

These are independent controlled experiments. They do not justify adding their percentages together as an overall bill reduction.

### Packing detail and its tradeoff

The packing dataset uses the existing2,130-sample recording fixture, wrapped in512 distinct synthetic record identities. Individual and packed paths receive exactly the same logical values and hashes. The real `LocalBlobStore` and `PackedBlobStore` implementations perform their normal hashing, compression, durability and integrity work. Physical pack upload/range-read methods are instrumented without changing their behavior.

The512 records distributed across16 hash partitions. A forced end-of-batch flush produced16 partially occupied packs, with32 records per pack on average. That is deliberately more realistic for a small batch than assuming every pack reaches its128-record maximum. It is still not a simulation of a sustained production arrival distribution or the normal five-second flush cadence.

| Metric | Individual objects | Durable packed intake |
|---|---:|---:|
| Put P50 |10.03ms |59.87ms |
| Put P95 |31.28ms |64.19ms |
| Put P99 |34.06ms |67.53ms |
| Total write/intake time |6.65s |30.45s |
| Subsequent pack flush time |Included in individual writes |6.31s |
| Physical object writes |512 |16 |

The packed path incurred approximately46MiB of PostgreSQL WAL and25.6s of summed SQL cursor wall time in this serial experiment. Local individual writes have no GCS request/response round trip; packed intake crosses Windows→WSL PostgreSQL and performs several SQL operations per record. PostgreSQL data was on tmpfs, not persistent cloud SSD. These facts prevent treating the observed slowdown as a prediction of cloud performance.

The important next measurement is net behavior under representative object-service latency and concurrent intake: arrival rate, pack occupancy, full SQL transaction latency, WAL/IOPS, retained pending bytes and foreground P95. This experiment supports the operation-count saving while exposing the database cost that must accompany it.

After publication, packed SQL rows held small locations rather than the full pending payload. PostgreSQL's allocated pages remained available for reuse. The final measurement also includes one deliberately unflushed restore-probe record; it is not evidence of a failed flush.

[Complete packing measurements](evidence/backend-local-cost-simulation-2026-10-26/packing.json).

### Archival and retention

The archive experiment creates5,000 invented idempotency receipts across10 synthetic accounts, dates them30days old, then calls the current encrypted archival implementation with its500-record batch bound. It does not invent a replacement archive algorithm. After archival, all20 sampled original requests recovered byte-equivalent logical replies through `replay_response`. Live receipt tuple payload fell from5,515,000 bytes to0; the cold object directory used1,885,684 bytes at that stage. Existing35-test cost checks separately exercise changed-body rejection, missing keys, lost acknowledgements, duplicate reward prevention and protected-reference cleanup.

The unchanged7.58MB table/index allocation is a material result: moving existing rows does not itself produce an immediate smaller provisioned-disk bill. The active working set and future growth can improve before allocated storage changes. No `VACUUM FULL`, production disk operation or real retention policy was applied.

The retention fixture has40 runs in each age bucket (10,40,100days). Ten first PB/lap sources are protected. Source dry-runs select110/74/37 candidates for7/30/90days respectively. Applying seven days removes110 and leaves all10 protected sources. This verifies the fixture's authority references; it does not establish that only1% of production history will be protected or that seven days is an accepted product policy. Challenge/day milestone compaction remains separate work.

[Archival results](evidence/backend-local-cost-simulation-2026-10-26/archives.json), [retention results](evidence/backend-local-cost-simulation-2026-10-26/retention.json), [logging results](evidence/backend-local-cost-simulation-2026-10-26/logging.json).

### Actual native client and compressed bytes

Pinned Godot4.7.2 ran a headless audit script against a new loopback API with invented development identities and an isolated Windows profile. Ten repeated recording accesses used one body download. A newly constructed and authenticated client reused the same disk recording without downloading another body. A final source withdrawal was rejected despite that warm cache.

The final run passed **21 native assertions**, returned Python exit code0 and completed every fixture assertion. The first recording body was47,561 compressed bytes. All ghost-route response bodies combined—including metadata and the final withdrawal error—were47,965 bytes. Nine unchanged metadata responses were304 with zero response-body bytes. These counts exclude headers/TLS and do not include the unrelated fixture's login/setup responses.

This demonstrates repeated-content reuse; it cannot establish average downloaded bytes/player/day. Eleven different recordings would have very different reuse. New installs, cache eviction, account changes, source revisions, browsing and selected opponents still need a representative journey mix.

The source helper generates canonical diagnostic evidence before the native cache experiment. That offline fixture preparation is not a full-replay fallback in ordinary race acceptance. This task did not modify verification policy or repair the older mixed load generator.

[Native counters](evidence/backend-local-cost-simulation-2026-10-26/native-cache.json), [exact child exit](evidence/backend-local-cost-simulation-2026-10-26/native-exit.json), [native stdout](evidence/backend-local-cost-simulation-2026-10-26/native-final.stdout.log), [native stderr/warnings](evidence/backend-local-cost-simulation-2026-10-26/native-final.stderr.log).

## Environment, isolation and actual checks

- Docker in Ubuntu WSL; cached `postgres:17-bookworm`, observed PostgreSQL17.11. No image pull, billable resource creation or cloud call was needed.
- A uniquely named/labelled disposable container, capped at2CPU/1,536MiB,40 connections,64MiB shared buffers and768MiB tmpfs data, with a randomly allocated port bound only to127.0.0.1. Fixture credentials stayed in ignored task-owned build storage and were removed with the fixture state.
- Only synthetic players, receipts, recordings and timestamps were generated. No real player database, credentials, purchases or accounts were read/copied.
- **35 existing local cost tests passed**,2 deselected. **20 existing PostgreSQL tests passed**,36 deselected. The latter include real transactional acceptance/reward/concurrency/retention checks; test verifiers isolate domain behavior and are not throughput proof for the current real race pipeline.
- The measured packing/archive/retention/logging experiments passed their assertions. The restore used a464,179-byte synthetic PostgreSQL dump into a different, newly created empty database. Object archives restored into new empty directories. All64 sampled pack values, the pending SQL value and20 private replies matched exactly.
- The disposable container and both synthetic databases were removed after validation. The three existing Beat My Track API/worker/database containers retained their original IDs and start times. One unrelated application's API had a changed start time; no simulation mutation command targeted it. Its cause is unestablished and the observation is retained rather than claiming all five original containers stayed unchanged.

[PostgreSQL environment](evidence/backend-local-cost-simulation-2026-10-26/postgres-environment.json), [35-test log](evidence/backend-local-cost-simulation-2026-10-26/regressions.log), [20-test PostgreSQL log](evidence/backend-local-cost-simulation-2026-10-26/postgres-checks.log), [database restore](evidence/backend-local-cost-simulation-2026-10-26/database-restore.json), [restored values](evidence/backend-local-cost-simulation-2026-10-26/restore-validation.json), [cleanup](evidence/backend-local-cost-simulation-2026-10-26/cleanup.json), [original-container observations](evidence/backend-local-cost-simulation-2026-10-26/existing-container-observations.json).

Initial attempts are retained: sandboxed WSL/WMI inspection was denied; an inline Windows→WSL quoting attempt failed before execution; the first35-test selection had24passes/11setup errors because `Base.metadata.create_all` ran without the complete model registry. A wrapper initializes the same registry used by the application and reruns the unchanged assertions:35pass. The first native run completed21checks but PowerShell surfaced diagnostic stderr as an error result; a fresh-fixture subprocess capture established the exact successful Python exit0. The first cleanup refused when it detected the unrelated container restart; the final cleanup records that drift while retaining the exact ID/name/label ownership fence for removing only this task's container.

## Reproduction and retained artifacts

The [machine-readable report](evidence/backend-local-cost-simulation-2026-10-26/report.json) contains exact commands, source/artifact hashes, outcomes and limitations. The [task-only patch](evidence/backend-local-cost-simulation-2026-10-26/scoped-change.patch) contains only this report and new simulation tools/evidence; it does not change the application or existing deployment.

The scripts deliberately refuse to overwrite an existing fixture state or restore target. A repeat run should use a fresh task-owned build directory or explicitly remove only its checked synthetic artifacts first. They are evidence tools for this workstation, not an unattended production maintenance job.

Main sequence, from the repository root with the existing Python environment:

```text
WSL: python3 docs/evidence/backend-local-cost-simulation-2026-10-26/postgres_fixture.py start
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/database_probe.py
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/run_regressions.py
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/run_postgres_checks.py
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/local_cost_lab.py
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/capture_native.py
WSL: python3 docs/evidence/backend-local-cost-simulation-2026-10-26/postgres_fixture.py restore
.tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/verify_restore.py
WSL: python3 docs/evidence/backend-local-cost-simulation-2026-10-26/postgres_fixture.py stop
```

The actual WSL invocations use the absolute `/mnt/c/Codes/Godot/Beat my track/...` script path; full argument arrays are in the report. Generated object directories, fixture dump and isolated profiles remain under ignored `build/backend-local-cost-simulation-2026-10-26` for local inspection. They contain synthetic data only.

## What remains to prove

The local results justify proceeding with controlled calibration. They do not validate the EUR3,900–6,900 monthly scenario. That still depends on real returning/new-player download mix, distinct recordings, actual pack occupancy, protected history, permanent milestones, database work/IOPS and provider billing. Provider request logs, soft-deleted object bytes and worldwide egress were not simulated by the application-only logging and filesystem counters.

The next capacity experiment should use a corrected current trajectory body, production-shaped PostgreSQL storage/latency, concurrent real acceptance and background packing/archive work. Measure offered/completed requests, full confirmation P50/P95/P99, CPU/RSS, connection waits, locks, WAL, pack fill and cleanup catch-up. The earlier mixed load generator's protocol gap remains; this task did not use its synthetic pass as current capacity evidence.

Cloud SQL failover/PITR, Google object-service fault behavior, complete production privacy-erasure-ledger recovery, geographical/mobile latency and invoices remain separate acceptance. No physical-device attachment check/test, APK/export/install, real sign-in/ad/purchase, live player/backend mutation, deployment or owner game-process restart was performed.
