# World Ranking backend requirements

Assessment of the [refined ranking specification](WORLD_RANKING_SPEC_2026_10_22.md), 23 October 2026.

The ranking fits the existing API, PostgreSQL and asynchronous worker architecture. Its additional computation is practical because it consumes already verified weekly PBs and publishes once a week. The main engineering requirements are bounded database work, safe publication and storage retention. It does not require another physics verifier, an all-player skill comparison, Redis or a separate ranking service at launch.

A local PostgreSQL prototype processed the core stages for one million weekly finishers and 26 million historical awards in approximately 71 seconds on one database CPU. This supports a weekly batch design. It does not establish that the currently deployed system can absorb that work alongside races.

## Workload and population

Capacity depends on activity and retained standings, rather than registered accounts alone:

| Symbol | Meaning | Work it drives |
| --- | --- | --- |
| E | Accounts entering this week's official Circuit, including incomplete entries | Eligibility extraction and up to five stored PBs per account |
| N | Accounts completing all five verified tracks this week | Five track classifications and N new weekly awards |
| H | Official awards inside the last 26 weeks | Best-12 and season selections |
| R | Accounts holding positive points inside that window | World/country snapshots and profile positions |
| A | Submitted official race attempts, including retries | Existing ticket/upload/verification capacity |

The measured cases use the same N accounts every week, so R equals N and H equals 26N. With turnover, R can be substantially larger than N: one million distinct finishers every week could leave 26 million ranked accounts after 26 weeks. That case was not benchmarked. Incomplete entrants also add work beyond the complete fields in the prototype.

The principal batch cost is approximately `O(5N log N + H log 26 + R log R)`, plus eligibility extraction, output writes and indexes. Five-track and world sorts dominate global ordering; each person's history is bounded at 26 results. Best 12 instead of best 16 reduces counting data slightly but does not remove the need to inspect reserves and expiry candidates.

## Work during racing

Reuse the existing official `RivalryBest` records and ticket bindings. Their data already includes the verified run, player, slot and canonical ticks. The shared Circuit needs a pinned week/lineup identity and authoritative resume policy, but ranking does not need to verify those same replays again.

A first or faster verified result updates a player's weekly PB. A slower/equal retry produces no additional world result. If implementation introduces a separate Circuit PB projection, update only that player's changed slot in the same accepted-result transaction. Avoid adding a second complete result history merely to rename the existing PB.

The existing [acceptance path](../backend/bmt_backend/rivalry.py) locks one small Rivalry group and computes that group's standings before and after an accepted run. Keep those groups small. Routing the world field through one shared `RivalryGroup` would serialize PB updates behind one lock and repeatedly load worldwide standings. A Circuit week can be shared metadata without becoming a globally locked score row.

Do not recalculate worldwide ranks, scan other players' histories or update a global entrant counter on every finish. Determine the frozen eligible population during settlement. The ranking contribution to ordinary racing should remain a player-scoped indexed update, or reuse of the already committed PB.

## Measured database computation

The [probe and SQL plans](evidence/world-ranking-backend-2026-10-23/probe.json) use disposable PostgreSQL 17.11, limited to one CPU and 1 GiB container memory. Settings include 128 MiB shared buffers, 16 MiB `work_mem`, disabled parallel query workers and a 180-second statement timeout. Tables and stage outputs are logged. The data is synthetic, with numeric work IDs, tied track times and typed arrays.

Each row below is one final observation, not a median or percentile:

| SQL stage | 10,000 finishers | 100,000 finishers | 1,000,000 finishers |
| --- | ---: | ---: | ---: |
| Five track placements | 0.067 s | 0.936 s | 10.221 s |
| Combine five placements | 0.029 s | 0.376 s | 3.447 s |
| Weekly positions and awards | 0.016 s | 0.201 s | 2.018 s |
| Best 12 from 26 weeks | 0.185 s | 2.039 s | 21.598 s |
| World and country standings | 0.028 s | 0.594 s | 16.333 s |
| Season best six and standings | 0.100 s | 1.466 s | 17.361 s |
| **Core stage execution total** | **0.43 s** | **5.61 s** | **70.98 s** |

The total includes writing those stage tables. It excludes initial eligibility extraction, creation of synthetic historical inputs, separate snapshot index construction, career processing and atomic publication. Snapshot index construction took an additional approximately 0.44/0.71/4.38 seconds of wrapper wall time. These results come from freshly generated data without foreground traffic; they are not cold-storage or full publication timings.

