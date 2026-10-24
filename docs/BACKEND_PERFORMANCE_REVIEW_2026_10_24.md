# Backend performance and scaling review

Reviewed 24 October 2026. Requirements BPR01 performance, BPR02 capacity and resources, BPR03 costs, BPR04 storage and operational readiness, and Q01 evidence.

**Correction on 24 October:** the original verification fleet and resulting cost forecast used a superseded native proof/full-replay path. Current acceptance is a Python trajectory check with no full-replay fallback. Those fleet and forecast figures are withdrawn. A fresh current-source benchmark measures 1.766 ms median/3.003 ms p95 for the prepared adapter. The original review/model remain archived for accountability; the [cost reduction plan](BACKEND_COST_REDUCTION_PLAN_2026_10_24.md) defines a proposed €1,800/month ceiling at one million daily players and the changes/tests required to pursue it.

**The backend has a credible architecture for growing an asynchronous racing game, but its current deployment is a small development service. It has no demonstrated capacity for a million daily active players.** The largest costs at that scale are likely to be accumulated race and financial history, data delivery, verification capacity, and PostgreSQL operation. The compact World Ranking implementation is comparatively inexpensive.

The current staging allocation has room for its observed traffic. Its worker is much closer to its CPU and memory limits than the API. Increasing API replicas alone would leave worker throughput, shared database connections and several write bottlenecks unresolved. A public launch needs measured arrival rates, explicit retention and recovery policies, and a sustained test of the exact production image.

The financial scenarios below use official regional EUR catalogue prices retrieved on 24 October. They deliberately include paid infrastructure after credits expire. They are engineering calculations under stated activity assumptions, rather than quotations or upper bounds on a future bill.

## Current deployment and observed load

Read-only Google Cloud inspection at approximately 10:37 Helsinki confirmed the following in `europe-west1`:

| Component | Actual configuration | Previous 24 hours |
| --- | --- | --- |
| API | 1 vCPU, 1 GiB per instance; service minimum 1, maximum 2; HTTP concurrency 16 per instance | Weighted sampled CPU mean 1.33%; maximum sampled distribution mean 28.3%; memory maximum sampled mean 334 MiB |
| Worker pool | One manually allocated instance, 1 vCPU and 768 MiB | Weighted sampled CPU mean 57.2%, with saturation samples; memory mean about 562 MiB, maximum sampled mean 659 MiB |
| PostgreSQL | Zonal `db-custom-1-3840`: 1 vCPU, 3.75 GiB RAM | CPU sample mean 19.6%, maximum 25.9%; memory maximum about 1.39 GiB; maximum aligned connection sum 12 |
| SQL disk | 10 GiB SSD, automatic growth disabled | Maximum reported used disk 497 MiB |
| Objects | Private regional Standard GCS bucket; seven-day soft delete; no bucket lifecycle policy returned | No current object-byte inventory was requested |
| Recovery | Seven retained daily SQL backups; deletion protection enabled | Point-in-time recovery and transaction-log archiving are disabled |
| Analytics | No reporting database configured; only one SQL instance exists | Broad Studio behaviour reports deliberately remain unavailable |

The complete request-count query returned **5,115 requests over 24 hours**, approximately 0.059 requests/second averaged over the day. The separately sampled request-latency distributions contain 5,126 observations with a weighted mean of 80.2 ms. These are different provider metric series with different reporting timing; the count difference is retained. They include administrative, health, conditional and failed responses. They do not establish game-endpoint p95, mobile latency or an availability SLO. The count includes 70 HTTP 503 responses and 475 HTTP 404 responses; their causes were not established by these aggregate metrics.

Utilization values are monitoring samples and distribution means, rather than instantaneous maxima. Quiet average API CPU cannot establish maximum-body memory safety or burst capacity. Development drivers and telemetry are enabled; this workload does not represent a production player population. The worker memory result supersedes the much smaller observed footprint in the 6 October cost review: reducing it to 512 MiB would be inconsistent with the current observations.

