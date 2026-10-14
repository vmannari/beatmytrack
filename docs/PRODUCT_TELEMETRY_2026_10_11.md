# Signed-in telemetry and product analysis — 2026-10-11

Authorized deployment follow-up: [the completed staging rollout](PRODUCT_TELEMETRY_DEPLOY_2026_10_11.md) now enables this signed-in collector on schema25 and revision00033-jeq. The local/default-off statements below describe the original implementation task; guest coverage and the broader acceptance limits remain.

The owner requested telemetry and product analysis with particular attention to
network traffic and computation. The first local slice collects signed-in
observations, prepares product facts in a separate worker, and presents them in
Studio → Product analytics. Guest coverage is explicitly unavailable; no guest
identity or account-linking policy is introduced. All administrative totals
include artificial players, using the existing authoritative player flag.

This implementation is **local and disabled by default**. It has not changed the
deployed Studio, enabled collection, migrated an existing database, or created a
cloud service. The preceding Studio deployment authorization covered that earlier
release. Activating this new collector requires a separately authorized deployment.

## Requirement coverage and definitions

| Requirements | Implemented in this slice | Remaining broader specification |
| --- | --- | --- |
| BMT-010–012,018 | Versioned fixed event catalog; authenticated ingestion; bounded batches; durable per-event acknowledgements; duplicate/conflict handling; same-transaction authoritative outbox. | General schema registry, every proposed event/domain, diagnostic sampling and a replacement analytical store. |
| BMT-013 | UTC occurrence/receipt, monotonic session offsets, recorded clock quality, 30-minute background session boundary, disjoint foreground intervals. | Session inspector and aggregate foreground-duration views. |
| BMT-014 | Owner override: include all signed-in players, with server-derived artificial flag. Artificial races supply accepted facts; they do not manufacture menu/store/session observations. | No population filter is added. Public scoring/rating isolation remains independent. |
| BMT-015–017,020 | Collection start, projection watermark/backlog, current partial day, retained window, bounded collection-loss counters, event-time restatement and prepared read-only reporting. | Full quality cockpit, sequence/orphan reconciliation, metric ownership registry, immutable export snapshots, unified Pulse attention queue. |
| BMT-021–023 | Distinct observed DAU/WAU/window activity; ordered first-race journey; exact-day D1/D7 with mature denominators. | Rolling retention and player-age/skill/build/device/mode cohort explorer. |
| BMT-024,032 | Ordered editor/save/publication-request/server-publication journey; publication counted once per immutable version; observed seven-day reach to an accepted non-owner racer. | Geometry edit/test/validation-failure/share journey, time-to-publish distributions and complete creator health. |
| BMT-025–026 | Actual challenge open/join/create/share observations, visible discovery/car-offer exposure and actual selection counts. | Recipient delivery/eligibility/tries/weekly-return analysis and position/skill/device-adjusted preference comparisons. Exposure counts do not establish causal preference. |
| BMT-040–044 | Actual Store opening, visible fixed-SKU offers and eligible checkout intent. | Verified provider purchase, fulfillment, price/currency, refunds and revenue are unavailable. Catalog prices are never used as revenue. |
| BMT-075,097,100–104 | Bounded database work, traffic/CPU fixtures, analytical goldens, one read per refresh, cancellation/auth fences and responsive evidence. | Deployed soak/cost/capacity, full keyboard/zoom acceptance and device-network measurements. |

`app_first_open` means the first **observed signed-in open for an account**. It
does not mean first installation. DAU uses qualifying observed foreground
activity or accepted authoritative racing/publication, not registration or
receipt of any arbitrary event. WAU/window activity counts distinct players
across days, rather than summing DAU. D1/D7 use the first observed qualifying
activity cohort and exact target UTC day, with complete target-day follow-up.
Missing, future, pre-collection and expired coverage is unavailable; it is not
converted to zero. Late valid observations can restate prepared historical facts.
The observed interval is collection/projection evidence, not proof of complete
delivery for every account or every feed. Collection loss is disclosed; detailed
feed-outage/consent interval reconciliation remains in the quality backlog.

