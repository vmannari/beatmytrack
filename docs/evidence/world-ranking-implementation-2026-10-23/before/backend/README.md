# Beat my track backend

Discovery resource guards (`0057_discovery_resource_guards`, 2026-10-23): discovery POSTs use a nonblocking account fence, including pre-body authentication and the final commit check. A busy account returns `503 DISCOVERY_ACCOUNT_BUSY` promptly; revocation, account removal and erasure serialization remain authoritative. Discovery executions share at most `max(1, min(3, database_pool_size - 1))` local query slots, across both small and bulk bodies, leaving a pooled connection for other gameplay when the configured pool has more than one connection.

Work credits are shared in PostgreSQL, independently of view creation. Each actor has separate ordinary and expensive allowances. Random, text and non-text filters, personal lists and authenticated new-view initialization use the expensive lane. One expensive operation per actor is leased across replicas, with a ten-second crash-recovery deadline and token checks before work and every commit. Credit reservations survive rollbacks and crashes; unused credit is refunded after releasing the request connection. Elapsed server work is charged in 25ms units, with a minimum of one unit for ordinary work and four for expensive work; each attempt conservatively reserves 60 units before executing. Defaults are `BMT_DISCOVERY_WORK_UNITS_PER_MINUTE=600` and `BMT_DISCOVERY_EXPENSIVE_UNITS_PER_MINUTE=240`. Insufficient credit returns `429 DISCOVERY_WORK_LIMIT`. Query/Random budget failures retain their charge and enforce an actor-wide expensive-work cooldown of 2, 4, 8, 16 and then 30 seconds. Rotating cursors, filters or Random exclusions cannot evade it. Ordinary pages retain their independent allowance. Guard rows expire after three idle minutes and are removed in bounded worker batches. SQLite file databases use WAL, and connection-local progress/busy handlers are cleared before pool reuse.

Anonymous traffic also has shared secondary network limits: IPv6 `/64`, IPv4 `/32`, 1,200 requests/minute, a burst allowance of 120 requests/ten-second bucket, 40 new views/minute and 202,000 inserted member rows/minute. Configure these with `BMT_DISCOVERY_NETWORK_READS_PER_MINUTE`, `BMT_DISCOVERY_NETWORK_BURST`, `BMT_DISCOVERY_NETWORK_CREATES_PER_MINUTE` and `BMT_DISCOVERY_NETWORK_ROWS_PER_MINUTE`. Anonymous small-body reception is additionally capped at two concurrent receivers per network and four per process, preserving receiver capacity for validated players. These limits supplement exact peer/player admission and trusted-proxy validation. They do not broaden cursor ownership, and validated signed-in players retain independent account budgets behind shared networks.

Personal-list copies retain only IDs present at the captured discovery epochs; unused history lists are omitted. Device-local favorites/history and the 50,000-ID input limit per list remain. Outstanding physical rows, including expired rows awaiting collection, are capped per actor at 202,000 rows and 64 MiB of charged member storage (`BMT_DISCOVERY_ACTOR_MEMBER_ROWS`, `BMT_DISCOVERY_ACTOR_MEMBER_BYTES`). Sixteen independent transactional service stripes cap aggregate retained members at 16,000,000 rows and 4 GiB (`BMT_DISCOVERY_STORAGE_MEMBER_ROWS`, `BMT_DISCOVERY_STORAGE_MEMBER_BYTES`), divided across stripes; an individual stripe may fill first. Charged bytes are 128 plus the UTF-8 kind/identifier lengths per member, not a measurement of PostgreSQL heap/index/WAL allocation. Limits return `429 DISCOVERY_STORAGE_LIMIT`, without preventing ordinary discovery or reads of already-created views. Tune allowances against measured legitimate demand, database allocation and cleanup capacity before increasing traffic.

Apply `0057` and matching API/worker code in a coordinated release, draining old collection writers and cleanup workers. Existing collections are preserved and accounted through indexed 512-member worker batches; new retained-member writes return `503 DISCOVERY_STORAGE_PREPARING` until accounting finishes, while ordinary feeds and existing views remain readable. Source health logs include `storage_backfill_ready`, sixteen member/byte totals and guard cleanup age. Deletion/expiry reduce the same counters in their transaction, including partially accounted legacy collections; failed writes release their capacity on rollback. The migration adds an index on existing collection metadata: measure its build/lock time on a representative copy and use a controlled window. No live migration, deployment, upstream WAF change or million-DAU certification is implied by the local checks. [Resource-guard implementation, failure tests and local timing evidence](../docs/evidence/discovery-resource-fixes-2026-10-23/report.json).