API and worker still use image `sha256:c126c96c221a621e16165d55c9286bb0ea838e8c539fc9b20cd7ac51dda6b53c`. The last verified release is schema 0057. The workspace also contains 0058 challenge series and 0059 World Ranking; their presence is not evidence of a live rollout. The cloud inspection did not query the database schema directly or change configuration. [Current inventory](evidence/backend-performance-review-2026-10-24/cloud-inventory.json), [complete metric summaries](evidence/backend-performance-review-2026-10-24/cloud-metrics.json), [last deployment evidence](LATEST_BACKEND_DEPLOY_2026_10_23.md).

## Architecture and existing scaling strengths

Driving and rendering run on the player's device. The backend handles identity, discovery, starts and uploads, asynchronous verification, records, competition, rewards, purchases and reporting. Adding a player does not add a continuous 120 Hz server simulation. Capacity follows HTTP activity, completed attempts, content downloads and retained data.

FastAPI services can be replicated. PostgreSQL is the shared transactional authority, and proof, ghost and track documents use compressed content-addressed object storage. A worker accepts ordinary races through a small Python trajectory pass. Native processes prepare cold static geometry and support explicit offline diagnostics; they do not replay each accepted race. Durable jobs, leases and idempotent receipts allow retries without duplicating results or rewards. These are appropriate foundations for this game.

Recent changes materially improve the read and background paths:

| Area | Current behaviour and scaling benefit |
| --- | --- |
| Discovery | Indexed projections and frozen cursor views avoid constructing a complete catalogue per request. Twenty-item pages retain current account/content authority checks. Short-text indexes, work credits, deadlines, receiver limits and bounded retained collections prevent unlimited individual work. |
| Leaderboards | Stored population counts, bounded time-prefix counters and a compressed tie tree avoid counting every faster player for each normal rank lookup. Keyset cursors bound ordinary page traversal. Legacy numeric offsets remain bounded at 10,000. |
| Histograms | Packed tick/frequency arrays depend on distinct tick values, rather than retaining every driver's Python row. Shared snapshots refresh in the background; conditional HTTP responses reduce repeated bodies. |
| Race acceptance | Creator-achievement effects are durable and reduced later, removing the previous creator-wide lock from the acceptance transaction. Rivalry matching uses bounded open-group candidates. |
| Telemetry | Durable intake and analytical ownership are partitioned. Separate actor/shared/rollup stages avoid holding one global analytical state row during every batch. |
| Background scheduling | Publication, discovery and optional telemetry have separate supervised processes. Presentation jobs receive reserved turns during continuous racing. |
| World Ranking | SQL-only settlement uses one connection, bounded phases and atomic generations. Readers continue to see a complete published generation while the next one builds. |

The former full-catalogue limit, per-driver histogram allocation, global telemetry projection lock and closed-group scan should not be repeated as current unfixed findings. Current code and the later fix receipts supersede those earlier reviews. [Previous review](evidence/backend-scale-review-2026-10-23/review.json), [follow-up fixes](evidence/backend-scale-other-fixes-2026-10-23/report.json), [discovery guards](evidence/discovery-resource-fixes-2026-10-23/report.json).

## Measurements and response times

