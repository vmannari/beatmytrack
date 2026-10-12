# Histogram and lap-PB recovery tests — 2026-10-10

Follow-up: [mission-reliability tests](MISSION_RELIABILITY_TESTS_2026_10_10.md) add failure sequences and fixes, superseding the ad0ace93 local candidate below with **58a44db0**. Earlier receipts remain historical; no deployment has occurred.

Requirements: **HOPT07/SC07** (implement and run the ten identified missing cases), HOPT06/SC06/B05/B07/R01/Q01/TD06/TD08. The owner explicitly requests implementation/testing. This slice adds **13 test functions, 23 parameterized scenarios per database engine**, fixes two reproduced reset races, and refreshes the local release candidate. It performs no deployment, live pruning or player-record writes.

## Coverage added

New file: `backend/tests/test_histogram_recovery.py`.

| Gap | Actual assertions |
| --- | --- |
| New PB during backfill | A real worker verifies a queued run whose ID is behind the persisted backfill cursor; the older batch cannot overwrite the new minimum/source. |
| Partial backfill failure | SQL failure on the second PB insertion occurs after the first insertion executed; all inserted PBs, lap revisions and cursor state roll back. A retry imports the correct minima. |
| Stale histogram builder | A replacement worker takes the expired lease and publishes a newer population; the original cannot overwrite it or clear its state, including when the original later throws. |
| Generation/publication failure | Both computation failure and SQL payload-publication failure preserve the old valid generation, leave the field dirty, release the owned lease and retry after the configured backoff. HTTP reads still serve the old valid snapshot. |
| Reset/verification/source-repair races | Actual reset API fences a proof already computing; a PostgreSQL reset waits for finalization without deadlock and rejects changed inventory; an old source repair blocked on reset cannot restore a retired minimum. Fresh eligible records remain writable afterward. |
| Winning-source correction | Worsening the winner, invalidating its splits and retiring the last source correctly replace/remove the minimum and invalidate a stale snapshot. |
| Race-only PB | An actual faster race advances only the race revision while retaining a better flying source from a slower prior race; the rebuilt fields show both correct values. |
| Authorized rewind and retry | Actual resume receipt issuance and v2 upload/worker finalization update both ledgers; resubmitting the completed ticket preserves sources/revisions and schedules no additional job. The domain verifier is a test double, not a new native trajectory test. |
| Reset boundaries/older versions | Creation exactly at the cutoff is eligible; repeated and older reset metadata cannot lower the cutoff/increase the epoch unnecessarily; resetting the latest version also fences older versions of that physical track. |
| Split boundaries/parity | Null, object, empty, negative, 216000 and 216001 values produce matching capture-trigger/backfill results. |

Additional PostgreSQL tests hold a reset-state row locked while real players publish public and private results. Both complete independently; the new reset publication lock applies only to artificial private writes. Genuine concurrency uses separate database transactions, explicit events and observed PostgreSQL lock waits, rather than assuming a race occurred because threads were launched.

SQLite skips four new PostgreSQL lock-specific scenarios. The final image SQLite run has five skips total, including the pre-existing concurrent-PB test. Existing test assertions were retained; no failing invariant was removed.

## Defects reproduced and corrected

**Stale artificial lap restoration.** A winning-source deletion/repair could select an old replacement, block behind a reset, then insert that replacement after reset deleted the ledger row. This left a pre-cutoff minimum that could prevent a slower but eligible post-reset lap from becoming the visible PB. The initial PostgreSQL suite reproduced the failure: **19 passed, 1 failed**. [Initial receipt](evidence/histogram-recovery-2026-10-10/postgres-initial.log).

The unreleased migration `0024_lap_personal_bests.py` now installs a publication guard. SQLite ignores a stale artificial/private candidate at insertion/update. PostgreSQL share-locks that board's reset-state row for artificial/private publication and rechecks its cutoff after any wait. Concurrent artificial writers can share that lock; ordinary real/public writes do not take it. Reset holds the exclusive state lock through its clearing transaction. This closes the source-repair publication race without introducing a shared reset lock into ordinary real acceptance.

**Reset/finalization deadlock.** The previous reset deleted a PB before fencing its verifying run. The PB delete could hold the PB row while waiting for the board; finalization could hold the board while waiting for that PB. The frozen pre-fix package reproduced PostgreSQL **SQLSTATE 40P01**, surfaced as HTTP 503 `DATABASE_UNAVAILABLE`.

`backend/bmt_backend/test_population_batch.py` now fences/locks runs first, rechecks the existing inventory digest after waiting, locks affected lap reset-state rows in stable order, then removes PBs. A race that commits a new PB while reset waits produces HTTP 409 `RECORD_INVENTORY_CHANGED`; the accepted race and both PBs remain intact. A reset that successfully fences an in-flight proof still prevents that proof from republishing cleared records. Existing all-car physical-track scope and real/public protection remain unchanged.