Discovery hardening (`0053_discovery_short_search`, 2026-10-23, DHF01-DHF06): small identity-encoded discovery bodies with a declared length of at most 16 KiB use eight bounded receivers and a separate parser/query allowance. Large, compressed and length-unknown collection uploads retain one large-tree slot. One unfinished small body per verified player or anonymous peer, a two-second inter-chunk stall bound and a five-second small-body deadline prevent one slow uploader from occupying query capacity. All discovery queries share the bounded pool; the integrated resource guards reserve ordinary gameplay capacity and separately admit expensive work. A busy response carries Retry-After. The native v3 window pauses automatic fetching after failure, honors that delay with bounded backoff/jitter on explicit retries, and resets retry ownership on account/query changes.

Freshness uses sixteen bounded indexed receipt probes in one SQL round trip. Frozen pages select narrow revision/order keys from the projection; current track/account/block authority remains checked during hydration. INSERT RETURNING avoids extra session/checkpoint reads, and Random retrieves sampled slot coordinates with its candidate rows. Exact sampling, frozen spans, current restrictions, private caches and twenty-item pages remain. Short searches retain exact case-insensitive substring behavior: PostgreSQL adds GIN indexes over distinct one/two-character grams, including literal punctuation, then applies the original ILIKE predicate. Arbitrary selective filters still have a finite work budget and can explicitly retry.

Cleanup progress now keeps the discovery daemon active until bounded expired work drains. Health includes pending receipt, rank-due, expired-pair and retained-state cleanup ages. The seven-day pair expiry index stores only partition/expiry: the consumer needs no tie ordering while it owns the partition. Exact latest-pair refresh, expiration and counter deltas remain. Paired 200,000-row local probes reduce total pair-ledger allocation by 26.9–28.2%; these are physical PostgreSQL measurements, not a cloud price or DAU forecast.

Apply `0053` before matching API/worker code; the current shared migration chain and admission/storage guards must also match the artifact being released. Review the rating-sum change from `0050`, backups, source backfill and old-client update together. A fresh projection builds the new indexes while empty. On a populated projection or pair ledger, ordinary transactional DROP/CREATE index builds block writers and can exceed the migration connection's default statement timeout. Measure a representative copy and choose a controlled maintenance window or an operator-reviewed concurrent-index cutover with equivalent schema verification before recording the revision. Do not run old expiry workers across a populated index cutover. Neither API requests nor workers run migrations. [Actual tests, paired SQL plans, WAL/storage measurements, limitations and scoped checkpoint](../docs/evidence/discovery-hardening-2026-10-23/report.json). No live rollout or device test was performed.

Local priority scalability fixes (2026-10-23, `0054_priority_scaling`): Rivalry matching reads at most 100 open group IDs through a partial index, skips busy groups when another open group is available, and keeps the exact 20-driver capacity. If every candidate is busy, it waits on one group before creating another; only new-group creation uses the band guard. Closed groups no longer accumulate in the matching scan. Membership, pinned tracks, skill scoring and retries retain their existing contracts.

Accepted ordinary races now commit a pending creator-achievement effect alongside the permanent coin receipt. Both play counts and first-time racer reach are projected later, in batches of at most 100 effects, coalesced by creator. Racer achievements remain immediate. Sixteen partition fences allow race intake during reduction while excluding account erasure; busy creator states retain their effects for retry. New intake checks creator eligibility; later suspension/test-identity changes preserve accepted effects, while account deletion cancels them. Pending rows contain only the creator ID, accepted run ID, partition, timestamp and reach, and are deleted atomically with projection. CoinReward remains the durable replay fence; do not independently replay historical accepted races into this outbox. Creator deletion drains indexed 100-row chunks before completing achievement erasure.

The service worker reserves privacy, histogram and one rotating achievement/Trackside turn every 16 completed jobs. With both presentation classes continuously busy, each gets a turn within 32 job completions; achievement competitions, rarity, held records and creator effects rotate internally. Idle presentation/lap/histogram work also rotates. These are work-count guarantees, not a wall-clock deadline or throughput certification. Long verifications still delay a turn. Size worker capacity against pending-effect age, requested-news latency and database load on representative traffic; a reserved share alone does not prove one-million-DAU capacity.

Roll out `0054` with matching API and worker code after draining/stopping old writers and taking a recoverable backup. Existing creator totals are retained with no historical rebuild. The open-group index is built transactionally by the ordinary migration; measure its lock/build time on representative data or use an operator-reviewed concurrent-index cutover before recording the equivalent revision. Drain the creator outbox with the matching worker before downgrade: the migration refuses to discard pending effects. Restart the matching service after migration; do not run legacy synchronous creator writers concurrently with the new reducer. [Tests, query plans, review refinements and task-only checkpoint](../docs/evidence/backend-priority-fixes-2026-10-23/report.json). No live rollout or physical-device test was performed for this backend change.

