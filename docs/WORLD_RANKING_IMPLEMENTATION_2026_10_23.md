# World Ranking implementation — 23 October 2026

The native client and backend implement the refined [ranking contract](WORLD_RANKING_SPEC_2026_10_22.md), using the [lean storage design](WORLD_RANKING_STORAGE_2026_10_23.md). Ranking settlement runs independently of race verification. Clients read completed generations; racing never waits for global ranking calculations.

This is a local, reviewable implementation. Migration, matching API/worker/client rollout, an announced prospective launch, production calibration and owner/device acceptance remain. No live service, account, device, purchase, APK or deployment was changed by this task.

## Implemented requirements

| ID | Result |
| --- | --- |
| WRI01 | One public Compact Circuit per UTC week, five pinned trusted official tracks, one entry per account/week, ordinary local skill groups retained. Three purpose-bound free resumes per official attempt; wallets, daily allowance and other racing retain their rules. |
| WRI02 | Numeric player mapping, narrow weekly awards, shared week metadata, compact private archives, temporary work tables and bounded retention. Reuse existing verified Rivalry PBs rather than duplicate a per-attempt ranking log. |
| WRI03 | Exact worldwide track places, five-track classification, ties/countback, field-scaled awards, best 12/26, best 6/13 seasons, expiry, reserves, qualifying career records and season honors. |
| WRI04 | Separate supervised SQL-only worker, one connection, leases, batch cursors, sort memory/query limits, cooperative pauses and foreground verification backlog guard. Atomic publication preserves the old ranking throughout preparation. |
| WRI05 | Authenticated World/Country/Friends/Season pages, nine-player neighborhood, bounded player breakdowns, current privacy checks, immutable cursor generations and ETags. |
| WRI06 | Demand-only native summaries, profile/leaderboard/results views, explicit Compact entry without changing Garage selection, official ceremony result/pending state, existing Garage trophy geometry for qualifying honors. Closing and account/safety changes remain responsive during requests. |
| WRI07 | Idempotent owner commands, separately rebuilt correction branches, auditable whole-week voids, restart/retry fencing, archive GC protection and preservation of unsettled PB evidence. |
| WRI08 | Production SQL pipeline probes at 100,000 and 1,000,000 synthetic players with concurrent HTTP reads and race-worker acceptance. See measured results below and the machine-readable evidence. |

## Sporting behavior

Only complete five-track, server-verified official Circuit results count. Free Race, private challenges, other cars and artificial/test populations cannot generate a Circuit award. Group placement and hidden skill matching do not affect worldwide points. No historical Rivalries are backfilled.

Within each track, equal ticks share the average occupied place, represented as an exact doubled integer. Compare the five-place sum, then the five sorted track places. Equivalent records share their sporting rank. IDs provide stable page order only.

At fields of at least 128, first/second/third earn 1,000/850/775 points; fourth and below use `floor(sqrt(56,250,000 / (place + 96)))`, with a minimum of one. Smaller fields scale by `(N−1)/127`, using integer arithmetic; a solo finish earns zero. Awards keep their earned value until expiry. The best 12 of the latest 26 calendar weeks count toward World Ranking. Compare tied totals by the sorted counting awards and then sorted weekly places, without an ID or recency sporting tiebreak.

Thirteen-week seasons start at launch; their best six results count. World Ranking continues through a season boundary. Top 100 and No. 1 week counters require at least 1,000 complete Circuit finishers that week. A season title requires six such qualifying weeks. Peak records retain their date and ranked population. Equivalent winners share honors. Permanent facts are versioned behind the same publication pointer and rebuilt after corrections.

## Responsiveness and resource boundaries

`world_ranking_worker` does not construct the web app or launch a canonical engine. Its PostgreSQL pool is one connection with no overflow; the supervisor gives its Python process Linux nice 19. Each step commits one bounded batch or one global SQL stage. Defaults are 2,000 players/batch, 16 MiB PostgreSQL work memory per sort node, no parallel query workers, a 30-second statement deadline, a 500 ms lock deadline and a 25 ms cooperative pause. Statement configuration is capped at 60 seconds. A runnable foreground race queued longer than 30 seconds defers the next ranking step.

This protects application pools and player/group locks. It does not reserve database CPU or eliminate shared I/O contention. Database capacity and API latency still need monitoring in production. A constrained sort can spill to disk or time out; the old snapshot remains served, and the worker retries from a committed phase. A persistent capacity problem must be addressed before public launch.

The initial million-player probe exposed a full-history `DISTINCT` member scan exceeding the existing 30-second limit. It was replaced with two indexed streams: previous snapshot members and current award recipients, merged in batches. Expired-only players are filtered by the subsequent bounded totals calculation. The final test keeps the original memory, CPU and statement limits.