| Evidence | Measured result | What the measurement establishes |
| --- | --- | --- |
| Latest discovery resource probe, 23 October | New view 305.8 ms and 27 SQL statements; 25 twenty-item pages had median 47.2 ms and maximum 98.0 ms, with 17–20 statements per page | Local synthetic 5,001-track PostgreSQL/TestClient behaviour. No cloud/network or sustained traffic claim. |
| World Ranking, 23 October | One million players and 26 million awards settled and cleaned in 1,120.8 s; ranking-page median/p95 18.5/55.2 ms, profile median/p95 18.2/99.2 ms | Local PostgreSQL constrained to one CPU/2 GiB. Foreground acceptance used FakeVerifier. Ranking-page latency does not establish complete race-pipeline capacity. |
| World Ranking foreground outliers | Country-page maximum 824 ms; synthetic acceptance p95 420 ms, maximum 1,247 ms | Shared database CPU can still delay foreground work. The old suggested fifteen-minute million-player settlement goal is not met by the 18.7-minute probe. |
| Telemetry, 22 October | One process 2,313 events/s versus four processes 2,638 events/s for uniform traffic; hot-context results 1,718 versus 2,297 events/s | Short 4,000-event drains under a two-CPU diagnostic limit, without concurrent HTTP ingestion or gameplay. Four processes delivered 1.14–1.34 times throughput, not four times. |
| Current trajectory verification, 24 October | Prepared adapter median 1.766 ms, p95 3.003 ms, maximum 3.677 ms over 500 calls; zero engine calls during acceptance | Fresh current-source local computation test over a 2,130-sample five-lap fixture. Excludes queue, SQL, storage, decoding and network. |
| Historical HTTP lab, 5 October | 100,000-player fixture completed 77.5 requests/s with endpoint p95 approximately 156–188 ms | Earlier code and a fifteen-second local read test. The subsequent substantial implementation changes prevent treating this as current capacity. |
| Historical overload control | 46 HTTP 503 responses, 550 dropped arrivals and 3.09 s scheduled p95 | The load lab detects overload; completed throughput alone conceals unmet demand. |

Sources: [discovery timings](evidence/discovery-resource-fixes-2026-10-23/profile-result.json), [ranking experiment and qualifications](WORLD_RANKING_IMPLEMENTATION_2026_10_23.md), [telemetry benchmark](evidence/telemetry-parallelism-2026-10-22/report.json), [current verification measurement](evidence/backend-cost-reduction-2026-10-24/trajectory-current.json), [trajectory contract](TRAJECTORY_VERIFICATION.md), [historical read report](evidence/backend-scalability-2026-10-05/postgres-100k.json), [overload report](evidence/backend-scalability-2026-10-05/overload.json).

A player's confirmation time includes upload, admission, queue wait, object reads, trajectory checking, SQL finalization and result delivery. Checker computation is only one term. The app can show local results immediately while this completes. Long polling reduces some completion delay, but defaults to four waiters per API process; it still occupies HTTP concurrency and has a polling fallback. Keep queue age and confirmation latency separate from API request latency.

Proposed initial acceptance goals are warm ordinary reads below 200 ms server p95 and 500 ms p99, upload acknowledgements below 500 ms p95 excluding upload transfer, ordinary proof confirmation below two seconds p95/five seconds p99, and stable background freshness during peak gameplay. Explicit offline replay diagnostics need a separate budget. These are proposed targets. Worldwide mobile network time, maximum uploads, cold starts and intentional long waits need separate budgets. Retain the warm API floor: an earlier cold first Rivalry request took approximately sixteen seconds.

## Activity model and capacity calculations

Registered accounts determine identity storage; daily active users determine daily work; peak concurrent players and action timing determine bursts. One million registered accounts with 10,000 daily players is a very different deployment from one million daily players.

The illustrative workload assumes ten accepted races, 150 API requests, 100 client telemetry events and thirty minutes of use per daily player. The busiest period is five times the daily average. Downloads average 5 MiB per daily player after client caching. These activity inputs were not measured in production. Current verification uses the Python trajectory path; the earlier 0.14/1.06-second mixture and 10% fallback assumption do not describe it.

| Daily active players | Illustrative peak players online | Average / peak API requests per second | Average / peak race verifications per second | Peak client telemetry events per second |
| --- | ---: | ---: | ---: | ---: |
| 10,000 | 1,042 | 17 / 87 | 1.2 / 5.8 | 58 |
| 100,000 | 10,417 | 174 / 868 | 11.6 / 57.9 | 579 |
| 1,000,000 | 104,167 | 1,736 / 8,681 | 116 / 579 | 5,787 |
| 10,000,000 | 1,041,667 | 17,361 / 86,806 | 1,157 / 5,787 | 57,870 |

