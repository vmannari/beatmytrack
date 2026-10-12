# Durable flying-lap personal bests â€” 2026-10-10

Recovery-test update: [the follow-up tests and fixes](HISTOGRAM_RECOVERY_TESTS_2026_10_10.md) supersede this document's local2c616d31 candidate with **ad0ace93**, including publication/reset lock guards. The recorded measurements and earlier receipts below remain historical; schema0024 is still undeployed and live services remain on0023.

Requirements: **SC06/HOPT06** (approved next scalability slice; PB-only histogram changes), SC05/SC01â€“SC04/HOPT03â€“HOPT05/B05/B07/R01/Q01/TD06/TD08. The owner authorizes implementation and requires each histogram to contain only each driver's PB. A tied/slower race that improves neither the race PB nor flying-lap PB now leaves both source revisions and the stored histogram generation unchanged.

Implemented locally; **not uploaded or deployed**. Fresh read-only inspection confirms the development API and worker still use `d16a4a17â€¦`, schema `0023_operational_read_indexes`, with readiness 200. The new exact-parent local candidate is `bmt-lap-pb:20261010`, schema **0024_lap_personal_bests**. See [candidate proof](evidence/lap-pb-2026-10-10/image-proof.json) and [live baseline](evidence/lap-pb-2026-10-10/live-baseline.json).

## Behavior and files

`LapPersonalBest` stores one accepted flying minimum per `(board_id, player_id)`, independent of the whole-race PB. Its source run, lap index, server completion time and source creation time are durable. Four flying laps of a verified five-lap race qualify; the first standing-start lap and creator proofs do not. Missing, noninteger, nonpositive, oversized and non-five-lap splits are rejected by the projection and reported during backfill. Authorized rewind results follow the same accepted-result path; no replay/physics simulation was added.

Database triggers perform a conditional minimum upsert when a result becomes verified. Equal/slower laps preserve the previous winner. Only actual lap-PB insertions/removals/time changes advance `Board.lap_revision`. Race PBs retain their existing strict improvement upsert. Ordinary acceptance evaluates one run's five small integers and its indexed PB, without searching past attempts. The verified result and both projections commit or roll back together. Completed-ticket/idempotency paths, scoring, optional ghosts and the trajectory checker are unchanged.

Scheduled histogram generation reads race and flying-lap PBs, deduplicating compatible public/private boards by driver. It performs **zero attempt-history queries**. PB membership and player visibility still govern inclusion; artificial identities remain excluded from public standings, ratings and eligibility. GETs continue reading durable snapshots; the adaptive refresh interval and UI selection/results-open refresh behavior are unchanged. Administrative visibility, record removal and resets can invalidate stale fields immediately.

| File | Change |
| --- | --- |
| `backend/bmt_backend/track_models.py` | Lap PB and backfill/reset-state models; indexed source provenance and targeted history access |
| `backend/bmt_backend/migrations/versions/0024_lap_personal_bests.py` | Additive tables/indexes; capture/minimum/revision triggers; rare source repair; durable reset fences |
| `backend/bmt_backend/lap_bests.py` | Bounded resumable backfill, strict accepted-lap selection, explicit offline legacy parity oracle |
| `backend/bmt_backend/runs.py` | Histogram builder reads the ledger instead of aggregating attempts |
| `backend/bmt_backend/maintenance.py` | Retention protects the flying-lap source; `--backfill-laps` maintenance command |
| `backend/bmt_backend/worker.py` | Idle service workers backfill one batch after ready player/track jobs, before histogram refresh/artificial generation |
| `backend/bmt_backend/histogram_snapshots.py` | Explicit diagnostic refresh completes bounded import first |
| `backend/tests/test_lap_bests.py` | PB/tie/slower behavior, provenance/retention, invalid facts, concurrent improvement, reset/backfill/correction fences and job priority |
| `backend/tests/test_scalability_followup.py` | Retiring a nonwinner leaves its field valid; resetting an empty lap field advances the reset fence without inventing a PB revision |

## Backfill, resets and retention