All ranking reads use stored scalar positions. Pages return at most 50 players, around-player reads at most nine and profiles at most 26 results. Friends use the existing 100-relationship limit. Normal reads do not count or sort the worldwide population. Current and previous public snapshots support pagination across publication; older cursors require refresh.

The client has no ranking timer or authoritative local scoring. Profile reads coalesce, use an account/origin-scoped 60-second cache capped at eight entries, and allow at most four pending profiles. One page of rows is retained; page history is capped at eight cursors. Ten rows are constructed per frame. Close remains enabled during requests; stale account/safety responses are discarded. Ranking work does not enter the canonical driving step or race result acceptance transaction.

## Stored data and retention

The hot ledger contains only `(branch, circuit, numeric player, points, weekly place)`. Keep the scoring window plus two publication/recovery weeks, rather than full lifetime SQL awards. Keep current/previous standings and a bounded base/current career version; sparse inactive career facts survive points expiry. Batch-delete temporary work and Circuit entry rows after publication. PostgreSQL autovacuum and free-disk monitoring remain necessary: deletion makes allocated work pages reusable rather than immediately shrinking files.

Cold chunks contain at most 10,000 records; default chunk size follows the 2,000-player batch. Each weekly record is 36 binary bytes: numeric key, five verified ticks, worldwide weekly place, points and historical country. Each world record is 16 bytes: key, position, total and country. These are base64-wrapped in a small versioned JSON envelope and use the existing content-addressed gzip object store. The extra country bytes preserve historical country during correction replay. No ranking replay/input stream or copied ghost is stored.

Archive digest references participate in both offline and online object GC checks. A Circuit without a first completed snapshot prevents ordinary 90-day Rivalry archival from deleting its still-needed PB inputs. Account removal keeps redacted sporting results under the existing historical-score policy; public IDs, names and country are masked immediately, and blocked profiles are inaccessible. A later removal does not silently alter a valid field. Audited sporting exclusions remain separate.

Corrections can temporarily require an additional ledger/work population while the old public branch remains readable; repeated corrections can retain the current/previous branches alongside the rebuilding branch. Provision this recovery headroom separately from steady-state storage. Older immutable sporting archives continue to grow with participation, at the compact per-week rate.

## APIs and operator commands

| API | Purpose |
| --- | --- |
| `GET /v1/ranking?scope=world|country|friends|season` | 50-row generation-bound cursor page; optional `country`, `cursor`, `around=true`. |
| `GET /v1/ranking/me` | Published own positions, points, earned/net movement, counting/reserve results, next expiry risk and career facts. |
| `GET /v1/ranking/players/{uuid}` | Privacy-aware public player breakdown. |
| `GET /v1/admin/ranking/status` | Existing staff authentication; launch, published snapshot, current phase/cursor, retries and error kind. |
| `POST /v1/admin/ranking/corrections` | Owner only: disqualify one Circuit entrant or void a whole week with an audited reason. |

A correction includes a UUID `command_id`, `expected_snapshot`, `circuit_id`, an eight-character-or-longer `reason`, and exactly one of `player_id` or `void_week: true`. Reusing the same command is idempotent; changed payload reuse conflicts. Publication must be idle before accepting it. Published corrections replay archived inputs through a separate branch and switch only when the complete replacement is ready. Commands do not accept arbitrary replacement client times. A closed unavailable first week can be voided before its first snapshot with `expected_snapshot: 0`. The owner status endpoint supplies its Circuit ID.

Updated schemas: [ranking](schemas/world-ranking-v1.schema.json) and [Rivalry](schemas/weekly-rivalry-v1.schema.json). Bootstrap advertises ranking version and launch week; native official entry stays disabled before the announced opening.

## Rollout

1. Back up the database and objects using the established release workflow. Apply `0059_world_ranking` after `0058_challenge_series`; the migration is additive and leaves existing rows intact. Downgrade refuses to discard populated ranking history.
2. Ship matching API, supervised workers and native client. Keep `BMT_WORLD_RANKING_LAUNCH_WEEK=0` until a launch is declared. Configure the same future Monday 00:00 UTC epoch on API and workers before opening. Initialization makes this launch immutable; changing it later is not a season reset.
3. Use the existing four-week planner to prepare five published trusted official Compact tracks and a matching pinned verification contract. Incompatible contract changes belong between weeks. Opened Circuit slots remain frozen; a critical unavailable event requires an owner-audited void.
4. Review connection budgets with the added single ranking connection per worker replica, including revision overlap. The existing GCP staging validator rejects an enabled configuration that exceeds its 40-connection budget; no larger instance or recurring cost is provisioned by this implementation. Drain old incompatible writers before opening.
5. Exercise publication/restore/correction on representative staging data; monitor API p95, foreground queue age, ranking progress, disk/temp space, autovacuum and oldest unpublished week. Accept native flow and sustained device performance before public activation.