For one million daily players, the arithmetic is ten million accepted races/day and 4.5 billion API calls per thirty-day month. Server-generated telemetry is additional to the client-event column. Synchronised event endings, launch publicity or unusually concentrated geography can exceed the fivefold factor.

The current prepared checker takes approximately 1.766 ms median in the fresh local fixture. Multiplying that by peak arrivals and dividing by 60% utilization gives a theoretical single-core-equivalent computation budget. It does not size the complete worker pipeline or measure fleet CPU:

| Daily active players | Median checker equivalents at peak and 60% utilization | Illustrative peak API vCPUs at 5–20 ms CPU/request | Primary PostgreSQL test envelope | Reporting replica test envelope |
| --- | ---: | ---: | --- | --- |
| 10,000 | 0.017 | 1–3 | 2–4 vCPUs, 8–16 GiB RAM | 2 vCPUs, 8 GiB |
| 100,000 | 0.17 | 8–29 | 8–16 vCPUs, 32–64 GiB RAM | 4 vCPUs, 16 GiB |
| 1,000,000 | 1.70 | 73–290 | 32–64 vCPUs, 128–256 GiB RAM | 8 vCPUs, 32 GiB |
| 10,000,000 | 17.0 | 724–2,894 | Requires a separate measured partitioning/topology design | Dedicated reporting and analytical capacity |

**These are candidate test allocations, not supported-player ratings.** API CPU/request is an assumption. The checker measurement excludes additional decoding, I/O and finalization costs. The database envelopes are conservative engineering starting points with no measured CPU-per-transaction calibration; they are not demonstrated minimum requirements. They may be insufficient with popular boards, heavy telemetry or poor locality, or substantially oversized after the data/request reductions in the cost plan.

Do not allocate one CPU merely because one race is waiting on storage or SQL. The number of concurrent in-flight jobs and their actual CPU consumption are different quantities. Current process/queue implementation still needs throughput testing, bounded I/O concurrency and role-specific resource limits. Database cache memory follows active indexes and frequently accessed rows, not every registered account. PostgreSQL CPU sizing also depends on write-ahead log generation, storage IOPS and commit latency.

The local NAS/PC Compose template declares approximately 2.4 GiB across database, proxy, API and worker container limits, before the operating system, filesystem cache and other applications. This is a small-host configuration, with no measured public NAS capacity or independent host failover. A home uplink, power supply and single storage host introduce additional availability and download constraints. [Compose resource limits](../backend/deploy/compose.yaml).

There is no ordinary full-replay fallback to model. Measure longer trajectories, rewinds, creator validation, cold geometry and retries through their actual paths. The old 136/224/579/1,023-engine sensitivity figures are withdrawn; they came from a superseded acceptance policy.

## Remaining bottlenecks and operational risks

