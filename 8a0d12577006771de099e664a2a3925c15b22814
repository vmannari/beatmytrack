# Request-path review evidence — 6 November 2026

Review only. No shipping edits, deployed database queries, live HTTP requests, native game/device runs, or deployment by this subtask. Concurrent Daily preparation files were inspected and preserved. The timings below are synthetic, in-memory SQLite component measurements, not PostgreSQL plans or live latency.

## P1: Permanent appearance rejection repeats while the edit remains unchanged

`game/backend/appearance_sync.gd:24` configures a 30-second poll. `refresh()` always starts with a GET at line 92, persists the pending local value at lines 133–136, then PUTs at line 137. The result branches at lines 139–153 clear pending only on success, re-read a conflict, or display an ownership error. A 422 falls through to the generic retry branch, preserving the same local value and previous baseline. `_needs_recovery()` at lines 55–61 remains true for any pending value, and the poll therefore remains active at line 162. There is no terminal validation-rejection state, fingerprint suppression, exponential backoff, or retry ceiling. The `break` at line 153 also prevents later vehicle edits in the same pass from syncing.

The server accepts `SaveAppearance` with strict nested catalog validation (`backend/bmt_backend/appearance_routes.py:13`, `vehicle_appearance.py:12`, `:70`, `:83`). Request-validation failure returns HTTP 422 with `INVALID_INPUT` (`app.py:109`); an explicit current/previous vehicle mismatch also returns 422 (`appearance_routes.py:46`). The client transport returns 422 unchanged; it has no retry loop for this status (`backend_client.gd:981`). Repetition originates in appearance sync scheduling.

Root-agent live evidence finds 1,468 PUT 422s on this endpoint, median service time 42.5 ms, with a cross-client median interarrival gap of 10.16 seconds and only 129 gaps of 29–31 seconds. The observed aggregate is **not** proof of one client's 30-second timer. This source review establishes the retry mechanism but does **not** identify the live rejected field, vehicle, payload, device, or source revision. These require a sanitized reason-code/schema-version observation rather than logging raw private payloads. Recommended remedy: preserve the local edit, suspend repeat delivery of an identical permanent rejection until the edit or supported catalog/contract changes, retain bounded backoff for transient failures, and do not block independent car operations. The existing ownership-error branch also retains the poll.

## Withdrawn: missing Daily lap ordering index

The initial `probe_requests.py` constructed ORM tables without executing migrations. Independent review found that migration `0038_garage_news.py:67` already creates `ix_news_lap_rank(board_id,time_ticks,player_id)`. A complete Alembic upgrade in `probe_migrated.py` confirms that exact index exists. **The missing-index finding is invalid and withdrawn.** Its initial timings and plans remain in `probe-results.json` with an explicit rejected-baseline disposition; they must not be cited as shipping schema performance. No index migration is recommended from this review.

The same initial fixture also omitted migration 0008's `ix_published_track_revision(state,track_id,number)`. All original own-track timings are excluded; the corrected full-migration check below supersedes them.

## P2: Profile publication pages depend on unrelated catalog size and perform per-track reads

The current Profile requests `/me/tracks?heads=true&profile_stats=true&limit=12` (`game/ui/own_profile_page.gd:631`). `tracks.py:180–190` builds its latest-version aggregate across every track before restricting the outer query to the owner. `_payload()` at lines 94–97 then issues an individual `Track` lookup for every result.

The **fully Alembic-migrated** `my_tracks()` probe returns 12 owned publications in both fixtures. It executes 15 SQL statements including one player load used to model the already authenticated caller, the main page, 12 Track reads, and one finish-count aggregation. With no unrelated tracks its median is 17.803 ms; with 50,000 unrelated tracks it is 184.493 ms (five samples, noisy concurrent desktop execution). The corrected SQLite plan uses `ix_published_track_revision` for the global aggregate, with no temporary GROUP BY sort; it still visits other owners' published versions and uses a final ORDER BY sort. These component observations establish query amplification and population sensitivity, not a production latency estimate or PostgreSQL plan. A joined owner-scoped latest-version query and joined/batched Track payload assembly are the direct candidates; PostgreSQL EXPLAIN ANALYZE and fixture result equality should gate any implementation.

## Existing strengths and limits

Public race leaderboards already use persistent time counts and bounded indexed windows. Histogram responses use generation-keyed, weighted immutable caches and bounded demand coalescing. Profile finish counts use SQL grouping rather than loading one ORM object per run; however aggregation still scales with retained race history. Daily snapshot prewarming exists as concurrent uncommitted work and is not treated as a missing feature here.

Commands:

```powershell
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/request/probe_requests.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/request/probe_migrated.py
```

The first probe completed computations but failed to serialize SQLAlchemy plan rows; tuples fixed the evidence serializer only. The second invocation completed and wrote `probe-results.json`, but independent schema review invalidated its missing-index conclusion as above. `migrated-results.json` records the actual migrated lap indexes and corrected profile plans/samples. Its redirected PowerShell wrapper returned exit 1 because existing SQLAlchemy reflection warnings became `NativeCommandError`; Python reached the end, wrote the complete JSON and printed it, without a traceback. The warning and wrapper status are retained in `migrated-stdout.log`; this is not presented as a clean command pass. No performance assertion was loosened.

Existing `test_profile_statistics.py` and `test_daily_lap_standings.py` initial invocation: **9 passed, 5 skipped, 4 setup errors**. Every error was the configured local PostgreSQL connection timeout at `localhost:55439`; SQLite passed. Initial test output is retained in `focused-tests.xml` with local database credentials redacted. The SQLite-only focused repeat **passed 9, deselected 9**, with 46 pre-existing expression-index reflection warnings, in 36.99 seconds (`focused-sqlite.xml`, `focused-sqlite.log`). No PostgreSQL performance or behavior pass is claimed.