Migration 0024 does **not** replay all history in its schema transaction. Existing boards receive incomplete state; a worker/maintenance batch examines at most 200 attempts on one board, with an indexed resumable cursor. Conditional minimum writes cannot overwrite a newer faster result. The batch rechecks the reset epoch/cursor while holding the state row, then rereads/locks its source facts before committing. SQLite reserves its writer with `BEGIN IMMEDIATE`; PostgreSQL uses row locks. A crash before commit leaves the cursor and imported PBs unchanged. New results are captured independently of the cursor. Incomplete boards cannot publish an empty authoritative lap field.

The prior reset question received no explicit selection during this work. This slice **preserves the reset API's existing all-car scope on selected physical tracks**, including older pinned versions. It makes the formerly vehicle-scoped lap cutoff/invalidation consistent with that existing clearing behavior; it does not silently adopt the proposed selected-car-only reset. Artificial sources older than the cutoff cannot revive through backfill or later writes. Repeated progress metadata does not rerun repair; deleting audit metadata does not remove the durable cutoff. New boards inherit retained reset cutoffs. Real drivers' historical private-board flying laps remain preserved; public real-record protection remains tested. A later owner-selected scope change must update clearing, fencing and ledger state together.

Normal accepted facts remain immutable. Deliberately retiring/correcting a winning source repairs that driver/board from indexed retained history, with a winner guard protecting concurrent improvements. Removing a nonwinner leaves the histogram alone. `maintenance.retain` excludes both race-PB and flying-PB sources. An **owned disposable retention fixture actually pruned** a redundant 100-day-old attempt while preserving the faster flying source from a slower race. No real/deployed pruning was performed.

## Measurements

Owned local PostgreSQL 17, loopback database, synthetic accepted-data fixtures. Large historical fixture loading temporarily disables USER triggers **only inside the uniquely generated disposable schema**; accepted-write regressions/finalization measurements use the real triggers. These are backend database/background measurements, not end-to-end HTTP latency or live-host guarantees. [Full measurements](evidence/lap-pb-2026-10-10/postgres-report.json).

| Drivers | Attempts per driver | Legacy flying-lap history query, median | Both PB fields and grids, median |
| ---: | ---: | ---: | ---: |
| 1,000 | 1 | 12.224 ms | 10.966 ms |
| 1,000 | 50 | 104.653 ms | 11.028 ms |
| 1,000 | 500 | 895.406 ms | 14.020 ms |

The new field reads have zero `FROM runs` queries in every case. Remaining cost scales with drivers; timings vary with database/cache pressure.

For 100,000 drivers, preparing both fields/grids took **1,016.5 ms** median; a full stored snapshot refresh took **1,751.7 ms**. Its JSON payload is **8,234,219 bytes**, and cold loading/parsing that payload took **261.9 ms** median. This is an hourly background field at the current default interval, with the existing bounded generation cache. A first cold large-field request still pays payload I/O/parsing; this slice does not claim a universal five-millisecond response.

In a 30-sample non-PB finalization fixture, database update/upsert/commit median changed from **15.943 ms to 4.339 ms**; ticket/upload preparation and verification computation were outside this timer. This is a local observation, not a guaranteed whole-finalization budget. The trajectory checker and all 114 packaged canonical files are unchanged. Initial migration plus 1,035-attempt backfill took **2.732 seconds**, six batches. Actual deployment data size/backfill time and arrival-during-batch queue delay remain to be measured before rollout; priority between batches is covered by a worker regression.

## Commands and actual checks

Python entry point: `.tools/backend-venv/Scripts/python.exe`, `PYTHONPATH=backend`, `PYTHONUTF8=1`. Local scripts are retained under `build/lap-pb-2026-10-10/`; receipt copies below are export-independent.