Local discovery redesign (2026-10-22): `/v1/discovery/v3/tracks` and `/v1/discovery/v3/random` replace whole matching-catalogue snapshots. A request sends `{"query":{"sort":"name"}}`, then only `{"cursor":"..."}` for later pages. Twenty-item pages expose `total: null`, `has_more`, `page_cursor`, `next_cursor` and `previous_cursor`. The matching client uses a bounded sliding window and labels loaded cards. A selected revision can open an anchored window with `locate_version`; that window starts at the selected track and continues forward. Refresh opens the ordinary feed. Arbitrary offsets and a selected track's exact global ordinal are retired. The v2 endpoints return HTTP426; overload never falls back to building a catalogue.

Migration `0050_discovery_indexed` installs transactional source receipts before the independent `bmt_backend.discovery_worker` backfills metadata and recent driver pairs. Sixteen independently locked partitions retain changed ranking/filter rows for the 30-minute cursor lifetime plus a cleanup margin. Unchanged rows are shared; no periodic whole-generation copies are made. Current visibility, account restrictions and blocks override frozen ordering before delivery. Candidate page spans remain frozen: removing a track shortens its page without pulling in a card from the next cached page or reweaving recommendations. Personal favourite/device-raced collections and bounded block sets are indexed, scoped and expiring; block/unblock changes identify a new view immediately. Rank updates coalesce for roughly 60 seconds; cursors freeze ordering, filter values and published revision, while display statistics and author identity are current. New views return retryable HTTP503 while preparing, after a worker outage, or when pending source receipts are over 120 seconds old. The worker logs bounded partition health samples every minute.

Queries have a 1.5-second application/SQL work budget, including personal collection creation. Selective combinations and one/two-character substring searches can still examine many indexed rows; a timeout returns HTTP503 instead of a false empty result. Random is exact uniform selection over eligible logical tracks: small complete candidate sets use a direct choice; larger sets use uniform dense slots with rejection, at most 4096 trials. Exhaustion returns a retry response. There is no promise that every selective Random request can succeed within a fixed budget. Retained history, journal receipts and expired personal rows are removed in bounded batches. The operator-only `python -m bmt_backend.discovery_worker --repair-track UUID` can reconcile one derived popularity counter from its durable pair ledger under a SQL deadline; it is never part of an HTTP request or race finalization.

Release discovery migration, API, service-worker supervisor and game client together after backup and an explicit rollout window. Old clients require an update. Initial backfill is resumable; allow it to complete and verify partition health before accepting discovery traffic. PostgreSQL widens the existing rating sum to BIGINT, which can rewrite/lock a large `track_versions` table; measure this on a representative copy and schedule the migration accordingly. The new indexes build on initially empty projection tables. Rollback across `0050` requires the reconciled backup/source checkpoint; do not run old writers against the new schema or resurrect the v2 full-catalogue path. Staging connection admission includes every supervised process and revision overlap; enabling telemetry can require fewer API replicas. [Risk dispositions, actual local checks, SQL plans and remaining capacity limits](../docs/evidence/discovery-indexed-2026-10-22/report.json). This local implementation has not been deployed or certified for one million daily players or 500 million accounts.

Local Studio performance update (2026-10-22): directory pages use bounded forward/backward cursors and omit whole-catalogue counts and per-row history. Player history remains in selected-player support. Behaviour tabs request only their own exact analysis; the duplicate historical view, unused lifetime overview totals and aggregate wallet balances are retired. Revenue and Coin flows retain their reporting periods. Migration `0045_studio_report_reads` indexes latest financial receipts and belongs to the current merged migration chain. API and Studio assets must roll out together because list totals can be null and behaviour defaults to Activity. [Disposition, measurements, actual checks and remaining limits](../docs/evidence/studio-performance-2026-10-22/report.json). This local change has not been deployed.

Local queue-capacity fix (2026-10-22): migration `0047_queue_capacity_slots` replaces the global pending-counter write with independently owned transactional slots for races, publications and historical validations. The exact configured total limit, eight pending jobs per player, leases and retries remain. `queue_capacity` is now a read-only aggregate view. All writers must use matching API/worker code; quiesce them for migration and coordinate capacity configuration across replicas. Limit reductions can require draining occupied higher slots. [Implementation, actual PostgreSQL reproductions and rollout limits](../docs/evidence/queue-capacity-slots-2026-10-22/report.json). This local change has not been deployed.