The first-race and creator funnels use unique players and chronological steps
within 24 hours and seven days respectively. The final onboarding step is an
actual second race start within ten minutes after the first observed finish;
pre-finish restarts do not satisfy it. First-race maturity includes that extra
ten-minute follow-up. A finish is a client observation;
only `race_accepted` increments accepted races. A publication is authoritative
and does not imply an externally raced track. Published-track reach uses its own
immutable-version denominator, excludes the owner, and only includes observed
publications with complete seven-day follow-up. Historical publication cohorts
are not reconstructed from subsequent races.

## Network and client computation

The client negotiates collection through the existing bootstrap response. An
older server or disabled flag causes no telemetry endpoint probe. A separate
best-effort transport cannot refresh credentials, change race authority, block
ordinary results, or borrow the race mutation queue. Uploads and new persistence
work are deferred during active racing/loading. Observations run outside canonical
simulation; a one-second app observer records actual race start, and existing
completion callbacks record finish. Start observations can lag by about one
second; this source is unsuitable for sub-second start-latency conclusions.
No trajectories, frame samples, screenshots,
free text, email, tokens or player-supplied authority flags are collected.

The local queue is capped at **1,000 events / 2 MiB / 24 hours**, partitioned by
account and server origin. A batch contains at most **50 events / 64 KiB**; the
response is capped at 16 KiB and the request timeout is ten seconds. Event UUIDs
survive retry. Collection acknowledges each accepted/duplicate/rejected event
only after the server commit. Account changes never move queued observations to
the new account. The queue uses an atomic background-thread snapshot; an abrupt
process kill before a deferred save can lose unsaved observations. These bounds
are a product measurement policy, not an exactly-once mobile delivery guarantee.

Meaningful menu activity is debounced for 60 seconds. Heartbeat-only batches wait
five minutes; all requests have at least 60 seconds spacing. Retries back off.
A full queue needs roughly twenty successful menu-time batches to drain; racing
and failures extend that interval. Foreground heartbeats are small, disjoint
60-second duration observations. They generate no per-frame traffic.

The pinned Windows Godot fixture exercises the actual packet builder and timing
policy over virtual one-hour schedules. These are **incremental telemetry JSON
measurements**, not measured Android HTTP/TLS/radio traffic or all existing game
network traffic.

| One-hour fixture | Requests | JSON request bodies | Assumed headers at 1 KiB/request |
| --- | ---: | ---: | ---: |
| Idle foreground menu | 10 | 15,521 B | 10,240 B |
| Active menu | 20 | 22,259 B | 20,480 B |
| 45 minutes racing | 3 | 13,163 B | 3,072 B |
| One lost acknowledgement | 10 | 16,580 B | 10,240 B |

TLS, response traffic, connection reuse, Android background behavior and radio
wakeups remain unmeasured. A measured 50-event packet is **12,170 B**. For an
illustrative 1,000 simultaneous active-menu users, this fixture implies about
5.6 requests/second on average and 22.3 MB/hour of request JSON; this is arithmetic
from the fixture, not a measured service capacity or bandwidth guarantee.

The final client fixture measured race enqueue p50 **7 µs**, p95 **9 µs**, maximum
**23 µs** over 64 samples. The 1,100-enqueue stress fixture measured p50 **13 µs**,
p95 **23 µs**, maximum **92 µs**. A full-queue main-thread snapshot took **124 µs**;
atomic serialization/write took **12.3 ms on the background worker**. Packet
preparation took **847 µs in the menu**. An earlier **5,973 µs** outlier is retained
in the evidence; it prompted bounded UUID pooling so live-race enqueue does not
call the operating-system random generator. Exhausting that pool drops an
observation and increments the loss counter.

## Server computation and storage

Ingestion makes one bounded bulk insert/read and locks a small counter row; it
does not count the raw backlog on every request. The default pending-client cap
is 50,000 events. Full capacity returns a retryable failure while known duplicates
can still be acknowledged. The authenticated player determines identity/flag;
malformed payloads retain only bounded rejection metadata.
One telemetry handler per API replica has its own semaphore and short busy
timeout. It cannot occupy the two ordinary race-upload parser permits.

An accepted race or first publication adds **one idempotent outbox INSERT** to
its existing authority transaction. It introduces no replay, physics, object
download, leaderboard scan or extra game request. A failed outbox transaction
cannot leave a committed score/publication without its corresponding receipt;
the existing durable race retry recovers without rerunning a cached verification.

