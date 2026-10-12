# Stored, throttled histograms — 2026-10-10

Requirements: HOPT03 (durable histograms), HOPT04 (dirty-only timed refresh), HOPT05 (population-dependent interval), HOPT02/RR06 (selection/results initialization and unified charts), TD06/TD08 (deduplication/public isolation), B05/B07/R01/Q01 (durable jobs, migration and measured acceptance).

The owner requests stored histograms rather than rebuilding them on every request, with throttling for busy tracks and longer intervals for larger populations. This supersedes immediate histogram freshness in older fixtures. Competitive PB writes and leaderboard scoring remain immediate; histograms and their comparison positions describe the stored snapshot. UI behavior remains selection-driven discovery and one load when results open.

## Behavior

`histogram_snapshots` stores the race and flying-lap field for each immutable track version/car/comparison population. It contains the prepared sixteen-bin grids, exact frequencies/cumulative counts and per-driver best times. Publication registers every allowed car, including empty tracks. Migration backfills registrations for existing versions/boards without rewriting races or PBs.

Verified results advance a database-maintained revision and mark the relevant snapshots dirty with constant-size metadata writes. They do not rebuild a histogram. The service worker checks due dirty snapshots after player verification/track validation and before artificial generation. It claims one refresh with an expiring lease and conditionally publishes its generation. Requests never claim or build a snapshot.

The default interval is `clamp(ceil(900 * sqrt(max(1, drivers) / 1000)), 60, 3600)` seconds. `BMT_HISTOGRAM_REFRESH_SECONDS` configures the 900-second reference value and must be positive. These are initial local defaults:

| Comparable drivers | Minimum refresh interval |
| ---: | ---: |
| 10 | 90 seconds |
| 100 | 285 seconds |
| 1,000 | 15 minutes |
| 100,000 | 1 hour |

Dirty tracks rebuild at the next idle worker opportunity after their interval expires. More attempts inside that interval do not schedule more rebuilds. Clean tracks do not generate periodic work. An unchanged source fingerprint skips reconstruction if a redundant dirty notification arrives. A newly published/empty track gets an initial snapshot; the first verified result after that obeys its existing interval. Actual queue load can delay an eligible refresh beyond its minimum interval.

A slower race can improve a flying lap without changing the race PB. The new `boards.lap_revision` tracks verified lap/status/ownership/time changes separately; a fingerprint includes the actual pinned board IDs and both revisions. Test reset progress does not invalidate histograms, but changes to reset eligibility metadata do. Retired runs, removed records and player visibility changes invalidate affected stored data immediately instead of waiting for the normal interval. Publication/manifest changes also invalidate their version's snapshot. Administrative invalidation is conservatively broad; this is rare and prioritizes correctness.

Until the worker prepares a first or invalidated snapshot, the endpoint returns an unavailable response. It never fabricates an empty population or synchronously scans race history to fill the gap. Ordinary newly arriving times continue to serve the previous valid snapshot until due. Lease expiry recovers a dead worker; errors retain prior valid data and delay retry by thirty seconds. Finalization checks the source and manifest again so an administrative change during generation cannot clear its invalidation with old data.

## Request computation

Both the public histogram and unified results-comparison routes use stored snapshots. The default sixteen-bin grid comes from storage. A caller's different bin count or retained frame is a cheap viewport adjustment over stored cumulative frequencies: sixteen boundary searches, not a scan of players or attempts. Results use exact tie-aware position against that same stored field, replace the player's previous contribution and keep current-result markers separate from population counts.

The API loads a snapshot payload once per process/generation and keeps immutable frequency/own-time structures. The cache has at most four snapshots and a conservative estimated 128 MiB weight budget. Cached grids use the existing bounded aggregate cache in a separate namespace. Returned bins are copied before individual overlays; one player cannot alter another player's shared response. A cold process reloads the durable snapshot rather than reconstructing it from runs. Cold large-payload decode time and actual process RSS are not covered by a five-millisecond guarantee.

The builder still reads verified lap history when it refreshes a dirty snapshot, once per scheduled generation rather than repeatedly per request. A durable best-lap projection remains a possible later improvement for very large attempt histories. This task adds no replay physics, dependencies, UI labels or push refreshes.

## Measured computation

Owned local PostgreSQL 17, analyzed synthetic tables, five calculation calls per case, including the first payload load. Timings exclude authentication, HTTP transport and live-host load. Initial implementation measurements:

| Drivers | Attempts | Median request | Background diagnostic refresh of both populations |
| ---: | ---: | ---: | ---: |
| 100 | 100 | 2.52 ms | 160.14 ms |
| 100 | 5,000 | 2.40 ms | 183.52 ms |
| 1,000 | 1,000 | 2.76 ms | 94.82 ms |
| 1,000 | 50,000 | 2.35 ms | 246.32 ms |

The final source recheck at 1,000 drivers/1,000 attempts measured **4.659 ms median**, reflecting local timing variation. Every case used three SQL statements on the first read and two thereafter, with **zero lap-history reads** in requests. The previous implementation used eleven statements/four lap-history reads and measured 291.26 ms at 1,000 drivers/50,000 attempts. [Initial samples](evidence/histogram-cache-2026-10-10/postgres-report.json), [final recheck](evidence/histogram-cache-2026-10-10/postgres-final-report.json).

An independent 100,000-driver in-memory stored-frequency viewport/position probe ran 1,000 calls: median **0.0132 ms**, p95 **0.0165 ms**. This covers the small view adjustment only, not database generation, payload decoding or HTTP. [Receipt](evidence/histogram-cache-2026-10-10/large-population-view.json).