## Validation and evidence

| Local PostgreSQL probe | 100,000 players | 1,000,000 players |
| --- | ---: | ---: |
| Weekly award rows | 2,600,000 | 26,000,000 |
| Settlement plus cleanup | 85.8 s | 1,120.8 s (18 min 41 s) |
| Ranking page median / p95 during work | 19.3 / 88.5 ms | 18.5 / 55.2 ms |
| Profile median / p95 during work | 20.8 / 57.7 ms | 18.2 / 99.2 ms |
| Ranking SQL allocated, including reusable work pages | 0.36 GiB | 3.22 GiB |

Both probes used one ranking connection and PostgreSQL limited to one CPU, 2 GiB memory, 128 MiB shared buffers and 16 MiB work memory. The 100,000-player run precedes the member-scan refinement; do not interpret the table as a controlled speedup comparison. The final million-player run made 2,183 samples per read endpoint and accepted 2,182 foreground races through the real HTTP/worker flow with FakeVerifier. Readers observed only the old or completed new snapshot. The largest global SQL stage took 10.67 seconds; pointer publication took 18.8 ms.

At one million, retained ranking/map/career/standings allocation was 2.71 GiB, plus 0.51 GiB reusable work-table allocation. The award ledger alone was 2.03 GiB. This excludes existing player/race storage, cold object bytes, WAL/backups and correction headroom; the seeded probe has one career generation rather than the complete steady-state pair. Cumulative database temporary-file traffic was 1.00 GiB, not a measurement of peak temporary disk. The combined pytest/API/worker test process peaked at 186.2 MiB RSS, 52.1 MiB above its pre-settlement high-water mark; this is not an isolated worker RSS measurement.

Foreground latency has outliers under the shared single-CPU limit: country page maximum 824 ms, and synthetic end-to-end race acceptance p95 420 ms / maximum 1,247 ms. Baseline reads contain only five samples and include cold outliers. These results establish bounded functional operation and useful local timings, not zero contention, canonical verification throughput, network latency, DAU capacity or a production SLO.

A separate final retention probe seeded 3,000,001 interleaved career rows for one million players plus an inactive player. Cursor-based pruning retained the correct 2,000,001 rows in 31.45 seconds / 1,002 bounded steps. This specifically checks the steady-state three-generation case absent from the first large pipeline seed: each batch advances across player keys rather than repeatedly scanning an increasing prefix of retained versions. Obsolete branch cleanup likewise probes retired branch IDs rather than scanning protected award populations. The inactive player's permanent facts remain intact.

The [evidence directory](evidence/world-ranking-implementation-2026-10-23/) contains original source captures, frozen-source PostgreSQL receipts, JUnit XML, native renders, failure controls, aggregate performance records, commands and a scoped Git-checkable patch. The final [report](evidence/world-ranking-implementation-2026-10-23/report.json) records exact source hashes and outcomes; it is authoritative for final numerical results.

Backend checks include exact points at solo/127/128/1,024 boundaries, mixed track ties and row-order independence, reserves/calendar expiry, best-six season co-champions, prestige counters, archive failure/restart, delayed verification, foreground backlog yield, simultaneous correction retries, worker lease exclusion, privacy/ETag updates, GC and preservation of all previous-schema table rows. A real canonical three-rewind regression is separate from FakeVerifier HTTP acceptance.

Native checks cover cache bounds and coalescing, stale-response/account fences, explicit Compact entry while preserving the Garage car, one-page navigation, close during a held request, career-driven Garage trophies and prestige removal after corrected facts. Graphical evidence uses desktop Compatibility and desktop Mobile renderers, including 390×844 and 430×932 windows; these are not physical Android device or FPS measurements.

Native captures: [desktop ranking](evidence/world-ranking-implementation-2026-10-23/native-gl_compatibility.png), [390×844 Compatibility](evidence/world-ranking-implementation-2026-10-23/native-gl_compatibility-390x844.png), [430×932 desktop Mobile](evidence/world-ranking-implementation-2026-10-23/native-mobile-430x932.png).

Retained broader regressions: one Rivalry detail “six more drivers” assertion and three publication-retry assertions reproduce with the captured original shared client files. Their assertions remain unchanged. Initial Windows sandbox certificate/userdata failures, an isolated trophy fixture missing Garage mode, encoding correction, the initial SQL integer-overflow fix, the member-scan timeout and corrected test setup remain documented in the raw evidence. No planned test is represented as passed.