- `python -m pytest backend/tests/test_lap_bests.py backend/tests/test_histogram_snapshots.py backend/tests/test_scalability_followup.py backend/tests/test_test_drivers.py backend/tests/test_population_batch.py backend/tests/test_review_reliability.py backend/tests/test_review_followups.py backend/tests/test_worker_lifecycle.py backend/tests/test_maintenance.py backend/tests/test_readiness.py backend/tests/test_loadtest.py backend/tests/test_challenges_http.py backend/tests/test_rivalry_http.py -k 'not postgres' -m 'not godot' -q --tb=short --junitxml=build/lap-pb-2026-10-10/sqlite-final-tests.xml`: **146 passed, 5 skipped** before the final SQLite writer-fence addition; the exact-image checks below exercise the final implementation and two additional backfill/job-priority cases.
- `python build/lap-pb-2026-10-10/owned_postgres.py`: broader PostgreSQL regression **78 passed**; final lap-specific run **20 passed**; benchmark exit zero; uniquely owned containers removed. Source correction, multiple cars, restart/backfill and simultaneous improvements covered. Later exact-image coverage includes the additional cases.
- `python build/lap-pb-2026-10-10/live_baseline.py`: read-only API/worker image and schema/readiness inspection; no authentication session or race submission.
- `python build/lap-pb-2026-10-10/prepare_image.py`: offline exact-parent image build and SQLite migration/route smoke passed. **Seven** backend files change; all **114** canonical game files and every unrelated backend file remain byte-identical. No upload/deploy.
- `python build/lap-pb-2026-10-10/test_image.py`: final exact package: **39 SQLite passed, 1 skipped; 32 PostgreSQL passed**. Receipts are [SQLite](evidence/lap-pb-2026-10-10/image-sqlite-tests.log) and [PostgreSQL](evidence/lap-pb-2026-10-10/image-postgres-tests.log). The owned PostgreSQL container was removed after success.
- Scoped `ruff check` passed. Task-only patch reverse-check and scoped whitespace checks passed; existing CRLF normalization notices remain. Existing Starlette/httpx deprecation warning remains.

Initial receipts are retained: the creator test fixture incorrectly assumed the generic publish helper created a creator-purpose board; it now constructs one explicitly. PostgreSQL found a trigger alias collision (`old` versus PL/pgSQL `OLD`), corrected to `retired`. Two prior revision assertions changed because this request explicitly replaces all-attempt dirtying with PB-only dirtying; visibility/public-isolation assertions remain. The benchmark needed explicit `generate_series` integer argument casts. No product invariant was removed to pass these checks. Older known broad domain/canonical-environment failures documented in the preceding scalability slice were not reclassified as passing.

No UI/art/camera/physics changes, APK/export, phone attachment check, phone/device test, full Godot validation or production action. No screenshot is needed for this backend-only slice. Popularity, shared Rivalry revision caching and smaller trajectory uploads remain separate future slices.

## Rollout and rollback boundary

[AGENTS.md](../AGENTS.md) requires explicit deployment authorization. This task prepares a concrete local candidate; live services remain on schema 0023. Exact-schema readiness remains strict; unknown or old heads are not silently accepted.

Before any authorized rollout:

1. Recheck the actual API/worker image/configuration and live counts of boards/retained attempts. Estimate backfill time against a disposable copy and compare the old lap query with the ledger on the same snapshot. Report invalid facts or already-pruned provenance; do not invent missing accepted data.
2. Select a bounded maintenance window from that measurement. Drain/stop writers, take a fresh backup and retain the exact parent image/configuration. The 2.732-second small local fixture does not establish the duration on deployed data. A large data set instead needs the explicitly tested expand/backfill compatibility release described in the preceding plan.
3. Migrate to 0024, repeat `python -m bmt_backend.maintenance --backfill-laps` until `complete=true`, then check `invalid_records` and parity. Warm published public/private snapshots with the matching gated worker before enabling traffic. Never serve an empty ledger as complete.
4. Switch matching API/worker/migration/smoke/catalog image references; check strict readiness, existing PB counts, frames, visibility/private 404s, normal completed-ticket values and one authorized smoke fixture. Existing population settings/cadence/resources remain pinned.
5. If a problem appears, stop writers and preserve the additive tables/source-run retention protection. Do not blindly redeploy schema-0023 code against head 0024 or downgrade/drop the ledger on live data. Prepare a matching-head rollback build with the legacy background lap reader and retained source protection, or restore the fresh stopped-writer backup and exact parent together after confirming there are no post-backup accepted writes. That rollback build/live restoration has **not** been performed in this task.

Checkpoint: [workspace task-only patch](evidence/lap-pb-2026-10-10/scoped-change.patch), [exact-parent server patch](evidence/lap-pb-2026-10-10/server-image.patch). The shared worktree contains unrelated changes; this slice does not commit or package them.
