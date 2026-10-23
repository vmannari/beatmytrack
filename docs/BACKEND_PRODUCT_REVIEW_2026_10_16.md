# Backend Studio: product analysis and production monitoring review

Review date: 2026-10-16. Requirements: **BRA01** view inventory and usefulness,
**BRA02** responsive interaction, **BRA03** trustworthy metrics, **BRA04** query
and worker efficiency, **BRA05** essential missing capabilities, **BRA06** staged
delivery plan for player behaviour, game quality and monetisation.

The deployed Studio is a useful diagnostic/support console with a sound bounded
reporting foundation. It is not yet a complete product-analysis system or a
production monitoring system. The recent Overview/Alarms work improves orientation
and investigation, but does not supply continuous detection, financial evidence,
release comparison or the population/segment data needed for business decisions.
The largest investment should be in those capabilities and their workflows.
Most record inspectors should be retained.

## What was actually reviewed

- Live retained staging revision `bmt-stg-e7a444ab-api-00059-vov`, schema
  `0036_community_safety`, compiler27/physics0.59. All17 asset hashes match the
  approved release. API/worker health was ready with one matching worker.
- All15 primary routes and six operational/quality subroutes: three desktop
  visits each; nine representative routes at1024/768/390px, totalling90 visits.
  Another eight visits covered player/track/race/competition inspectors at1440
  and390px. Rapid navigation and credential Lock were checked.
- Fifteen authenticated GET endpoint observations, frontend/backend source,
  ingestion/projection/schema/index/worker code and the client telemetry contract.
  Empty live case/publication inspectors were source-reviewed, not exercised
  with fabricated live records.
- Four isolated correctness reproductions using the frozen deployed backend and
  synthetic SQLite data. PostgreSQL17 benchmarks used500 synthetic players and
  10,000/50,000 pending events; each temporary schema/container was removed.
- Newer local migration0037 coin and0038 news work was examined as future scope.
  It is **not deployed** in the reviewed release and is not counted as a live
  Studio capability. Subsequent local physics0.60 is also separate.

All live requests were read-only. No live accounts, purchases, alarms, scores,
configuration, catalog or IAM were changed. No phone attachment check/test, APK
export/install, production load test or provider transaction was performed.
Raw record responses and potentially identifying screenshots remain in ignored
`build/backend-product-review-2026-10-16/`; public evidence contains aggregate
measurements and redacted inspector routes.

## View-by-view disposition

"Major" means redesigning the decision workflow and, where needed, its data
service. It does not mean discarding sound record projections or rewriting the
frontend in a different framework.

