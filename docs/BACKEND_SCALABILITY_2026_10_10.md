# Backend scalability follow-up, 2026-10-10

Requirements: SC01 (review growing backend work), SC02 (bounded operational reads), SC03 (heartbeat write coalescing), SC04 (targeted invalidation), B05/B07/R01/Q01/TD06/TD08. This is a local implementation and capacity review; no backend was deployed.

## Implemented

**Health reads:** `operations.competition_health` previously queried recent verified, failed and rejected counts and verified latency independently. Those metrics now share one filtered aggregate. Dedicated indexes on `runs.created_at` and `operation_state.updated_at` let recent arrivals and active workers avoid reading large historical ranges. Returned health values are unchanged; this adds no stale-response cache.

**Routine heartbeats:** claiming/verifying/idle diagnostics are merged per worker and persisted at most once per second (sooner if the configured stale threshold is very short). Build changes, unavailable builds, explicit lifecycle changes and a requested shutdown persist immediately. Pending metrics survive a failed flush; draining/stopped states remain sticky. Cache memory is bounded to 64 worker IDs. PostgreSQL writes never hold an application lock through pool/database waits; a shutdown writer can proceed independently and database row locks retain serialization. SQLite's shared test connection still serializes writes. This changes diagnostic sampling, not race verification, scoring, receipts or queue admission.

**Histogram invalidation:** retiring one run or removing a PB previously invalidated every stored snapshot. Player visibility changes now affect only boards on which that player has PBs. Record changes affect only the related immutable version/car. Artificial-record resets advance lap revisions and invalidate only the named tracks/car and artificial-inclusive population; public-only snapshots stay intact. Both old and new reset regions are covered when metadata changes. Progress-only updates do not invalidate data. This prevents routine work on one busy track from creating refresh work on unrelated tracks.

**Capacity lab:** the existing CLI now prepares stored histogram fixtures before request timing and uses the actual service worker's background path. Its older seed-only setup would otherwise measure unavailable histogram responses after the stored-snapshot change. The seed is still explicitly synthetic and isolated, not canonical verification evidence. Existing fresh-count tests explicitly prepare offline snapshots; no numeric, restriction or tie assertions were removed. Snapshot tests now require artificial resets to leave public-only data untouched, with a separate private-scope test proving required invalidation.

## Measurements

Owned local PostgreSQL 17, 100,000 retained attempts (100 recent), 10,000 retired worker entries, one active worker and 400 histogram registrations. Identical returned health values were checked before/after, apart from filesystem free space. Ten health calls per implementation, including the first:

| Work | Before | After |
| --- | ---: | ---: |
| Health median | 14.94 ms | 11.37 ms |
| SQL statements per health call | 10 | 7 |
| Snapshots invalidated by one retired run | 400 | 2 |
| Heartbeat SQL for 100 simulated jobs within one interval | 900 | 3 |

The heartbeat-only burst measured 1,804.84 ms before and 9.18 ms after. Its coalesced clock deliberately stays inside one interval; this is not an overall race-throughput claim. Actual verification, scoring and upload work are excluded.

EXPLAIN ANALYZE BUFFERS shows the worker lookup changing from a sequential scan discarding 10,002 entries to an indexed lookup returning the one active entry. Arrival counting used the broader claim index before (92 shared buffer hits), then its dedicated timestamp index (7). Worker lookup buffer hits fell from 104 to 3. These are local analyzed fixtures, not NAS/cloud/HTTP latency or sustained deployment-capacity results. [Samples and plans](evidence/backend-scalability-2026-10-10/postgres-report.json), [probe log](evidence/backend-scalability-2026-10-10/postgres-final-probe.log).

## Larger next opportunities

1. **Persist flying-lap PBs per driver/pinned board.** Scheduled histogram generation still reads attempt history. A durable lap projection would make refresh cost depend on drivers, not attempts, and protect lap PBs during retention. A disposable dry-run reproduced the retention gap: a slower overall attempt contained the driver's 19-tick flying PB, while their race PB had 20-tick laps; retention selected the slower attempt because only the race-PB run was referenced. No pruning was applied. Add the projection and its source-run reference before relying on generic superseded-run pruning for lap history. [Dry-run receipt](evidence/backend-scalability-2026-10-10/retention-audit.json). This task does not implement that projection or change retention policy.
2. **Share a recent-distinct-driver popularity projection.** Discovery's popular/trending order aggregates verified runs over seven days for each new filtered snapshot. Its existing twenty-second query cache helps identical searches, but different filters repeat the same history work. A per-track/driver last-finish projection plus a periodically prepared popularity order would avoid that growth. Preserve public-only drivers, creator-proof exclusion, rolling cutoff and page-time visibility checks.
3. **Cache Rivalry's shared standings by a real group revision.** Groups are already bounded to twenty drivers/five tracks, but every conditional GET builds the same standings before deciding to return 304. Share the static field across members and calculate clock/self information separately. A valid revision must include memberships, best results, profile/visibility changes, pending results, track availability and archival; week transitions must remain timely. Existing board revisions alone are insufficient for this.
4. **Reduce mandatory recording I/O with an explicit trajectory upload contract.** Acceptance is trajectory-only, but canonical controls/recordings are still retained and transported. A versioned smaller upload could separate trajectory acceptance from optional presentation/offline diagnostics. Keep exact ticket duration, resume receipts, replay pinning and durable/idempotent uploads; do not remove fields silently from the current contract.