## Changed files

- `backend/bmt_backend/histogram_snapshots.py`: durable refresh, lease, adaptive interval, safety checks, stored reads and explicit diagnostic refresh.
- `backend/bmt_backend/histogram_population.py`: immutable driver field and cumulative-frequency view/position calculations.
- `backend/bmt_backend/migrations/versions/0022_histogram_cache.py`, `track_models.py`: snapshot storage, backfill, dirty/invalidation triggers and lap revision.
- `backend/bmt_backend/runs.py`: reads stored public/unified histograms and adds individual overlays.
- `backend/bmt_backend/board_cache.py`: bounded cache namespaces/weights; `config.py`: reference interval; `worker.py`: idle service refresh. Explicit single-race diagnostic `process_one` calls retain their prior behavior; the long-running service uses `process_worker_job`.
- `backend/tests/test_histogram_snapshots.py`: storage, cold-process reads, cadence, lap-only dirty changes, visibility/reset invalidation, leases, source-change races, migration preservation and player-job priority.
- `backend/tests/test_domains.py`, `test_test_drivers.py`: existing histogram correctness fixtures explicitly refresh offline snapshots before checking fresh counts. No count/tie/frame/isolation assertions were removed. The PostgreSQL consistency hook now commits a new stored generation between snapshot metadata and payload reads and still proves one consistent response.
- This report/evidence, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md record actual outcomes.

## Actual commands and outcomes

Python is the existing `.tools/backend-venv/Scripts/python.exe`, with PYTHONPATH=backend and PYTHONUTF8=1. No dependencies were installed.

- `-m pytest backend/tests/test_histogram_snapshots.py backend/tests/test_domains.py -k 'not postgres and (histogram or results_comparison)' -q --tb=short --junitxml=build/histogram-cache-2026-10-10/sqlite-final.xml`: **15 passed**, before the final added service-worker priority test. [Receipt](evidence/histogram-cache-2026-10-10/sqlite-final.xml).
- `-m pytest backend/tests/test_scalability.py backend/tests/test_worker_lifecycle.py backend/tests/test_histogram_snapshots.py -k 'not postgres' -q --tb=short --junitxml=build/histogram-cache-2026-10-10/worker-cache-final.xml`: final **40 passed, 6 skipped, 27 deselected**. Windows signal/POSIX and explicitly PostgreSQL-only cases are skipped by those fixtures. [Receipt](evidence/histogram-cache-2026-10-10/worker-cache-final.xml).
- `-m pytest backend/tests/test_test_drivers.py -k histogram -q --tb=short --junitxml=build/histogram-cache-2026-10-10/drivers-final.xml`: final **2 passed**, deduplicated all-driver comparisons, reset cutoffs and private-board isolation. [Receipt](evidence/histogram-cache-2026-10-10/drivers-final.xml).
- `build/histogram-cache-2026-10-10/owned_pg_final.py`: owned PostgreSQL **15 passed, 1 skipped**, then final request benchmark exit zero; generated container removed. The skip is the SQLite parameter of the PostgreSQL-only consistency test, not a missing PostgreSQL run. [Tests](evidence/histogram-cache-2026-10-10/postgres-final-tests.log), [benchmark](evidence/histogram-cache-2026-10-10/postgres-final-probe.log).
- `build/histogram-cache-2026-10-10/owned_pg_priority.py`: final PostgreSQL service-worker priority test **1 passed**, generated container removed. [Receipt](evidence/histogram-cache-2026-10-10/postgres-priority-tests.log).
- `-m ruff check backend/bmt_backend/histogram_population.py backend/bmt_backend/histogram_snapshots.py backend/bmt_backend/migrations/versions/0022_histogram_cache.py backend/tests/test_histogram_snapshots.py`: passed after correcting test imports.

The disposable runners use an already installed local postgres:17 image, unique owned containers, loopback connections and generated isolated schemas. They check ownership before cleanup; no remote service or real player records were changed. Probe source receipts retain their original execution directory under `build/histogram-cache-2026-10-10`.

Earlier broad SQLite domain coverage produced **30 passed and two failures**: the existing historical checkpoint-rule transition returns 409, and the native practice fixture cannot obtain its track validator in this launch environment. Both reproduce unchanged with the exact pre-task runtime modules in an isolated baseline package. [Current broad receipt](evidence/histogram-cache-2026-10-10/sqlite-broad.xml), [baseline](evidence/histogram-cache-2026-10-10/baseline-failures.log). They were not relaxed or fixed in this slice. An initial worker test run exposed the new background work changing single-race diagnostic return values; the service integration was separated and all unchanged assertions now pass. An initial selector accidentally included stale local PostgreSQL configuration; final PostgreSQL tests used the owned loopback database.

## Limits and remaining acceptance

This is a **local backend implementation**, not a deployment. Migration 0022 depends on the already existing local 0021 challenge migration; an authorized rollout must review that chain, back up existing records, migrate and deploy matching API/worker builds. First snapshots can be populated by the worker before client acceptance. No migration was run against the running backend.

No phone attachment check or device test, Android export/install, full Validate or production action was performed. No visible UI changes require new screenshots. Remaining acceptance: real-host load/memory and initial population, owner review of the proposed adaptive intervals, very large history refresh cost, and the two pre-existing broad domain failures. The source-only checkpoint excludes unrelated dirty workspace changes.