| Priority | Finding | Consequence and next step |
| --- | --- | --- |
| High | Fixed verification allocation and shared worker CPU | One pool instance supervises verification, publication, discovery and telemetry processes within the same 1 vCPU/768 MiB. Process separation does not reserve CPU or memory. Separate their deployment resources when measured contention requires it; scale verification from oldest job age and arrival/drain rate. |
| High | Database connection budget | API pools have four connections and no overflow. Each worker replica can add two verification connections plus one each for publication, discovery and telemetry; enabled ranking adds another. Two APIs plus four such worker replicas already reserve up to 28–32 connections before operations and transient deployment overlap, against a limit of 40. Recalculate all pools and test a suitable pooler/topology before scaling. |
| High | Combined admission lanes do not guarantee a spare gameplay connection | With a four-connection API pool, telemetry and small discovery each permit up to three concurrent operations through independent semaphores. Their combined allowance can exceed the pool; notification listeners and ordinary traffic also use it. A per-lane cap does not create a global reserved connection. Stress these lanes together before deciding whether shared admission or separate bounded pools are needed. |
| High | Popular-board writes still share rows | PB triggers update board counts/revisions and time/tie indexes transactionally. Different players improving on the same board can wait on shared rows until the acceptance transaction commits. Bounded rank reads do not remove this write serialization. Measure one very popular board, shared ties and multi-car tracks; collect lock-hold time and waiters. The serialization point is source-confirmed; its production throughput threshold is unmeasured. |
| High | Permanent receipts grow with total attempts | `CoinReward`, earned `StudioCoinEntry` rows and compacted server `ProductEvent` receipts survive ordinary race pruning. Their total does not become bounded merely because runs have a ninety-day retention option. Establish compact durable replay fences and archive policies without allowing duplicate fulfillment. |
| High | Retention requires an operating schedule | Reference-aware race/object retention is opt-in and resumable. No bucket lifecycle was configured, and this inspection did not establish a recurring race-retention job. A configured `retention_days=90` is not proof of deletion. Monitor age, candidate arrivals, batch completion and protected references; keep deletion ownership and retry guarantees. |
| High | Fixed disk and limited recovery | Automatic SQL growth is disabled, there is no regional failover, and PITR is disabled. Daily backups alone can leave nearly a day's database changes unrecoverable after a destructive loss. Adopt explicit RPO/RTO targets and rehearse database/object recovery before launch. |
| Medium | Telemetry parallelism is not linear | The measured four-process speedup was only 1.14–1.34 times. Shared semantic contexts intentionally have one reducer, and the primary still pays for analytical writes and WAL. Tune event volume and measure sustained ingestion with gameplay; use a dedicated analytical system if the primary remains the bottleneck. |
| Medium | Bounded queues provide little large-scale burst time | At the model's million-player peak, 128 verification slots equal only 0.22 seconds of incoming races; 50,000 client-event backlog credits equal 8.64 seconds of client events. Bounds protect the service but cause throttling when consumers stall. Size backlog from tolerated outage time, durable client retries and measured storage. Increasing it does not increase processing rate. |
| Medium | Near-full queue admission can reject early | A preflight probes at most 64 slots. With one vacancy in capacity C, success is only `min(64,C)/C`; final allocation also searches a finite slot domain. A vastly enlarged slot pool needs a measured redesign, rather than a configuration increase alone. |
| Medium | Ranking and reporting share infrastructure costs | Ranking has low-priority scheduling and a foreground-age guard, but no database CPU reservation. Analytics is correctly blocked without its required physical standby. A full reporting replica replicates all primary data and consumes disk/WAL bandwidth; it does not reduce primary analytical projection writes. |
| Medium | Read amplification, retries and logging | Current discovery pages take 17–20 SQL statements. One thousand such pages/s means 17,000–20,000 statements/s before other activity. Lost completion hints fall back to polling. Structured request logs at 4.5 billion calls/month can also generate terabytes of billable logs. Budget SQL work, retry traffic, cache hit rates and log ingestion independently. |

Relevant source boundaries: [supervisor](../backend/bmt_backend/service_worker.py), [database pools](../backend/bmt_backend/db.py), [request admission](../backend/bmt_backend/middleware.py), [PB projection triggers](../backend/bmt_backend/migrations/versions/0013_scalability.py), [rank triggers](../backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py), [reward receipts](../backend/bmt_backend/economy_models.py), [financial entries](../backend/bmt_backend/studio_finance.py), [telemetry expiry](../backend/bmt_backend/telemetry_processing.py), [retention](../backend/bmt_backend/maintenance.py), [reporting isolation](../backend/bmt_backend/studio_reporting.py).

Existing limits also need legitimate-traffic testing. Discovery retains at most sixteen million charged collection members/four GiB of charged member storage across sixteen service stripes. These are logical accounting bounds, not PostgreSQL heap/index/WAL measurements; one stripe can fill before the service total. Bulk personal-list uploads and large shared-network guest populations must receive usable retry behaviour under the intended load. Published tracks remain immutable and retained, so content growth is a separate permanent budget.

## Storage and retention requirements

The following are **assumed physical-size ranges**, rather than measurements of the live tables or average replay sizes. They expose the order of magnitude and identify which measurements matter next.