Current bounded paths do not need blanket rewrites: queue admission uses transactional counters, job polling batches at most thirty-two IDs, adjacent rankings use indexed windows, skill matching examines at most twenty boards, track candidates are bounded, and groups/challenges have small caps. Identity/body budgets, object publication pins and short DB connection pools already supply necessary pressure limits. More caching on reward or entitlement writes would weaken correctness and is outside this review.

## Files and validation

Runtime changes: `backend/bmt_backend/operations.py`, `worker.py`, `app.py`, `track_models.py`; migration `migrations/versions/0023_operational_read_indexes.py`. Lab: `loadtest.py`. Tests: new `backend/tests/test_scalability_followup.py`, plus existing `test_histogram_snapshots.py` and `test_review_reliability.py`. This report/evidence, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md record the slice.

Commands use `.tools/backend-venv/Scripts/python.exe`, PYTHONPATH=backend and PYTHONUTF8=1:

- `-m pytest backend/tests/test_loadtest.py backend/tests/test_scalability.py backend/tests/test_worker_lifecycle.py backend/tests/test_review_reliability.py backend/tests/test_review_followups.py backend/tests/test_scalability_followup.py backend/tests/test_histogram_snapshots.py -k 'not postgres and not real_signals and not recorded_practice and not checkpoint_rules_upgrade' -q --tb=short --junitxml=build/backend-scalability-2026-10-10/sqlite-final.xml`: final **105 passed, 2 skipped, 90 deselected**. The two skips require PostgreSQL locking. [Receipt](evidence/backend-scalability-2026-10-10/sqlite-final.xml).
- `build/backend-scalability-2026-10-10/owned_postgres.py`: initial PostgreSQL selection **72 passed, 1 failed**. The failure was an older histogram fixture expecting an immediate request-time rebuild; fresh-count checks now explicitly run the offline snapshot builder. [Original receipt](evidence/backend-scalability-2026-10-10/postgres-first-tests.log).
- `build/backend-scalability-2026-10-10/owned_postgres_final.py`: corrected PostgreSQL fixture **1 passed**, then before/after benchmark exit zero. Its generated container/schema were removed. [Receipt](evidence/backend-scalability-2026-10-10/postgres-final-tests.log).
- `build/backend-scalability-2026-10-10/owned_postgres_shutdown.py`: final PostgreSQL shutdown/application-lock, draining, stop and health checks **4 passed**. An artificially blocked routine write does not prevent a stopped heartbeat using another available connection, and its later completion cannot revive the worker. Generated container removed. [Receipt](evidence/backend-scalability-2026-10-10/postgres-heartbeat-final-tests.log).
- `-m pytest backend/tests/test_loadtest.py backend/tests/test_review_reliability.py -k 'not postgres and (load or board_cache_tracks)' -q --tb=short`: **4 passed**, including actual loopback HTTP and both passing/strict-failing latency-gate contracts. [Receipt](evidence/backend-scalability-2026-10-10/fixture-load-final.xml).
- `-m ruff check backend/bmt_backend/operations.py backend/bmt_backend/migrations/versions/0023_operational_read_indexes.py backend/tests/test_scalability_followup.py`: passed.

The PostgreSQL runners use an existing local image, owned nonce-labelled containers and generated isolated schemas; cleanup verifies ownership. They never use a deployed database or reset another service. Source receipts are saved alongside evidence; their original execution directory is `build/backend-scalability-2026-10-10`.

Initial fixture errors used an unsupported helper argument and then exceeded one owner's publishing slots; the second circuit now uses another fixture owner without changing the quota. A local heartbeat cleanup alias error was corrected with an independent pending dictionary. Its obsolete hung pytest helper was stopped only after checking exact command lines/IDs; the corrected tests passed. PowerShell Stop-Process failed, so the verified owned child was terminated with taskkill. The two pre-existing broad checkpoint/practice failures recorded in the histogram report were excluded from this focused suite, not weakened or claimed fixed.

No running backend migration/deployment, external player-record writes, canonical simulation or UI changes, Android export/install, phone attachment check or device test. Migration 0023 depends on the pending 0021/0022 chain. Building indexes on a large live database requires a reviewed rollout/window; no deployment-capacity guarantee is inferred from this lab. Remaining acceptance: real-host concurrency/memory, the larger projections above and the pre-existing full-domain failures. [Task-only review patch](evidence/backend-scalability-2026-10-10/scoped-change.patch) preserves unrelated workspace work.