The 100,000 and million-finisher probes wrote approximately 74 MiB and 915 MiB of temporary data cumulatively across the measured stages. These are I/O totals, not peak temporary disk occupancy or peak RAM. A million-row, 50-entry page and a single-player lookup took 0.418 ms and 0.067 ms of database execution in their individual observations; HTTP, authentication, redaction and network time are excluded.

The complete history cardinalities, twelve counting results and world/season point ceilings passed the probe's checks at all three populations. This prototype does not implement production eligibility, job recovery or correction handling.

## CPU and memory allocation

Use one logical ranking job and at most one heavy ranking SQL stage at a time. At the measured million-finisher scale, even the approximately 71-second core total is small relative to a week. The important constraint is its interference with concurrent verification and API database queries.

Perform global ordering in PostgreSQL and stream or batch output. Do not load millions of ORM objects or all 26-week histories into the 768 MiB worker container. Keep a narrow score projection or covering index with player, week, award, worldwide place and result identity; keep the wider audit facts separate from the frequently scanned score columns. The compact history projection plus its player/week index occupied about 2.03 GiB at 26 million rows in the prototype.

PostgreSQL can spill sorts to temporary storage instead of retaining the complete population in memory. However, `work_mem` applies to individual sort/hash operations, and concurrent operations or sessions can multiply consumption. Set a bounded budget for the ranking connection and inspect its actual query plans rather than raising the database-wide setting. [PostgreSQL 17 memory settings](https://www.postgresql.org/docs/17/runtime-config-resource.html#GUC-WORK-MEM)

The repository's Compose database uses 4 MiB `work_mem`; this experiment used 16 MiB. The configured cloud worker has one CPU and 768 MiB, while the cloud database provisioner requests a separate one-vCPU database tier with 3,840 MiB memory. These are checked-in deployment settings, not an inspection of live resource usage. The experiment's database cap is not a measurement of the existing worker's spare RAM.

## Database storage

One steady weekly population produces:

| Weekly complete finishers | Qualifying track PBs per week | Awards in the rolling window | Award rows per year |
| --- | ---: | ---: | ---: |
| 10,000 | 50,000 | 260,000 | 520,000 |
| 100,000 | 500,000 | 2,600,000 | 5,200,000 |
| 1,000,000 | 5,000,000 | 26,000,000 | 52,000,000 |

A separate 100,000-row fact sample includes a 36-character player ID, five run references, five tick values, five placements, award, weekly position, contract hash, revision and three indexes. It occupied 66,166,784 bytes, or approximately **662 bytes per result including indexes**. Extrapolating that exact layout gives:

| Weekly complete finishers | Audited facts for 26 weeks | Annual facts if retained |
| --- | ---: | ---: |
| 10,000 | 0.16 GiB | 0.32 GiB |
| 100,000 | 1.60 GiB | 3.20 GiB |
| 1,000,000 | 16.02 GiB | 32.04 GiB |

These estimates exclude replay blobs, the existing game database, WAL, backups, staging generations, bloat and optional rank history. Shipping JSON fields, extra indexes and additional provenance can increase the footprint. The compact score projection would add approximately 2 GiB at the million-finisher density if stored separately from the audited facts.

The prototype's indexed current world/country snapshot occupied about 380 MiB per million entries with numeric player keys. Budget roughly 0.5–1 GiB per million entries for a shipping snapshot until its final schema is measured. Keep two hot generations; calculate movement from the previous one. Retain compact historical rank facts only where the UI or career reconstruction needs them, rather than retaining every wide snapshot indefinitely.

A planning allowance of roughly **20–30 GiB of ranking working data** at one million steady weekly finishers is reasonable for this compact design, before operational disk reserves and older archives. It is not a provisioned-volume recommendation. The checked-in disposable cloud provisioner requests only 10 GB with automatic growth disabled; that setting cannot hold the projected mature million-finisher result ledger alone.

Scoring expiry is not deletion. Define archive/privacy retention separately, and preserve enough facts to explain awards and rebuild corrections. Current maintenance can archive Rivalry PBs and release optional race evidence after the configured retention interval, normally 90 days. Integrate the new references with that process: the 26-week ranking must not depend on an accidentally deleted active source, or force every old replay blob to remain forever.

## Backend changes required

**Separate settlement from foreground work.** The main verification worker currently performs several maintenance tasks only when it finds no race job. A weekly ranking placed solely in that idle path can starve during sustained traffic. Give the ranking a durable job, a reserved bounded turn or supervised SQL-only runner, a lease and progress heartbeat. One replica owns a generation; other replicas must not repeat its heavy stages.

**Respect existing timeouts.** The current application database default is ten seconds per statement. Four million-finisher prototype stages exceeded that limit. Classify each track separately and process histories and output in player batches. Where a frozen global sort still needs longer, give only that ranking stage an explicit, bounded timeout and cancellation policy. Keep normal HTTP limits intact. Avoid one transaction spanning extraction, every sort and every output batch; a global sort may read the full immutable staging table within one bounded statement.

**Budget the database connection.** Use one ranking connection without overflow while doing SQL work. The staging validator already counts API, race, publication, discovery and optional product connections, including revision overlap. Its two-API/one-worker case without product work reaches the declared 40-connection planning budget. Adding a new supervised process must be included in that calculation; it cannot silently inherit a four-connection pool. Adjust allocations or database capacity based on the resulting budget.

**Publish an immutable generation.** Wait for all eligible pre-deadline accepted submissions to become terminal. Build weekly facts, world/country/season entries and career deltas behind a new generation. Commit output batches idempotently, then change one publication pointer. Serve the previous complete generation until that point. Verification backlog and contract recovery can delay publication independently of ranking CPU time.

**Keep reads bounded.** Profiles fetch stored positions; pages fetch 50 rows and around-player responses fetch nine. Use indexes tied to generation, sporting rank and stable row identity, with keyset cursors. A matching B-tree can return an ordered limited page without sorting the whole table. [PostgreSQL 17 ordered index scans](https://www.postgresql.org/docs/17/indexes-ordering.html)

Country positions are calculated with the weekly snapshot. Friend positions sort only the bounded authorized friend roster. Shared page caching must retain the established privacy/blocking checks. Do not run a global `COUNT` or a fresh world sort for each profile read.

**Make corrections background work.** Changing an eligible time can change other drivers' weekly places and awards. Rebuilding only the offender is insufficient. A correction may require reclassification and subsequent affected world/season snapshots across the award's 26-week lifetime, followed by source-based career rebuilding. Make that work restartable and publish its replacement atomically.

## Existing race verification capacity

Ranking arithmetic does not establish capacity for the races feeding it. The minimum is five completed races per finisher per week; actual attempts include retries and incomplete entrants.

| Weekly complete finishers | Minimum average completed races per second | Average if each finisher submits 20 races |
| --- | ---: | ---: |
| 10,000 | 0.083 | 0.331 |
| 100,000 | 0.827 | 3.307 |
| 1,000,000 | 8.267 | 33.069 |

Those are weekly averages. Deadline bursts can be much larger, and incomplete entrants add attempts. Size verifier slots using representative service times and peak arrival rates: `required slots >= peak races/second * mean service seconds / target utilization`. Measure the service time rather than borrowing the SQL ranking timings. Existing Rivalry racing already incurs that load; only additional racing induced by the ranking adds it again.

## Implementation decision and acceptance

Proceed with the existing stack and weekly materialized publication. At 10,000–100,000 complete weekly finishers, the measured arithmetic leaves substantial batch headroom; production acceptance still depends on concurrent traffic. At a million, storage lifecycle, bounded queries and foreground isolation become explicit design work, while the weekly score calculation remains tractable.

Before enabling public points, require representative PostgreSQL tests of eligibility extraction, partial completion and turnover; concurrent PB writes while settlement runs; killed/restarted workers and corrected generations; database connection exhaustion; memory and temporary-disk peaks; and profile/page latency under rollover demand. Establish publication and foreground-latency budgets before that test. Example initial goals are publication within five minutes of settlement at 100,000 finishers and fifteen minutes at a million, with no more than 10% foreground p95 latency regression; these are proposed acceptance budgets, not measured guarantees.

The [machine-readable assessment](evidence/world-ranking-backend-2026-10-23/report.json) records requirements WRB01–WRB04, source fingerprints, commands, calculations and limits. The initial synthetic million-player generator overflowed an integer multiplication; using bigint fixed it, and all three complete probes passed with the score bounds unchanged. Both owned containers were removed. This assessment changes no runtime code or live backend data and includes no device test or phone attachment check.