| Current navigation / view | Value today | Disposition | Concrete next change |
| --- | --- | --- | --- |
| Overview | Useful starting point; current faults, scoped activity, source links | **Keep; focused improvements** | Split operational health, release quality and business coverage; compare a baseline; show affected-player counts and sample confidence. Missing feeds must be prominent beside healthy checks. |
| Alarms and alarm detail | Useful triage and audited acknowledge/recovery-clear desk | **Keep desk; major alert-service work** | Continuous independent evaluation, occurrence history, ownership, routing, deduplication, maintenance suppression, recovery evidence. Existing revision/idempotency/recovery guards are valuable. |
| Player behaviour | Useful basic signed-in activity, ordered first-race funnel, exact D1/D7, observed selections | **Complete workflow/data redesign** | Segmentable journeys and retention, reusable cohorts, build comparisons, foreground engagement, saved analyses and clear evidence behind a recommendation. Current long dashboard is insufficient for explaining changes. |
| Client quality | Useful frame buckets, published-track presence/slow samples, render context, network and OS exits | **Major release-investigation redesign** | Release/build comparison first; rank regressions by affected users, group failures, connect network/server traces, then open device/track heatmaps. Retain the detailed diagnostic tools. |
| Race submissions | Correct operational counts, largely duplicates Overview and race list | **Merge; retire primary navigation entry** | Put submission trends/outcomes into Operations and drill down to Race evidence. It is not a separate player-behaviour product. |
| Tracks & creators / track detail | Useful published catalog, creator/rating/version/proof and route inspection | **Keep; focused improvements** | Add observed discovery-to-start/finish/replay reach and version-specific failure/abandonment evidence; keep missing observations unknown. Add an explicit version comparison. |
| Publications / publication detail | Useful creator request/proof/state investigation | **Keep; focused improvements** | Stage duration, oldest pending, retry/dead-letter eligibility, failure groups and direct support-case context. Do not collect private local drafts to fill the view. |
| Players / player support | Useful identity, access, purchases, histories and cases | **Keep; focused improvements** | One chronological support timeline; connect a selected session/release/purchase issue; clearer lifetime versus reporting-window scope. Preserve private-identity redaction. |
| Race evidence / race detail | Strong authoritative proof inspection and pinned-contract evidence | **Keep; focused improvements** | Clear outcome summary, structured failure-code filter, source freshness and links to the relevant request/quality report when actually correlated. |
| Competitions list / competition detail | Detail inspector is useful; list is mainly UUIDs and end dates | **Redesign list; retain detail** | Current/finished/problem queues, readable identity, participation/completion, contract compatibility, search and real pagination. Keep source-vs-stored rank/points inspection. |
| Support cases / case detail | Useful audited notes, state transitions and moderation evidence | **Keep; focused improvements** | Named assignee, priority, SLA/age, failure grouping, player impact and linked incidents. Individual staff identity is a prerequisite for accountable ownership. |
| Monetisation | Useful purchase support and development-product controls; no financial measurement | **Complete workflow/service redesign** | Separate revenue, ad delivery, IAP lifecycle, entitlements and earned-coin economy. Add real provider/reconciliation sources before revenue KPIs or optimisation claims. |
| Reliability & access / jobs / audit / access | Useful current verification/build snapshot and audit | **Major operations redesign** | API and dependency time series/SLOs, all worker/job types, incidents, recovery and provider backup evidence. Preserve detailed build comparison and audit. |
| Configuration | Mainly a compatibility explanation and unavailable-service notice | **Move out of primary navigation now** | Keep compatibility under release/operations diagnostics. Add a real versioned configuration/experiment/rollback service only as separately scoped work. |
| Data coverage | Useful honest capability register | **Keep; move to Administration and link contextually** | Combine implementation capability with actual receipt freshness, source ownership, schema versions, missing dimensions and failed-quality checks. A hardcoded supported flag is not a live feed check. |

Suggested primary navigation: **Overview; Player behaviour; Game quality;
Monetisation; Content & competitions; Operations & alarms; Player support;
Administration.** Cases, publications, race evidence and catalogs remain accessible
as queues/inspectors within these areas and through search. Experiments and
release scorecards should be shared workspaces linked from the affected area.

## Responsiveness and information design

At the current small staging volume, the UI is responsive. Three desktop samples
per route gave median display times from119.9ms to367.0ms; the largest measured
sample was399.3ms. Overview was302ms, Player behaviour151ms, Client quality276ms,
Tracks274ms, Monetisation212ms and Reliability246ms. These are operator-PC browser
observations, not production p95, field INP, cold startup or a load acceptance.

There were no JavaScript errors, failed admin reads, whole-page horizontal
overflows or observed browser long tasks in these visits. Rapid navigation ended
on the intended page and Lock cleared access. The measured main-page DOM peaked
at771 elements. All27 representative narrow layout checks and eight inspector
checks contained at their tested widths. A heuristic found no visible tested
button/navigation target below24px; this is not a full accessibility audit.

The weaknesses are workflow and density:

- The390px Player behaviour capture is5129px tall. Tables contain their overflow,
  but retention and business comparisons are still cumbersome on a phone. Provide
  compact triage cards, a selected investigation and progressive disclosure;
  detailed exploration remains best on desktop. Add keyboard and screen-reader
  acceptance for the redesigned workflows.
- Global dates coexist with current queue snapshots, lifetime catalogs and
  calendar-day telemetry. Each metric needs visible effective dates, population,
  grain and freshness; do not rely on bottom-of-page caveats.
- Every navigation clears the workspace to a loading paragraph and reloads context.
  Preserve the shell and filters, use section-level loading/errors, and retain
  explicitly labelled last-good evidence during a refresh.
- Quality's default/collection pages fetch three endpoints and about113.6KB;
  Crash/ANR fetches four and about114.3KB, even with no current race packages.
  The catalog/map selector is fetched for tabs that do not need it. Add a small
  track-options endpoint and fetch map data only after selecting a track/tab.
  The first track catalog page alone was about100.3KB. This is unnecessary
  transfer, rather than evidence of a current rendering bottleneck.