Full deployment (2026-10-18): cloud API86/schema42, its worker/all five owned jobs and the PC API/worker use the complete tested physics0.66/rules23 image. Player support now includes inventory and audited grants. [Release, actual validation, backups and data preservation](../docs/FULL_BACKEND_DEPLOY_2026_10_18.md). Older phone builds still need a matching client update.

The local [Studio platform implementation](../docs/STUDIO_PLATFORM_2026_10_16.md) adds focused analytics, release quality and durable operational response. See its [activation runbook](../docs/STUDIO_PLATFORM_ACTIVATION.md) for schema0040 and the still-required live connections; no new rollout is implied.

The owner-approved creator-slot and ad-free entitlements have a development-only,
payment-free [purchase simulator and launcher](../docs/PURCHASE_SIMULATION.md).
It requires migration `0016_commerce`; the standalone loopback lab is isolated from
existing services. Actual store billing and production fulfillment are not configured.

The first server slice provides identity, immutable shared creator tracks, ratings
and verified personal/global records. It is a Python modular monolith with
PostgreSQL 17, a separate canonical Godot replay worker and content-addressed object
storage. The same containers run on the DS925+ and a future cloud VM/container host.

See [architecture and requirements](../docs/BACKEND_V1.md) and the
[deployment runbook](deploy/README.md). Neither a NAS deployment nor Google OAuth
credentials are included. The menu's **Sign in** opens Google and Development options;
see [account setup and acceptance](../docs/ACCOUNT_SIGN_IN.md). Track/rating/leaderboard
menus also use the optional cloud and Weekly Rivalry integration.

Scalability repairs require migrations through `0014_storage_lifecycle` and matching API/worker artifacts. See [load profiles and gates](LOAD_TESTING.md) and [actual verification/acceptance](../docs/BACKEND_SCALABILITY_FIXES_2026_10_05.md).
Native Google Cloud Storage is available with `BMT_OBJECT_BACKEND=gcs`, an explicit
bucket/prefix and application-default credentials. It retains immutable SHA256
keys, conditional generation-safe publication/deletion, database pins and portable
object archives. [GCP staging](deploy/gcp/README.md) prepares bounded, explicitly
applied Cloud Run/worker/Cloud SQL resources; [actual verification and remaining
live acceptance](../docs/BACKEND_GCS_STAGING_2026_10_05.md) records the tested scope.

Local API development (use a maintained Python runtime; deployment image uses 3.12):

For this Windows PC, use `scripts/dev.ps1 -Action BackendStart`. It starts the
isolated WSL Docker stack at `http://127.0.0.1:18181` and saves the game's connection
and development key for normal editor launches. `BackendStop` stops the stack
without deleting data. This avoids the existing unrelated service on port 8080.
See [PC setup and Google client-ID steps](../docs/ACCOUNT_SIGN_IN.md).
The generic manual API setup below is for other separately configured environments.

```powershell
# Windows: use Python linked to supported OpenSSL 3.5+ (for example Python 3.14).
# Do not reuse the old Python 3.10 / OpenSSL 1.1.1 test environment.
python -m venv .tools/backend-secure-venv
.tools/backend-secure-venv/Scripts/python -m pip install --require-hashes --only-binary=:all: -r backend/requirements.lock
.tools/backend-secure-venv/Scripts/python -m pip install --no-deps --no-build-isolation -e backend
# Set BMT_DATABASE_URL to a disposable PostgreSQL 17 database.
# Set BMT_OBJECT_DIR to an ignored development directory.
# Set BMT_GODOT_BIN to the exact binary from godot-version.txt.
# Set BMT_GAME_PROJECT to the absolute game directory; import it first.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendMigrate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendRun
```

`scripts/dev.ps1` prefers `.tools/backend-secure-venv` and accepts an explicit
`BMT_BACKEND_PYTHON` path. It rejects the old local TLS runtime before backend
operations. Use a standard Python distribution for new environments; the Cloud
SDK interpreter includes vendored libraries which can override venv packages.

The Python image and setuptools builder are pinned; package installs verify the
checked-in SHA256 wheel hashes. To refresh hashes, use
`python backend/deploy/lock_dependencies.py --add name==version --receipt build/dependency-wheels.json`.
Review the version and artifact changes before committing the new lockfile.