Both new race tests fail against frozen pre-fix source and pass after the fixes. [Frozen-source proof](evidence/histogram-recovery-2026-10-10/postgres-before.log). The source-copy test does not modify the shared runtime. Snapshot generation/lease/failure tests passed without a histogram-runtime change.

## Actual commands and outcomes

Pinned Python: `.tools/backend-venv/Scripts/python.exe`. Local pytest uses `PYTHONPATH=backend`, `PYTHONUTF8=1`. Owned PostgreSQL runners generate unique container/schema names, bind only loopback, verify ownership before stopping, and never use the deployed database.

| Command | Outcome |
| --- | --- |
| `python -m pytest backend/tests/test_histogram_recovery.py -k 'not postgres' -q --tb=short` | Initial **19 passed, 1 skipped**; later additional lock tests require PostgreSQL. |
| `python build/histogram-recovery-2026-10-10/owned_postgres.py` | Initial **19 passed, 1 failed** exposed stale source repair; fixed focused run **53 passed**; broader final PostgreSQL run **59 passed**. Frozen pre-fix tests intentionally reproduce **2 failures**, including 40P01. All owned containers removed. |
| Broader SQLite command below | **172 passed, 9 skipped, 143 deselected**. |
| `python build/histogram-recovery-2026-10-10/live_baseline.py` | Read-only current API/worker image and readiness inspection: both `d16a4a17…`, schema 0023, HTTP 200. No auth session/race submission. |
| `python build/histogram-recovery-2026-10-10/prepare_image.py` | Offline local candidate build and SQLite migration/route smoke passed. |
| `python build/histogram-recovery-2026-10-10/test_image.py` | Exact candidate package: **58 SQLite passed, 5 skipped; 55 PostgreSQL passed**. Includes new scenarios and existing histogram/PB/comparison checks; frozen pre-fix failures reproduced; owned container removed. |
| Scoped `python -m ruff check …` | Passed for the new tests, migration and reset module. |

Broader SQLite command actually run:

```powershell
$env:PYTHONPATH='backend'; $env:PYTHONUTF8='1'
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_histogram_recovery.py backend/tests/test_lap_bests.py backend/tests/test_histogram_snapshots.py backend/tests/test_population_batch.py backend/tests/test_test_drivers.py backend/tests/test_scalability_followup.py backend/tests/test_review_reliability.py backend/tests/test_review_followups.py backend/tests/test_worker_lifecycle.py backend/tests/test_maintenance.py backend/tests/test_readiness.py backend/tests/test_loadtest.py backend/tests/test_challenges_http.py backend/tests/test_rivalry_http.py backend/tests/test_resumes.py -k 'not postgres and not canonical and not replay_rejects_invalid_rewind_contract' -m 'not godot' -q --tb=short --junitxml=build/histogram-recovery-2026-10-10/sqlite-final.xml
```

These are selected suite runs with overlap; their counts must not be added as unique coverage. No line/branch percentage was measured. Existing Starlette/httpx deprecation warnings remain. Known unrelated broad/native-environment failures from prior work were not removed or reported as passing.

## Candidate and limits

Local image: **`bmt-lap-recovery:20261010`**, image ID **`sha256:ad0ace930c807249ea5eac6a08bfd3313fc8779969a85bf50d333a50c784b17e`**, schema **0024_lap_personal_bests**. It supersedes the earlier `2c616d31…` candidate. The exact deployed `d16a4a17…` parent is retained; this combined candidate changes eight backend files, preserving every unrelated backend file and all **114 canonical game files byte for byte**. [Image proof](evidence/histogram-recovery-2026-10-10/image-proof.json), [server patch](evidence/histogram-recovery-2026-10-10/server-image.patch).

0024 has not been deployed and was refined before release. The new guards will be installed when the development schema advances from inspected head 0023. Do not assume `upgrade head` repairs a separate database that already ran an older draft of 0024; such a database needs explicit reconciliation or a follow-up migration. Test databases were disposable and recreated.

The lightweight trajectory checker, five-lap contract, exact completed-ticket behavior, best-only scoring, optional ghost rules, UI refresh timing and adaptive histogram cadence remain unchanged. No native physics replay, UI/art change, screenshot, phone attachment check/device test, APK/export, live reset/prune/race write, image upload or deployment was performed. A deployment still requires explicit authorization under [AGENTS.md](../AGENTS.md); the live-data/backfill/parity/rollback preflight in [the lap-PB rollout document](LAP_PERSONAL_BESTS_2026_10_10.md) remains outstanding. Sustained load and arrivals during a long background batch remain separate host acceptance checks.

Task-only checkpoint: [patch](evidence/histogram-recovery-2026-10-10/scoped-change.patch). Local runner/build source and sanitized receipts are retained beside it. The shared worktree has unrelated changes; this task does not commit/package them.