| Storage category | Assumption | At one million daily players doing ten races/day |
| --- | --- | ---: |
| Ordinary race/ticket/job SQL history, excluding permanent receipt bundle | 2–6 KiB per accepted race, ninety days | 1.68–5.03 TiB |
| Permanent reward, finance and compact server receipt bundle | 1–4 KiB per accepted race, one year | 3.40–13.60 TiB, then continues growing |
| Replay and ghost objects combined | 20–100 KiB compressed per accepted race, ninety days | 16.76–83.82 TiB before protected older objects and soft-delete recovery |
| Raw client telemetry | 100 events/day/player, 1 KiB each including SQL/index allowance, eight days including expiry grace | 763 GiB |
| Per-player daily analytical facts | One 1 KiB row/day/player, 180 days | Another 172 GiB for each such daily context; session and multiple-context facts add more |
| World Ranking | Actual one-million-player/26-million-award experiment | 3.22 GiB SQL allocated, including reusable work pages; excludes other gameplay tables and full steady-state correction headroom |

The permanent bundle estimate includes several receipt classes collectively. It must be replaced with measured `pg_total_relation_size` deltas on accepted races; row-count conservation and permanent receipt semantics must survive any compression. At this activity level the game generates 3.65 billion accepted results/year, so even 100 additional physical bytes/result cost about 340 GiB/year before replicas/backups.

Ninety-day object retention is an optimistic window for planning: current race/lap PBs, creator proofs, challenge targets, other live references and immutable track versions remain protected. New bests can release older evidence only when every reference is gone. GCS soft deletion adds approximately seven days of recovery storage to successfully deleted objects; it does not remove unreferenced objects by itself. Failed/partial publication evidence also has separate accounting and retention.

Current World Ranking archives use 36 bytes per weekly result and 16 per world-position record before base64 envelopes, gzip, manifests and storage metadata. At a million records of each kind for 52 weeks, the raw binary content is about 2.52 GiB/year. Earlier 34/14-byte proposals are superseded. Turnover, corrections and mapping/career history change the totals. Ranking storage is small beside retained full race evidence. [Implemented ranking format](WORLD_RANKING_IMPLEMENTATION_2026_10_23.md).

Account storage is independent of daily traffic. As a separate assumption, 2–10 KiB of basic identity/index data per registered account means about 0.93–4.66 TiB for 500 million accounts, before sessions, ownership, profiles and racing history. No such population has been seeded or tested. Large sparse account populations need indexed account lookup and cache locality; they do not require every account in RAM.

Plan physical primary/replica allocation, backup bytes, WAL, vacuum headroom, index builds and recovery staging separately. The cost model adds 30% allocation headroom and two used-data equivalents of backups as assumptions; neither is a measured production peak. Multi-terabyte table churn may require more. Long restores and vacuum debt can become operational limits before raw storage prices become unaffordable.

## Running costs

The official Cloud Billing catalogue was queried in EUR for Belgium/EMEA rather than converting a web calculator's default US prices. Selected public SKU responses and pricing tiers are retained in [prices.json](evidence/backend-performance-review-2026-10-24/prices.json). Prices exclude tax and negotiated discounts. [Catalogue API](https://docs.cloud.google.com/billing/v1/how-tos/catalog-api), [Cloud Run pricing](https://cloud.google.com/run/pricing), [Cloud SQL pricing](https://cloud.google.com/sql/pricing), [Cloud Storage pricing](https://cloud.google.com/storage/pricing).

| Resource | Regional catalogue calculation for a thirty-day month |
| --- | ---: |
| Current 1 vCPU/1 GiB API kept warm but idle | €11.40, plus active request charges |
| Current continuous 1 vCPU/768 MiB worker | €27.76 |
| Planning continuous 1 vCPU/1 GiB verifier | €28.46 |
| Current 1 vCPU/3.75 GiB zonal SQL compute | €42.80 |
| Current 10 GiB SQL SSD | €1.50 |
| SQL SSD, zonal / HA regional | €0.1496 / €0.2992 per GiB-month |
| SQL backups | €0.0704 per used GiB-month |
| Regional Standard object storage | €0.0176 per GiB-month |
| Request charge after the catalogue's initial tier | €0.351 per million API requests |
| Standard object writes / reads at paid marginal tiers | €4.399 / €0.351 per million operations |