Start `scripts/dev.ps1 -Action BackendWorker` in a second PowerShell process using
the same configuration. The script enforces the pinned engine; on a Linux host the
equivalent service command is `python -m bmt_backend.worker`.
The API's `/docs` and `/openapi.json` describe the exact request/response contract;
`/healthz` is process liveness and `/readyz` checks database/schema/storage readiness.
Liveness performs no dependency IO. Readiness coalesces concurrent requests,
has a two-second response deadline, caches schema/dependency success for two
seconds and performs deeper object write/read checks every 30 seconds on demand.
Observed API storage failures invalidate both caches immediately. An expired or
late probe returns 503; at most one dependency IO job runs per API instance.
See [readiness bounds and separate-process failure tests](../docs/BACKEND_READINESS_REPLICAS_2026_10_05.md).
Readiness does not prove that Google login or the external verifier is configured.
Workers handle SIGTERM/SIGINT, stop claiming jobs, allow five seconds to finish
(`BMT_WORKER_SHUTDOWN_GRACE_SECONDS`), then cooperatively cancel verification.
Interrupted leases retain their evidence and recover after expiry within existing
retry limits. `--once` also closes the verifier and database pool. Competition
health excludes draining/stopped workers and exposes five-minute processing,
failure and completion-latency measurements. See [lifecycle verification and
limits](../docs/BACKEND_WORKER_LIFECYCLE_2026_10_05.md).
Missing Google client IDs disable Google sign-in. Missing/wrong Godot prevents valid
track/record verification; no claimed client time becomes a verified record.

Committed race changes send best-effort wake hints outside the acceptance
transaction. PostgreSQL listeners borrow at most one connection from the existing
bounded pool while a worker is idle or foreground requests are waiting; ordinary
queries share the remaining pool. Idle listeners release it when no longer needed.
One-connection/custom unpooled engines use periodic checks instead. Queue leases,
checker policy, atomic rewards and durable receipts remain authoritative.
The capability `run_wait_ms=2000` enables one short client wait after a fresh upload
through `GET /v1/runs/{run_id}/wait?timeout_ms=2000`. The API defaults to four waiting
requests per process (`BMT_RUN_WAIT_CAPACITY`, 1..64), one per player; saturation
returns current status immediately. Keep this below HTTP concurrency so normal
requests retain capacity. Waiting holds no request SQL transaction or thread;
fresh authorization/ownership checks run before each reply. Lost hints, reconnects,
older APIs and wait failures retain normal status polling and saved upload identity.
Local HTTP measurements and acceptance limits:
[race confirmation evidence](../docs/evidence/race-confirmation-latency-2026-10-22/report.json).

The game's Development button uses `POST /v1/auth/developer` with
`X-Dev-Auth-Key`. The backend always selects the fixed `developer` account.
The lower-level `/auth/development` endpoint retains separate test identities for
multi-player API fixtures. Both require all three settings:
`BMT_ENVIRONMENT=development`, `BMT_DEV_AUTH_ENABLED=true`, and a random
`BMT_DEV_AUTH_KEY` of at least 32 characters. Use an isolated development database
on loopback. Production mode rejects development bypass configuration at startup;
the production Compose file disables it. These identities are distinct from Google
identities and are never silently linked.

For example, after configuring a disposable development database and object directory,
start the API from one PowerShell session and call its bypass from another:

```powershell
# API session; keep this generated key private, and use it only in this dev instance.
$env:BMT_ENVIRONMENT = 'development'
$env:BMT_DEV_AUTH_ENABLED = 'true'
$env:BMT_DEV_AUTH_KEY = (& .tools/backend-venv/Scripts/python -c 'import secrets; print(secrets.token_urlsafe(32))')
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendRun

# Second session: set the same BMT_DEV_AUTH_KEY privately, then sign in.
$login = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8080/v1/auth/developer' `
  -ContentType 'application/json' -Headers @{ 'X-Dev-Auth-Key' = $env:BMT_DEV_AUTH_KEY } -Body '{}'
Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/me' `
  -Headers @{ Authorization = "Bearer $($login.access_token)" }
```

The first command remains running, so the two parts are intentionally separate
sessions. The key/tokens are not saved by these commands. Launch the debug game from
a terminal with the same `BMT_DEV_AUTH_KEY` and `BMT_API_URL=http://127.0.0.1:8080`
using `scripts/dev.ps1 -Action Run`; select **Sign in → Development · developer**.
Release exports hide Development. Disabling server development auth also rejects
previously issued development access/refresh tokens.

Tests and dependency checking:

```powershell
# Set BMT_TEST_DATABASE_URL only to a disposable test database.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendTest
.tools/backend-venv/Scripts/python -m pip check
```

Do not point tests at a real player database. Current measured outcomes and remaining
acceptance checks are recorded in [BACKEND_V1.md](../docs/BACKEND_V1.md).

This workspace's disposable PostgreSQL fixture is `bmt-backend-test` in Ubuntu WSL,
listening at `localhost:55439`. Its ignored `.tools/backend-postgres.env` contains
`BMT_TEST_DATABASE_URL` for test discovery. It is stopped when testing finishes;
restart only that fixture with `wsl -d Ubuntu -- docker start bmt-backend-test` before
PostgreSQL tests, and stop it afterward. Its credentials are not production settings.