`python -m bmt_backend.product_worker` is a separate process with one database
connection. The default projection batch is 500 events (maximum 1,000). Prepared
daily membership/counters and bounded player frontiers avoid raw race/event scans
from dashboard queries. Backlog probing is capped at 5,000 indexed rows and is
displayed as a lower bound when capped. Idle polling backs off to 60 seconds;
empty retention maintenance runs at most once per minute. Busy batches yield
for 200 ms. This process is separate from competitive verification and artificial
generation; deployment must give actual race processing resource priority.

Raw client receipts are retired in paced batches after the configured seven-day
window plus retry safeguards. Authoritative receipts retain small permanent
dedupe tombstones after their properties are compacted. Prepared daily facts
default to 180 days. Reporting hides expired facts immediately; physical cleanup
is paced, so this is not an erasure deadline. Player first-activity/frontier and
dedupe state remain longer. Account-erasure/consent workflows, small-cell policy
and cross-system cleanup are still the separate privacy backlog.
Permanent server receipt/profile cardinality grows with lifetime results/accounts;
the raw/fact windows do not cap total database size. A live capacity plan must
measure their actual row/index sizes and growth alongside retained race data.

An owned PostgreSQL17 fixture measured the following with 500 synthetic players.
Seeding time is excluded. Handler wall time includes local driver/database work;
the fixture supplies no HTTP middleware, deployed instance, canonical race or
device-performance claim. See the machine-readable benchmark for CPU and query
plan evidence.

| Backlog | Ingest 50 events | Project 500 events | 90-day prepared dashboard | Dashboard SQL/raw scans |
| --- | ---: | ---: | ---: | --- |
| 50,000 | 82.1 ms | 388.5 ms | 11.0 ms | 4 / 0 |
| 100,000 | 76.4 ms | 397.1 ms | 8.7 ms | 4 / 0 |

Projection used **156–172 ms of measured Python process CPU per 500-event
pass**, excluding PostgreSQL CPU and I/O wait. Windows process accounting in this
run is quantized in roughly 15.6 ms steps; zero/small CPU samples are not proof of
zero work. The standalone authoritative INSERT plus commit took **4.0–4.5 ms**
(one SQL execution and one commit); actual authority writes share their existing
transaction, so that phase is not the exact incremental race-finalization cost.
The 50-event acknowledgement was **3,883 B**; the prepared 90-day response was
**14,966 B**. The browser's ten-day fixture returned **4,300 B** in one request.

The first `EXPLAIN ANALYZE` exposed a full-backlog scan/sort for the ordered
500-event selection. The final schema adds `ix_product_pending_order`, a partial
index on `(received_at,id) WHERE processed_at IS NULL`; ordered idle/capped probes
match it. Final 50k/100k plans use an **Index Scan returning 500 rows** and an
**Index Only Scan returning at most 5,000 rows**, without the backlog sort. The
[earlier plans](evidence/telemetry-analysis-2026-10-11/benchmark-before-pending-index.json)
and [final benchmark/plans](evidence/telemetry-analysis-2026-10-11/benchmark.json)
are preserved. Daily-fact cleanup deletes at most the configured batch's composite
keys per table, rather than deleting every player in several expired days at once.

In this minimal fixture, the event relation occupied **26.2 MB / 52.3 MB** at
50k/100k rows, including indexes. Its server rows contain only a car dimension;
real lineage/client properties can be larger. WAL, backups and other fact/profile
tables are excluded. These sizes cannot establish total live storage cost.

These samples establish bounded operations, not p95 production latency
or sustained throughput. The single product-state lock serializes projection
and client ingestion; its measured hold time matters when sizing a live service.
Authoritative writers do not acquire that lock. No new analytics vendor,
warehouse or cloud service dependency is introduced.

Exact WAU/window distinct counts read prepared player-day membership. Their
90-day window is bounded, but work still scales with the number of active
players/days. The 500-player fixture does not establish capacity for millions
of membership rows. The existing database statement timeout applies; larger
population measurements or additional cached counts may be needed before scale.

## Files, validation and evidence