- Shared context is a serial prerequisite to other reads. Cache stable
  authenticated context briefly or include it in the workspace response; preserve
  the existing cancellation/auth-generation guards.

Proposed acceptance targets, to validate against representative volumes: immediate
input feedback, common warm workspaces p95 under1s, heavier investigations under2s,
visible loading within100ms, no blocking browser task over50ms in target flows,
and a measured field INP goal at or below200ms. These are proposed budgets, not
current service guarantees. [INP guidance](https://web.dev/articles/optimize-inp).

## Correctness: confirmed findings and interpretation limits

| ID / priority | Finding and evidence | Required response |
| --- | --- | --- |
| BRA-F01 / P0 for decisions | Every product total intentionally includes artificial drivers; guests are absent. Product facts have no equivalent population/build/OS segmentation. The live first-race cohort was one player; none of its D7 cohorts was mature. | Keep current all-player totals as required. Obtain a policy decision before introducing separately labelled business populations; never silently redefine existing totals or claim install-wide retention from these data. Show sample size and maturity prominently. |
| BRA-F02 / P0 for monitoring | Eight checks are evaluated on demand; reads do not create durable occurrence history. Short faults between checks disappear. No independent uptime/SLO delivery or incident routing exists. | Add an external detector and durable incident lifecycle. An alarm page served by a failing API cannot be the only detector of that API. |
| BRA-F03 / P0 for release decisions | Current selected live scope had no race-statistics or network-summary totals. Financial feeds are unavailable and purchase history was empty. | Surface collection/rollout coverage as unknown, not a healthy release or zero revenue. Validate one end-to-end supported client path before using these panels for decisions. |
| BRA-F04 / P1 confirmed bug | Reliability emits `races?q=<failure-code>`, but entity search omits `failure_code`. In an isolated fixture, one matching failed run became zero results through that link. | Add a structured code filter, or support the emitted query. Test the link end to end. |
| BRA-F05 / P1 confirmed bug | `failures_last_5_minutes` groups all non-null failure codes, including rejected evidence, while its table is labelled server failure categories. The fixture contained one infrastructure failure and one rejection; both appeared. | Split infrastructure, invalid evidence and policy/business outcomes. Preserve distinct denominators and remediation paths. |
| BRA-F06 / P1 confirmed bug | Reliability uses `d.schema`, but `studio/context` omits it, producing an unavailable schema display despite an observed schema36. | Return deployment/schema identity in the context or request a deployment source. |
| BRA-F07 / P1 semantic mismatch | A valid one-hour product request returns complete-day prepared counts; operational lists use exact timestamps. Quality/network acknowledge their day grain, while the product response does not provide an equivalent resolution field. | Normalize/reject unsupported intraday boundaries, or return and display effective bucket boundaries everywhere. Do not reconcile differently grained counts as though identical. |
| BRA-F08 / P1 operational gap | Background jobs lists `Run` records, including completed runs by default, while queue health also counts publication/track-validation work. Product projection/privacy/maintenance are separate again. | Replace the generic jobs list with job-kind/state/contract/lease/age views; make pending-work links open the corresponding pending queue. |
| BRA-F09 / P1 scale correctness | Race/network diagnostics sum only the first500 fact rows by default; track discovery facts cap1000 rows. Truncation is disclosed, but headline totals can still look population-wide. | Use full filtered rollups for headline metrics, separate detail paging, and render partial totals as lower bounds/unknown until complete. Never drop the truncation flag. |
| BRA-F10 / P1 usability | Competition list has a50-record budget and `has_more` notice, without a next-page mechanism. | Add stable paging and current/problem filters; make all retained records reachable. |

Source anchors: [render/context](../backend/bmt_backend/admin_ui/app.js),
[Reliability](../backend/bmt_backend/admin_ui/monitor_views.js),
[entity search](../backend/bmt_backend/admin.py),
[health formulas](../backend/bmt_backend/operations.py),
[product reporting](../backend/bmt_backend/product_analytics.py),
[race-statistics aggregation](../backend/bmt_backend/race_statistics.py),
[network aggregation](../backend/bmt_backend/network_health.py),
[competition paging](../backend/bmt_backend/studio_competitions.py),
[isolated reproductions](evidence/backend-product-review-2026-10-16/correctness-reproductions.json).

Preserve the existing strengths: missing versus zero, immature cohorts, ordered
journeys, accepted server outcomes versus client finishes, approximate histogram
percentile ranges, pinned versions, explicit truncation, durable receipt dedupe,
permission boundaries and audited revision-fenced actions. Nothing in this review
establishes corrupted live scores or fabricated financial totals.

Late observations deserve a stronger contract: ingestion accepts up to seven days
of event age, while mature follow-up is based on processor/receipt progress and
cohort age. A completed follow-up window is not necessarily final after offline
arrivals. Distinguish preliminary/finalised results, document correction policy,
and test out-of-order late events and replay/backfill. This is a contract risk
identified in source, not a measured live cohort error.

## Query, data and worker efficiency

The prepared reporting architecture is worth retaining. One product process is
separate from competitive verification, uses a single bounded DB pool, and is
given lower Linux CPU priority by the supervisor. Projection is bounded; idle
probing backs off; raw data and prepared facts have retention; heartbeat writes
are coalesced; queues use leases and explicit compatibility.

The exact deployed product code was profiled in owned PostgreSQL fixtures:

| Pending synthetic events | Ingest50 | Project500 | Dashboard | Dashboard SQL / raw-event scans |
| ---: | ---: | ---: | ---: | --- |
| 10,000 | 88.6ms,5 statements | 435.9ms,23 statements | 11.8ms | 4 / 0 |
| 50,000 | 79.7ms,5 statements | 456.2ms,23 statements | 8.5ms | 4 / 0 |

Each projection committed once. Idle probe used one statement and3.1-3.3ms.
`EXPLAIN ANALYZE` used `ix_product_pending_order` for the500-event claim. The
dashboard and one batch stayed bounded as raw backlog grew. These are single
desktop loopback samples of a simple server-event workload; not sustained
throughput, concurrent lock-wait, cloud DB CPU or a high-cardinality quality test.

Next efficiency work:

1. **Measure shared-lock contention.** Ingestion and projection both lock the
   singleton `ProductState`; projection holds it through its batch. This is a
   structural concurrency bottleneck candidate, not demonstrated overload.
   Measure ingest p95/lock wait alongside rich projection and game traffic before
   introducing partitioned counters or shorter transactions.
2. **Expose every worker pipeline.** Projection lag/batch duration/retries,
   verification compute versus queue wait, publication phases, erasure retries,
   maintenance age and contract mismatch should be attributable. The current
   single container is a shared CPU/memory/failure boundary despite separate
   processes. Scale or separate pools when measured SLOs justify the cost.
3. **Bound DB work, not just returned rows.** Exact totals, substring searches,
   distinct players and deep OFFSET still grow with history. Prefer exact-ID
   lookup, keyset paging, appropriate rollups and measured indexes. Add trigram
   search only if representative plans warrant it. Batched page-level player
   counts and existing partial indexes are good practices to retain.
4. **Reduce repeated transfer and reads.** Small selector projections, lazy map
   details, workspace snapshots and short authenticated caches should precede a
   frontend-framework migration. Keep no-store/private semantics for sensitive
   player records and visible age for cached aggregates.
5. **Version analytical facts.** Current day/key/dimension facts cannot answer
   historical build, acquisition or experiment questions after raw retention.
   Add the dimensions/facts needed by named decisions and a bounded replay path.
   Preserve permanent authoritative dedupe when compacting receipts.
6. **Keep analytics off score authority.** Start with the existing PostgreSQL
   prepared facts and explicit query/connection budgets. When segment/replay volume
   warrants it, export through a durable outbox to an analytical store; keep
   purchases, entitlements, verification and moderation transactional. On the
   existing GCP stack, BigQuery is an option, not an installation decision made by
   this review. Partition pruning, narrow projections, clustering chosen from
   actual access patterns and billed-byte budgets matter there.
   [BigQuery query guidance](https://docs.cloud.google.com/bigquery/docs/best-practices-performance-compute).

Do not claim production scalability from the small live population or this
benchmark. Acceptance must include the forecast peak and offline replay bursts,
simultaneous game traffic, long date ranges, high-cardinality dimensions,
dependency failure, queue recovery and erasure/replay safety.

## Essential missing decision capabilities

**Player behaviour:** consented guest/install/account scope, acquisition source,
new/returning cohorts, actual foreground engagement, D1/D7/D30 and rolling return,
repeat racing, completion/abandonment/retry, mode/car/biome/track-version funnels,
cohort comparison, saved segments and event-to-outcome timelines. Foreground
duration observations already exist, but prepared reporting does not turn them
into an engagement metric. First observed activity is not necessarily install
date. Aggregate car-selection events are not unique-player preference or causal
appeal. Optional guest acquisition/linking requires a separate consent/identity
design; do not import guest Coins or upload private local authoring.

**Game quality:** release/build scorecards, comparable previous/control builds,
device/renderer cohorts, user-impact counts, crash/ANR grouping and symbolicated
evidence where collected, startup/menu/load/download timings, queue-to-verified
journeys, memory/device-health evidence and issue-to-fix tracking. Published-track
heatmaps are a drill-down, not the entry point. Keep Play vitals separate from
next-launch client exit observations: their populations and denominators differ.
[Android vitals](https://developer.android.com/google/play/vitals).

**Monetisation:** exposure-to-request-to-provider-success-to-fulfilment funnel,
paid and ad-free access expiry, refund/reversal/reconciliation, ad request/fill/
impression/reward delivery, impression revenue with currency/precision, ad pressure
per session, payer conversion and cohort revenue with retention/quality guardrails.
Live Play notifications require fetching complete purchase state from the Play
Developer API; receipt/notification presence alone is insufficient.
[Play RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference).
AdMob paid events provide micros, currency and precision; estimated ad revenue
must stay distinct from reconciled proceeds and from test impressions.
[AdMob revenue contract](https://developers.google.com/admob/android/impression-level-ad-revenue).
Never infer revenue from configured test prices or approved simulated purchases.

**Earned-coin economy:** separate the upcoming non-cash rewards/unlocks from paid
commerce. Show mint/spend/remaining balance reconciliation, reward reasons,
purchase refusal, unlock adoption and time-to-afford by cohort. The current local
wallet/reward/unlock tables are a foundation, not a complete time-series
debit/credit audit ledger or a live Studio economy. Instrument news/friends
adoption only if it answers a defined product question and fits privacy policy.

**Production operations:** independent availability/dependency probes, API request
error/latency/bytes time series, database/pool/lock health, all job queues, error
budgets, incidents/ownership/notifications, release markers, real provider backup
and restore evidence, and spend/storage budgets. Existing structured request logs
already include route template, request ID, status, duration and bytes; build
dashboards/alerts from them before adding redundant instrumentation. For tracing,
use bounded route/operation attributes rather than player IDs as metric labels.
[OpenTelemetry HTTP conventions](https://opentelemetry.io/docs/specs/semconv/http/http-metrics/).

**Safe optimisation:** versioned configuration, stable random assignment,
separate actual-exposure events, experiment/variant identity in facts, preselected
primary metrics, holdouts, sample-ratio checks, uncertainty and stopping rules,
guardrails and audited rollout/rollback. Selection correlation is not proof that
a car, offer or ad frequency causes retention/revenue. Reject unreliable
experiment allocations rather than presenting a confident winner.
[Microsoft SRM research](https://www.microsoft.com/en-us/research/articles/data-quality-fundamental-building-blocks-for-trustworthy-a-b-testing-analysis/).

**Governance:** named staff SSO/MFA and permissions, source/metric ownership,
definition versions, lineage, retention and deletion propagation, consent coverage,
controlled exports and an audit trail for changes. Shared owner/analyst keys are
insufficient for individual incident responsibility. A low-volume cohort needs
its denominator and an "insufficient evidence" state.

## Delivery sequence and completion gates

| Step / priority | Concrete deliverable | Dependencies / acceptance |
| --- | --- | --- |
| 1 / P0: make evidence trustworthy | Metric registry with unit, source, authority, denominator, population, consent, effective range/grain, freshness, completeness, late-arrival policy and owner. Fix F04-F07 and misleading queue links; make missing client/financial feeds explicit. | Current approved all-player totals remain intact. Any separately labelled business population is an explicit policy decision. Synthetic fixtures reconcile the displayed numbers with source queries, including duplicates, missing/late/out-of-order events and partial dates. |
| 2 / P0: detect failures independently | External read-only API/dependency probes; route latency/error dashboards from existing logs; continuous detector and durable incident occurrences, owner, severity, suppression and notifications. Connect every worker pipeline. | Detect a controlled API outage even when Studio cannot load; preserve a short incident between operator visits; verify dedupe, escalation, recovery and notification delivery. Start with a few player-impact SLOs and low-volume-safe rules, not an alert on every isolated error. |
| 3 / P1: establish usable player cohorts | Versioned engagement/session/journey facts, necessary build/platform/mode dimensions, explicit cohort explorer, retained D1/D7/D30 and repeat-race metrics, saved comparisons. | Consent/identity/population policy resolved; do not silently reconstruct historical dimensions from current player state. Wait for genuine mature follow-up and minimum evidence before making retention claims. Validate replay/backfill and erasure propagation. |
| 4 / P1: build release-quality workflow | Release registry/markers; build-vs-baseline scorecard; affected users; grouped crashes/ANRs; race finish/abandonment and network verification journey; drill-down into existing track tools. | An updated supported client supplies real packages; collection coverage is visible per build/device. A controlled regression appears in the correct cohort and links to retained evidence. An absent feed stays unknown. |
| 5 / P1-P2: make monetisation measurable | Provider-backed IAP/ad events and fulfilment ledger, refunds/reconciliation, verified revenue basis/currency, earned-coin mint/spend history; cohort scorecards with retention/quality guardrails. | Provider setup and contracts are separately authorised work. Test/replayed events cannot double-count money or grant access; financial sources reconcile and unavailable settlement remains unavailable. Never combine Coins with money. |
| 6 / P2: enable safe experiments | Versioned non-canonical configuration, assignment/exposure facts, experiment scorecards, sample-ratio checks, predeclared decision rules and rollback. | Metrics and financial/quality guardrails already trustworthy; pass an A/A validation; repeated exposure is idempotent; assignments are stable; invalid allocation or insufficient sample blocks a winner. Preserve canonical race contracts. |
| 7 / P2: consolidate and harden | Eight primary workspaces, unified evidence links, named staff permissions, saved views/exports, compact mobile triage, lazy selectors, measured query budgets and analytical-store separation if needed. | Common questions answerable without manual SQL or knowing UUIDs; complete filtered KPIs agree across drill-downs; peak/replay/failure load stays within chosen budgets; restore/recovery and access-control exercises pass. |

Steps2-4 can proceed as coordinated streams after the shared definitions; the
sequence is a dependency order, not a calendar estimate. Begin collecting the
right evidence before investing in all dashboard layouts. Continuous alerts
should reflect significant player impact/error-budget consumption, with care for
low-traffic rates. [SRE alert design](https://sre.google/workbook/alerting-on-slos/).

The first end-to-end acceptance scenario should be concrete: **a new release raises
Android frame stalls on a specific renderer, first-race completion falls, and
repeat play changes**. The tool must show coverage, comparable cohorts, sample
sizes, correlated evidence and the tracked corrective action. A later controlled
ad/offer experiment must demonstrate monetisation improvement while its retention,
crash/ANR and fulfilment guardrails remain acceptable. Until assignment/exposure
evidence exists, describe correlations rather than causal effects.

## Evidence and work boundaries

[Live inventory](evidence/backend-product-review-2026-10-16/live-inventory.json),
[browser summary](evidence/backend-product-review-2026-10-16/browser-summary.json),
[full browser observations](evidence/backend-product-review-2026-10-16/live-browser-review.json),
[inspectors](evidence/backend-product-review-2026-10-16/live-inspectors.json),
[correctness reproductions](evidence/backend-product-review-2026-10-16/correctness-reproductions.json),
[PostgreSQL plans/profile](evidence/backend-product-review-2026-10-16/postgres-product-profile.json).
Captured review tools, source hashes, findings/backlog and task-only checkpoint
are alongside these files. Screenshots were visually inspected at1024 and390px;
private identifying images are not copied into public evidence.

Initial harness failures are not application findings: the Cloud SDK needs its
native Windows encoding despite UTF-8 report output; Playwright's string-evaluated
wait predicate conflicted with CSP and was replaced by a compatible observation
loop with CSP retained. The old benchmark fixture omitted analytics opt-in and
was corrected only in the owned in-memory benchmark copy; ingestion consent was
not weakened. The initial benchmark log is retained. The corrected profile and
four correctness reproductions are actual completed runs.

This task produced a review and implementation plan. It did not implement the
recommended product changes, add analytics vendors, change approved population
policy, deploy source, grant permissions, charge money or alter player records.
No complete accessibility, mobile-device, concurrency/soak or restore certification
is claimed. Owner prioritisation and the noted policy/provider decisions remain
for subsequent implementation.