## Administrative Control Room

See [BACKEND_UI.md](../docs/BACKEND_UI.md) for the live `/admin` console, owner/analyst
configuration, supported workflows, verification and remaining prototype scope.
The PC launcher generates separate administrator credentials in its ignored env file.
Production administrator roles are disabled until their distinct keys are configured.

## Product observations and prepared analytics

Product telemetry is **off by default**. The API advertises the configured flag
through bootstrap; signed-in clients collect only when it is enabled. Guests are
not uploaded or linked retrospectively. Observed activity includes artificial
players under the owner's inclusive analytics policy. Client observations never
authorize race results, purchases, entitlements or rewards.

The valid authoring contract is
[product-events-v1.schema.json](schemas/product-events-v1.schema.json).
`POST /v1/telemetry/batches` requires a current player Bearer session and accepts
at most 50 events in a 64 KiB normalized compact JSON batch. Event IDs, session IDs
and optional batch/install IDs use UUIDv4; properties are restricted to the fixed
event catalog, five cars, five biomes and five offer IDs. Client identity, source
and artificial classification are not accepted payload fields.

The schema checks an entirely valid batch. Runtime ingress instead checks event
rows individually: a successful response contains one `accepted`, `duplicate`
or `rejected` acknowledgement per input position. Rejection reasons include
`INVALID_EVENT`, `CLOCK_OUTSIDE_WINDOW` and `ID_CONFLICT`. Accepted receipts
commit before acknowledgement; repeat the same immutable event IDs and payloads
after a lost reply. Invalid batch envelopes/contracts or optional batch/install
references receive HTTP 422,
oversized batches receive 413, and disabled collection or a full client backlog
receives 503 without acceptance acknowledgements. The occurrence window is seven
days old through 300 seconds ahead of server time. These relative-time,
persisted-ID and byte-size checks are enforced by the service, not JSON Schema.

Settings are shared by the configured API and the separate projector:

| Environment variable | Default | Allowed range |
|---|---:|---|
| `BMT_TELEMETRY_ENABLED` | `false` | `true` or `false` |
| `BMT_TELEMETRY_CLIENT_BACKLOG` | 50000 | 50–1000000 pending client receipts |
| `BMT_TELEMETRY_PROCESSOR_BATCH` | 500 | 1–1000 rows per projection pass |
| `BMT_TELEMETRY_RAW_DAYS` | 7 | 1–30 days |
| `BMT_TELEMETRY_FACT_DAYS` | 180 | 14–366 days |

The projector retains client receipts for the raw window plus a one-day retry
grace, and only retires receipts whose occurrence is also outside the seven-day
ingestion window. Server receipts become small deduplication tombstones.
Prepared facts have the configured reporting floor; earlier, future or
uncollected coverage is unknown. Cleanup runs in bounded chunks. Profiles keep
bounded milestone evidence, and cohort overflow is reported for the affected
prefix/window rather than presented as a zero result.

The matching API/projector artifact requires migration `0051_telemetry_parallel`
(including `0044_telemetry_counter_bigint`). Take and validate a database backup,
stop old projectors and drain old API, simulator and authoritative-event writers
before migrating. Old binaries must stay fenced after activation: their writes
cannot participate in the new ownership and credit protocol. The migration
preserves prepared historical totals and per-player state; it does not rebuild
retired raw history. PostgreSQL indexes build concurrently, and an interrupted
index build can be retried. Widening the prepared `product_metrics.value` column
still requires a maintenance window and space for PostgreSQL's table rewrite;
size that table and check lock/statement timeouts before rollout.

Start the matching workers to route existing pending receipts in bounded
batches. Client collection returns `TELEMETRY_PREPARING` until legacy routing
finishes; previously accepted receipts remain durable. If the old pending client
population exceeds the selected capacity, drain it with the old projector before
cutover, or provision sufficient capacity. Every service must use the same
`BMT_TELEMETRY_CLIENT_BACKLOG`; resizing serializes only the short credit-pool
change and rejects a shrink below occupied credits. These instructions do not
migrate a live database or activate services.

Run projection **separately from competitive verification workers**, using the
same database and reviewed settings:

```console
python -m bmt_backend.product_worker --once
python -m bmt_backend.product_worker
python -m bmt_backend.product_worker --stage actor
python -m bmt_backend.product_worker --stage shared
python -m bmt_backend.product_worker --stage rollup
python -m bmt_backend.product_worker --stage maintenance
```

