# Backend achievement timing — 2026-11-03

BAT01: Check race/biome grants and read visibility against verification commit. BAT02: Remove empty-worker backoff for newly committed achievement work. BAT03: Respect scheduled eligibility deadlines and promptly recheck pending competitions. Preserve grant criteria, atomicity, permanent receipt deduplication, bounded idle work and worker fairness.

The follow-up asks whether the backend adds delays beyond normal processing. This review uses local runtime sources, transaction tests and disposable SQLite fixtures. No production account, result, worker or database was queried.

| Path | Finding and final behavior |
| --- | --- |
| Race, biome, distance, clean/precision/PB milestones | `worker.finalize()` calls `economy.accept_verified()` and `achievements.capture_race()` before its verification transaction commits. Metrics and unlocks are immediately readable once the run is verified. They do not wait for the achievement worker, rarity aggregation, another race or another biome. The biome comes from that run's track version. |
| Achievement collection | Two bounded achievement SELECTs; no awarding, history scan, worker wait or collection cache. Middleware supplies `Cache-Control: no-store`. Rarity aggregation is independent of an individual's grant. |
| Creator plays/reach | Effects are queued transactionally to avoid cross-player locking in race acceptance. Previously, new events could arrive during the worker's 60-second empty-queue cooldown without invalidating it. They now issue a coalesced wake hint after commit and bypass that cooldown on the next normal worker turn. |
| Publication/rarity work | Individual publication awards already commit with publication. Their newly pending rarity work now uses the same wake hint. |
| Competition and held-record deadlines | Previously a full empty scan could sleep past a known due time. The existing bounded queries now retain the earliest future deadlines, capping the cooldown at the next eligibility time. Competition end times and the required 30-day held-record period remain. |
| Competition waiting for queued/verifying races | Previously rescheduled for 60 seconds later, even if the last race completed immediately. It now retries after one second, matching normal worker cadence. A pending race still prevents premature final awards. |

The previous Desert→Grass report is consistent with deferred client refresh or ordinary verification completing later. The ordinary backend grant path itself has no achievement-specific timer. These tests do not establish the production timeline of that particular report.

One eligibility rule matters when interpreting progress: non-improving races with terminal status `skipped` intentionally do not advance verification-dependent achievements, under [the existing skip contract](NON_IMPROVING_RACE_SKIP_2026_10_26.md). Their completion coins still apply. The new regression checks that this is exclusion rather than a queued grant. This timing task preserves that rule and all thresholds; it does not retroactively count skipped history.

Changed runtime sources:

- `backend/bmt_backend/achievements.py`: post-commit hints for newly pending work/scheduled competitions, generation-aware cooldown, known deadline tracking and one-second pending-competition retry.
- `backend/bmt_backend/creator_achievements.py`: request the shared wake after committing new creator effects.
- `backend/bmt_backend/run_signals.py`: retain a local work generation through the worker clearing its wake event; expose a transaction-scoped helper that uses the existing commit/rollback hooks and existing notification packet.

No database IO or NOTIFY is added inside the transaction by the hint helper. PostgreSQL delivery remains on the existing bounded notification transport. Rollback discards the hint. Work arriving during a scan retains a later generation so that the scan cannot consume its wake. Empty idle scans still use four bounded achievement probes at most once a minute; known deadlines and committed work are the exceptions. Lost notification hints retain the existing durable fallback. Fair role rotation and reserved turns under racing load remain.

`backend/tests/test_achievement_timing.py` adds transaction, creator/rarity wake, lost-hint fallback, remote hint receipt, scan-race, deadline, pending-competition and skipped-result checks. The independent PostgreSQL listener test is present but remains unexecuted because database setup failed.

| Actual verification | Result |
| --- | --- |
| Original four new tests against task-start runtime | 2 passed, 2 failed: new creator and rarity work stayed behind the idle cooldown |
| Final SQLite timing/achievement/priority/confirmation regression | 43 passed, 2 skipped, 55 deselected; exit 0 |
| Additional hint receipt/scan-race tests | 2 passed, 20 deselected; exit 0 |
| Supporting earlier skip/completion/worker lifecycle run | 55 passed, 1 skipped, 51 deselected; exit 0; preceded the deadline refinement |
| Scoped Ruff and whitespace checks | Passed |
| PostgreSQL initial run | 31 setup errors: connection timeout to configured disposable localhost database; no test body ran |
| Final PostgreSQL attempt with normal access, fail-fast | Same connection timeout on first setup; exit 1; no test body ran |

The two final SQLite skips require PostgreSQL: independent notification sessions and real row-lock concurrency. These are not counted as passes. Initial setup also exposed a missing parent for pytest's task-specific basetemp; the parent was created and tests rerun. A second sandbox PostgreSQL attempt was interrupted after the repeated connection failure was established. The normal-access shell also reported its existing PowerShell profile execution-policy error; the test command ran and retained the same database timeout. Global Python lacked pytest, so all actual tests used the existing `backend-secure-venv`. No dependencies, database/service configuration or owner processes were changed. Existing FastAPI deprecation and SQLite index-reflection warnings are retained.

Commands ran from `backend/`, using new, task-specific basetemp directories under `build/backend-achievement-timing-2026-11-03/`:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_achievement_timing.py -q -k 'not postgres' --basetemp=../build/backend-achievement-timing-2026-11-03/baseline-tests
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_achievement_timing.py tests/test_achievements.py tests/test_priority_scaling.py tests/test_run_confirmation.py -q -k 'not postgres and not matching_plan and not migration' --basetemp=../build/backend-achievement-timing-2026-11-03/final-regression-sqlite
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_achievement_timing.py -q -k 'remote_hint or arriving_during' --basetemp=../build/backend-achievement-timing-2026-11-03/final-hint-races
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_achievement_timing.py tests/test_priority_scaling.py tests/test_run_confirmation.py -q -x -k 'postgres and not sqlite and not matching_plan and not migration' --basetemp=../build/backend-achievement-timing-2026-11-03/final-postgres-access
```

Each test command also wrote raw logs and JUnit XML to [the evidence directory](evidence/backend-achievement-timing-2026-11-03/). The checkpoint records final source hashes and before/after patch verification. It excludes concurrent work and the previous client timing fix. Forward/reverse patch application and normalized content equality are checked in a private temporary repository; the main index is untouched.

Remaining limits: PostgreSQL LISTEN/NOTIFY and row-locking acceptance, matching API/worker deployment and owner acceptance remain. Verification queues, lock contention, worker failures, offline transport and lost-hint fallback can still postpone delivery. No production latency or maximum-delay guarantee is claimed. Competition/record eligibility periods remain intentional. No migration, gameplay/competitive identity change, UI layout change, screenshot requirement, device query/test, APK, real backend operation, deployment, owner-save/process change, staging, commit or merge was performed.