The current fixed resource floor is **€83.45/month**, before active API use, storage operations, backups, registry/builds, logs and other usage. An approximate small-traffic planning allowance is €90–150/month. This is not a billing-export reconciliation. The initial request/API-resource free allowances and credits can reduce cash spend; a busy second API instance can increase it. CPU utilization is not the same as billed active instance time.

The original larger-population forecast is withdrawn because it charged for a verification fleet derived from a superseded acceptance path. It also combined conservative SQL allocations, ninety-day per-attempt evidence, permanent detailed receipts, billed content delivery and two independent objects per race. These were costly scenario choices rather than demonstrated minimum resources. The original arithmetic remains available as a historical counterfactual, not a forecast for the current backend.

Several independent cost drivers remain valid under those stated assumptions:

- **Downloads:** at a million daily players, 1/5/10 MiB per player/day gives approximately €2,288/€10,538/€18,397 per month of Europe-to-Europe Cloud Run delivery at the retrieved tiered rates. A suitable direct low-egress delivery path and client caching can change this substantially.
- **History policy:** each additional year of the assumed permanent bundle adds 3.40–13.60 TiB of source SQL, before replicas/backups. Compact immutable receipts can replace expensive hot detail only after exact reward/retry behaviour is proven.
- **Object operations:** two separate writes for 300 million monthly races create 600 million object writes. A cheap storage-byte price does not remove that operations bill. Bounded immutable packs require a changed storage contract.
- **Log volume:** 400–1,000 bytes per request over 4.5 billion requests produces roughly 1.64–4.09 TiB/month before provider metadata and worker logs. Apply deliberate success-log sampling/aggregation while retaining necessary audit evidence.

The owner's new target is 95% below the former scenario. The [cost reduction plan](BACKEND_COST_REDUCTION_PLAN_2026_10_24.md) proposes a €1,800/month ceiling and a €1,753.96 candidate allocation at one million daily players. It keeps the model's ten daily races and requires lower unit hosting/delivery costs, packed objects, compact receipts, shorter nonprotected detail retention and fewer redundant calls. It is a target budget with unproven capacity, not a replacement claim that this amount already supports a million daily players. Labour, migration, tax and operational responsibility need separate consideration.

## Recommended scaling sequence and acceptance

1. **Establish current-image service costs.** Run the actual trajectory/rewind/creator paths across all five cars and common/maximum tracks, with warm and cold geometry. Record complete pipeline latency, Python/native preparation CPU, RSS, object bytes/calls, SQL finalization and failures. Keep offline replay diagnostics separate. Measure stored table/index/object deltas for a substantial synthetic accepted-race batch.
2. **Test a concrete 10,000-player workload.** Use an isolated same-region environment at declared resource limits. Generate an open-loop mixed workload around 87 API calls/s, 5.8 verifications/s and 58 client events/s at peak under this model. Verify generator drops, scheduled p95/p99, errors and queue age rather than completed throughput alone. The existing [capacity lab](../backend/LOAD_TESTING.md) is a useful starting point but must exercise current discovery, telemetry and optional ranking paths.
3. **Run hot-key and simultaneous-lane tests.** Concentrate traffic on one official board, one creator, one skill band, shared tie values and one analytical context. Combine discovery, telemetry, uploads, completion waits and ordinary reads. Test deployment overlap and connection exhaustion. A broad uniform player fixture will miss these bottlenecks.
4. **Make retention and recovery operational.** Establish approved retention/archive rules for each receipt class, reference-safe object collection, backup checks, oldest retained age, disk/WAL alarms and measured drains. Proposed public-service starting recovery targets are RPO at most five minutes and RTO at most thirty minutes; they require a suitable recovery configuration and a successful exercise, not just an enabled setting.
5. **Separate resources where tests justify it.** Give verification, publication, discovery and analytics explicit CPU/memory/connection budgets. Keep gameplay-primary work bounded; provision the required reporting standby only through the normal authorised change process. Scaling full supervisor replicas duplicates every role, so prefer role-specific scaling at material load.
6. **Progress through measured plateaus.** Test 10,000 then 100,000 then one million daily-player arrival rates with representative retained histories and indexes. Use at least a 24-hour soak at a justified intermediate rate, plus weekly rollover, cold content, worker kill/restart, dependency slowdown, retention and restore exercises. At a million, explicitly accept WAL/IOPS, vacuum, multi-terabyte recovery and peak verification cost before committing to the topology.