`--once` performs one bounded pass. With `--stage all` (the default), a service
rotates player projection, shared-fact reduction and incremental metric folds.
Multiple PostgreSQL processes claim independent logical partitions with
`SKIP LOCKED`; each process uses one connection with no pool overflow. Separate
roles can be scaled when measurements identify a stage bottleneck. Player
ownership and append coordination use different rows, so a projecting player
does not block collection. A hot shared context still has one reducer.
Before a player's next batch, its previous metric contribution must be folded;
this prevents a late negative restatement from reaching totals before the
positive contribution it corrects.

Client credits remain occupied until all required derived work commits. Exact
retries use no extra credits. Temporary credit contention returns
`TELEMETRY_ADMISSION_BUSY`; exhausted capacity returns `TELEMETRY_BACKLOG_FULL`.
Idle polling backs off from 50 ms to two seconds. Failed owners roll back and
back off while unrelated owners continue. Reporting refreshes every five seconds
using committed input and fold barriers, independently of new receipts. It
exposes protocol 2 coverage metadata. Maintenance drains bounded chunks while
work remains and checks again after a minute when idle. SIGINT/SIGTERM closes
the pool. Collection-disabled processes exit before opening it.

The published barrier is a completeness lower bound. Prepared totals can also
include newer provisional contributions; `counts_include_provisional_tail`
states this explicitly. They are cumulative reporting snapshots, with the
existing seven-day late-arrival policy, rather than immutable event-time totals.

Roll back concurrency by running one **new-protocol** `--stage all` process.
Migration downgrade to legacy binaries is refused; it requires a reconciled
backup or an independently reviewed tail-consolidation procedure. Deployment
files do not launch additional replicas automatically. Representative sustained
HTTP load, skew, storage/WAL, gameplay latency and restore testing remain rollout
gates; local concurrency tests do not qualify a million daily players. See the
[implementation evidence](../docs/evidence/telemetry-parallelism-2026-10-22/report.json).

Studio's `GET /v1/admin/product-analytics` reads one bounded prepared bundle for
at most 90 UTC days. It does not scan raw event history or reconstruct behaviour
from account creation, issued tickets or old race rows. The view distinguishes
observed completion from accepted results, mature exact-day cohorts from missing
follow-up, and Store/social observations from verified payment outcomes.
See [implementation, measurements and remaining acceptance](../docs/PRODUCT_TELEMETRY_2026_10_11.md).

# Race challenges (2026-10-08)

The local API/worker now supports pinned Beat my time and Group challenges, owned verified targets, invitation codes, canonical ghosts and best-only results. Migration `0020_challenges` must precede deployment of the matching API/worker. This feature has been verified against disposable local services; the retained development backend has not been changed. See [CHALLENGES.md](../docs/CHALLENGES.md) for endpoint contracts, actual tests, native sharing/link configuration, screenshots and remaining device/deployment acceptance.

Studio expansion local checkpoint: [scope and validation](../docs/STUDIO_EXPANSION_2026_10_11.md). Additive local migrations 0026/0027 supply cases/quarantine and prepared quality facts. `BMT_CLIENT_QUALITY_ENABLED=true` requires product telemetry and negotiated client support; default false. New Studio workspaces inspect existing evidence or bounded counters. Signed-in reports/appeals are connected to the game by the [public-content safety implementation and moderation runbook](../docs/PUBLIC_CONTENT_SAFETY.md). Enhanced capture, live provider fulfillment/reconciliation, complete reversal ledger, recovery and production compensation remain unavailable. No automatic deployment is authorized by this local change.

## Public-content safety

Migration `0036_community_safety` records versioned publication-rules acceptance, private account blocks and explicit reported-player case targets. The matching game provides Report track / Report player, block/unblock, report status and appeals in Settings → Privacy → Community safety. Fresh publication and legacy upload paths require the current acceptance before storing user content. Blocks cover discovery, downloads, new race/challenge interactions and cached game presentation; quarantined tracks lose public documents and pinned Rivalry artwork/text while historical scores remain. The Backend Studio owner is responsible for daily case review and the existing audited content/account actions. See the [operating assignment, flows, tests and rollout limits](../docs/PUBLIC_CONTENT_SAFETY.md). Applying migrations or deploying a matching client/service remains a separate release action.

## Account privacy and erasure journal

Migration0034 adds irreversible account removal with retained public tracks/standings, optional analytics off by default, public `/privacy` and `/account-deletion` resources, and an independent erasure journal. Configure `BMT_PRIVACY_DEVELOPER_NAME`, `BMT_PRIVACY_CONTACT_EMAIL`, `BMT_PRIVACY_BACKUP_DAYS` (30) and `BMT_PRIVACY_PURCHASE_DAYS` (365). Preserve the sibling local object directory or the separate cloud journal prefix through backups/restores; do not restore that journal to an older snapshot. See [account privacy implementation and offline restore runbook](../docs/ACCOUNT_PRIVACY_2026_10_14.md).