The client collector and transport are in `game/backend/product_telemetry.gd`
and `backend_client.gd`; observation hooks are in `game/core/app.gd`,
`game/ui/track_browser.gd` and `store_page.gd`. Backend contracts/models/ingestion
are in `backend/bmt_backend/{telemetry,telemetry_models}.py`, projection/read worker
in `{product_analytics,product_worker}.py`, and the additive schema is migration
`0025_product_telemetry` following `0024_lap_personal_bests`. The last reviewed
deployment used `0023_operational_read_indexes`; a future deployment must review the
whole migration/image chain. Authority hooks touch `worker.py` and `tracks.py`.
Studio integration adds `admin_ui/product_analytics.js` and its authenticated
route, navigation/style/capability changes.

Actual verification receipts and source-specific checks are retained under
[telemetry evidence](evidence/telemetry-analysis-2026-10-11/). Client measurements
are copied there from the native test output. Browser fixtures use authenticated
ingestion, the actual projector and actual reporting API; they are not hardcoded
dashboard values or real player data. The dashboard issues one prepared read per
refresh, with no overview fan-out and no idle polling. Existing query failures,
navigation cancellation and Lock clear data safely.

| Actual command/check | Result |
| --- | --- |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_product_telemetry.gd` | **55 checks passed**: bounded queue/packets, durable retry IDs/ACKs, account/origin separation, clock/session boundaries, async restore/startup order, background gating and cost fixtures. [Log](evidence/telemetry-analysis-2026-10-11/client-telemetry-tests.log), [measurements](evidence/telemetry-analysis-2026-10-11/client-metrics.json). |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_product_store_telemetry.gd` | **15 checks passed**: visible/hidden/warmed offers, fixed SKU IDs and guarded checkout intent. [Log](evidence/telemetry-analysis-2026-10-11/client-store-tests.log). |
| `scripts/dev.ps1 -Action Import`, then `-Action TestApp` | Pinned import passed; **99 app checks passed**. [Log](evidence/telemetry-analysis-2026-10-11/app-tests.log). |
| `.tools/backend-venv/Scripts/python.exe build/telemetry-analysis-2026-10-11/finalize_evidence.py --backend-checks` | **27 passed, 5 PostgreSQL cases deselected**. [Log](evidence/telemetry-analysis-2026-10-11/backend-final-tests.log). |
| `.tools/backend-venv/Scripts/python.exe scripts/test_product_analytics_postgres.py --focused` | Final **5 passed, 27 deselected**, with actual PostgreSQL concurrency, migrated bounded cleanup and authority transaction/slot rollback-recovery. 50k/100k benchmark completed; owned container removed after label check. [Test log](evidence/telemetry-analysis-2026-10-11/postgres-focused-tests.log). |
| `.tools/backend-venv/Scripts/python.exe scripts/test_product_analytics_console.py` | Final **11 browser checks**, zero exceptions; actual authenticated ingestion/projector/read API, complete/immature/missing cohorts, late canceled response, failure/Retry, analyst/Lock and 1440/1280/960/390px containment. [Receipt](evidence/telemetry-analysis-2026-10-11/browser-receipt.json). |
| Existing `.tools/review` JSON Schema validator | Draft2020-12 schema, 26 event-name/parser parity, 18 rejection examples and ACK contract passed. No installation. [Receipt](evidence/telemetry-analysis-2026-10-11/schema-checks.json). |
| Explicit `ruff check --config backend/pyproject.toml` on all touched Python files; JS syntax checks | Passed. Source/workbook invariants, scoped whitespace and reverse patch applicability are recorded with the review checkpoint. |
| `scripts/dev.ps1 -Action Doctor` | Exact engine/templates available; **no attached devices**. [Actual ADB output](evidence/telemetry-analysis-2026-10-11/adb-devices.log). |

The earlier broader admin/support/Studio/API run produced 87 passes and one skip
with one new PostgreSQL fixture failure: its fake ID token was shorter than the
existing authentication guard. The fixture now supplies a proper random token;
the guard is unchanged and final PostgreSQL tests pass. An unfiltered domain run
also tried the stopped, configured PostgreSQL test service; selecting SQLite and
using a newly owned PG container corrected the test setup. Initial App execution
encountered a concurrently added vehicle class before cache registration; the
pinned import resolved it without editing those unrelated vehicle files. Initial
sandbox access failures used the authorized local test override. One existing
Starlette/httpx deprecation warning remains. No assertion or invariant was weakened.