For each tier, publish endpoint p50/p95/p99, accepted and rejected arrival rates, queue age and drain time, oldest projection lag, pool waits, lock contention, DB CPU/IOPS/WAL, disk/temp peaks, per-role memory, object and egress bytes, and cost per thousand accepted races. Verify that protected results/rewards remain exact during overload and recovery. Keep normal driving and local result presentation independent of slow confirmation.

A single PostgreSQL deployment may remain economical well into growth if these measured workloads fit. At tens of thousands of peak requests and thousands of race finalizations per second, first measure partitioning by player/board, an analytical pipeline outside the gameplay primary, delivery caching and independently scaled verification. Geography needs deliberate latency measurements before adding regions; a remote API that still makes many cross-region primary queries can increase cost and latency. There is no evidence supporting a multi-region or 500-million-account certification today.

## Review validation and files

This review changes documentation and review tools only. The [evidence directory](evidence/backend-performance-review-2026-10-24/) contains aggregate inventory/monitoring, selected public prices, reproducible arithmetic and the actual focused test receipt. It contains no tokens, credentials, account records or database dump. Existing concurrent runtime work is preserved.

Actual commands used the pinned backend Python environment:

```text
python -X utf8 docs/evidence/backend-performance-review-2026-10-24/inspect_cloud.py
python -X utf8 docs/evidence/backend-performance-review-2026-10-24/prices.py
python -X utf8 docs/evidence/backend-performance-review-2026-10-24/model.py
python -X utf8 docs/evidence/backend-performance-review-2026-10-24/finalize_review.py
python -X utf8 -m pytest backend/tests/test_bounded_leaderboard_ranks.py backend/tests/test_bounded_retention.py backend/tests/test_priority_scaling.py backend/tests/test_telemetry_parallel.py backend/tests/test_service_worker.py -k 'not postgres' -q --tb=short --junitxml=docs/evidence/backend-performance-review-2026-10-24/focused-tests.xml
python -X utf8 -m ruff check docs/evidence/backend-performance-review-2026-10-24
git apply --check --reverse -- docs/evidence/backend-performance-review-2026-10-24/scoped-change.patch
```

The focused run returned **39 passed, 1 failed, 15 skipped, 51 deselected**. The failure is `test_visible_windows_limit_keys_before_joining_hidden_pbs[sqlite]`: the small SQLite fixture chooses its covering primary-key index rather than the specifically named partial index. Its returned-row assertion passes before the plan assertion fails. The same limitation is documented in the 23 October deployed-image gate; no test or invariant was weakened here. Skips include Linux-only signal/supervisor checks on Windows. PostgreSQL parametrizations were deliberately excluded, so this run supplies no new PostgreSQL concurrency or throughput result.

The historical model's arithmetic remains reproducible, but its obsolete verification assumptions and capacity/cost inference are withdrawn. The corrected review and cost plan distinguish measured checker computation from complete pipeline capacity. Local links, Ruff, Python compilation and the scoped checkpoint are rechecked after correction. An initial patch-generation error on a source file without a trailing newline was corrected by preserving the standard no-newline marker.

The first read-only cloud query failed under the restricted credential/network environment. It was retained as `cloud-inventory-initial.json`; normal read-only execution succeeded. Initial monitoring results had further pages; the final summaries follow all returned pages. No production load, migration, deployment, resource purchase, account mutation, device test or phone/tablet attachment check was performed.