The [final combined backend review](../docs/evidence/backend-final-review-2026-10-14/review.json) checks the attack fixes together with account erasure, database migrations and process recovery. Discovery responses now report the actual remaining snapshot lifetime. Host reboot/power-loss and production rollout remain separate acceptance checks.

## Garage News

Migration `0038_garage_news` follows the concurrent `0037_earned_coins` migration.
Deploy matching API/worker/client artifacts together; bootstrap advertises
`garage_news_version: 1`. This implementation has not migrated or deployed any
retained backend. The native Garage adds News and a private mutual-friends list.

Verified public results capture distinct physical-track milestones at 100, 1,000
and 10,000 racers and new track/lap world records. Participation deduplicates a
player across cars and immutable revisions. Migration seeds existing participation
without historical alerts; a fresh track seeds any existing creator participation
once on first use. Ties and slower results never announce records. Competitive
comparisons retain the exact pinned track revision, car and rules. Removed
accounts' historical times remain in the competitive population.

`GET /v1/news` is a private keyset-paginated read (30 items plus one lookahead),
with no counts, track-document reads or scheduled work. `POST /v1/news/refresh` requests
one comparison pass per UTC day. The request expires after ten minutes; an expired
or completed player has no runnable job, and tomorrow never queues automatically.
Only opening News renews demand. An interrupted pass resumes its cursor that day.
The existing idle worker handles at most eight raced boards per transaction;
accepted races and publication work retain priority. All raced public boards can
be visited through successive batches, without truncating a player's history.

Migration `0039_friend_publications` also records one shared first-publication
fact per new physical track, atomically with successful publication. There is no
friend fan-out, historical backfill or new worker job; new revisions and retries
do not announce another track. Both verified Publish and the legacy publish path
use the same capture. A single conditional insert checks for older published
revisions and deduplicates the fact.

Opening News merges these facts into the existing feed using the same keyset
cursor. One bounded roster read covers at most100 accepted friends; when friends
exist, one batched statement takes up to31 eligible recent rows per author from
the owner/time index and selects only31 outlines for the merge. It does not issue
one query per friend. Tracks must have been published since friendship acceptance
and within90 days. Current blocks, account restrictions, hidden/archived tracks
and removals are rechecked. The existing scoped60-second client cache applies;
publications can appear on the next feed read without another daily rank job.
Unfriending immediately removes cached publication stories. The existing indexed
expiry sweep shares its100-row/minute budget between inbox items and these facts.
See [friend-publication implementation and evidence](../docs/GARAGE_FRIEND_PUBLICATIONS_2026_10_16.md).

Unchanged board revisions and friend rosters skip comparisons and their JSON
snapshots. Changed batches fetch race/lap friend PBs in two bounded queries,
with at most 100 mutual friends. SQL returns nine compact percentile cutoffs
per metric, shared by all demanding players. A board's changed cutoffs rebuild
at most once per UTC day, only on demand; unchanged cutoffs remain reusable.
Ranking calculations lock only the presentation cache, not the competitive board.
The initial pass establishes a baseline. Later daily passes report observed
percentile drops and friend overtakes, including after an inactive player returns.
Brief crossings that reverse between checks are not an event archive. New
friendships establish a baseline rather than generating old defeat alerts.

Friend APIs are private: GET/POST `/v1/news/friends`, PUT to accept an incoming
request and DELETE to remove/decline/cancel `/v1/news/friends/{player_id}`. Requests
use the exact racing name and count toward both players' 100-relationship limit.
Blocks apply in both directions; hidden tracks and blocked creators/actors are
excluded from feeds. Cached native items disappear immediately on a local block.
Account erasure removes private news, watches, demand and friendships in bounded
chunks and redacts retained actor references. Shared recipient key locks fence
deletion; finalizers retain exclusive non-key actor locks to avoid crossed-inbox
deadlocks while preserving account restriction serialization.

The client keeps at most 100 news rows in memory, shares account/origin-scoped
60-second reads, and never polls while hidden/prepared/outgoing. A requested daily
pass has at most four visible follow-up reads with backoff. Feed pages exclude
items older than 90 days; indexed idle maintenance prunes at most 100 expired
items per minute, while active passes prune up to 100 excess inbox rows toward
the newest 100. No push service or additional always-on worker is introduced.

Actual tests, native fixture views, initial failures, source hashes and limits:
[Garage News evidence](../docs/evidence/garage-news-2026-10-16/report.json).
Phone touch/performance and production capacity remain unmeasured.