Final captures reviewed: [desktop](evidence/telemetry-analysis-2026-10-11/analytics-1440.png),
[narrow](evidence/telemetry-analysis-2026-10-11/analytics-390.png), and
[unobserved window](evidence/telemetry-analysis-2026-10-11/analytics-no-coverage.png).
The task-only before-to-final patch and file/evidence hashes are retained under
`docs/evidence/telemetry-analysis-2026-10-11/checkpoint/`; unrelated dirty workspace
changes are excluded. This is a review artifact, not a merge or deployment.

Activation instructions are in [the backend README](../backend/README.md).
Collection remains off until explicitly configured with the matching migrated
schema and separate worker. No phone is attached in the actual `Doctor` check;
no physical-device test, Android export/install or live deployment was performed.
Device-network/battery measurements, deployed soak/capacity, the broader product
requirements listed above and privacy/provider integrations remain acceptance
work rather than claimed completed functionality.


## Client network health ? 2026-10-13 (COMM-03)

Owner implements communication review finding3, with B05/B07/Q01. The existing first-party telemetry transport negotiates network_schema_version1; older/disabled services are not probed. Fixed client counters distinguish category/method/status/failure, success/cancellation/retry/HTTP429, client queue/preparation, HTTP completion interval and decode. Existing public and authenticated reads, fresh-ticket priority, credential rotation and recovery remain independent. Safe UUIDv4 request IDs survive response headers or structured response metadata and are retained for selected failures; URLs, payloads, credentials, raw operation keys and freeform error text are excluded.

New race jobs retain an atomic server-time queue anchor. Legacy, malformed or unanchored queue ages stay unavailable. Request-body sizes describe encoded attempted bodies; returned response sizes describe decoded bodies. They exclude headers/TLS/radio overhead and do not prove every prepared byte was transmitted. HTTP completion time includes callback scheduling and is not server computation time. Counters describe individual transmissions, including resends; they cannot establish service uptime or logical-action failure rates. Recent operation-key repeats are observed within a bounded process-local cache, not reconstructed lifetime retries.

The RAM observer holds at most4 account/origin scopes,16 categories,128 recent operation entries and8 selected failure kinds per scope. Menu snapshots are due every5minutes; driving/loading does not begin diagnostic snapshots, persistence or uploads. Existing1000-event/2MiB/24-hour local queue,50-event/64KiB packets, committed per-event ACKs and request spacing remain. Network-only events use the existing five-minute passive policy. Telemetry transport is excluded from its own observations. Unsnapshotted data can be lost on process termination,24-hour expiry or profile-cache eviction; guest/other-SDK coverage remains unavailable. Summary day means menu-time collection day and can include earlier requests.

Migration0032 adds prepared daily network counters and a partial selected-failure index. The product worker projects/cleans the facts within existing batches/retention. Studio's Network tab uses one prepared GET with category/platform/build/device/OS filters, timing bucket ranges, transfer/preparation totals, upload-age coverage and selected received IDs. Raw selected failures share the short client-receipt retention; queries inspect at most201 indexed candidates and return50 scoped samples, with explicit truncation. IDs are unverified client hints and must be matched to backend logs.

Actual checks: final SQLite82passed/2deselected; owned PostgreSQL17 60passed and removed; actual pinned native HTTP12checks/0failures with exact server-ID matching and committed ACK; native network28/telemetry55/quality57/session17/exception28/outbox11/refreshed-ticket26/recovery260 all zero failures. Studio browser29 and JavaScript contracts passed, including desktop/960/390 containment and no unrelated race/catalogue query for the Network tab. Ruff/syntax/diff checks passed. The captured native fixture packet is4698B JSON for6 network observations plus ordinary startup data; the largest event is819B. These are desktop/fictional local fixtures, not phone or TLS/radio costs. Initial timing and durable-queue fixture errors were corrected without weakening assertions.

No physical-device test, APK export/install, full game regression, production/live backend write or deployment occurred. Authorized0032 migration/backend rollout and updated app/device acceptance remain. Actual commands, packet/captures, limitations and task-only checkpoint are in [the review receipt](evidence/network-health-2026-10-13/review.json).
