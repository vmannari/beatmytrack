# Beat my track backend

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

The matching API/projector artifact requires migration
`0025_product_telemetry` after `0024_lap_personal_bests`. Apply the normal
backup, migration and rollback procedure to an explicitly selected environment
before enabling collection. This documentation does not migrate a database,
activate a live service or create infrastructure.

Run projection **separately from competitive verification workers**, using the
same database and reviewed settings:

```console
python -m bmt_backend.product_worker --once
python -m bmt_backend.product_worker
```

`--once` performs one bounded pass, not a complete backlog drain. The service
uses one database connection with no pool overflow, yields between pending
batches, backs idle checks off through 15/30/60 seconds, and schedules idle
maintenance at most once per minute. SIGINT/SIGTERM stops its loop and closes
the pool. With collection disabled it exits before opening that pool. Existing
deployment files do not launch this process or activate infrastructure
automatically; an operator must configure the separate service explicitly.

Studio's `GET /v1/admin/product-analytics` reads one bounded prepared bundle for
at most 90 UTC days. It does not scan raw event history or reconstruct behaviour
from account creation, issued tickets or old race rows. The view distinguishes
observed completion from accepted results, mature exact-day cohorts from missing
follow-up, and Store/social observations from verified payment outcomes.
See [implementation, measurements and remaining acceptance](../docs/PRODUCT_TELEMETRY_2026_10_11.md).

# Race challenges (2026-10-08)

The local API/worker now supports pinned Beat my time and Group challenges, owned verified targets, invitation codes, canonical ghosts and best-only results. Migration `0020_challenges` must precede deployment of the matching API/worker. This feature has been verified against disposable local services; the retained development backend has not been changed. See [CHALLENGES.md](../docs/CHALLENGES.md) for endpoint contracts, actual tests, native sharing/link configuration, screenshots and remaining device/deployment acceptance.

Studio expansion local checkpoint: [scope and validation](../docs/STUDIO_EXPANSION_2026_10_11.md). Additive local migrations 0026/0027 supply cases/quarantine and prepared quality facts. `BMT_CLIENT_QUALITY_ENABLED=true` requires product telemetry and negotiated client support; default false. New Studio workspaces inspect existing evidence or bounded counters. Signed-in report/appeal API exists; in-game report UI, enhanced capture, live provider fulfillment/reconciliation, complete reversal ledger, recovery and production compensation remain unavailable. No automatic deployment is authorized by this local change.

## Account privacy and erasure journal

Migration0034 adds irreversible account removal with retained public tracks/standings, optional analytics off by default, public `/privacy` and `/account-deletion` resources, and an independent erasure journal. Configure `BMT_PRIVACY_DEVELOPER_NAME`, `BMT_PRIVACY_CONTACT_EMAIL`, `BMT_PRIVACY_BACKUP_DAYS` (30) and `BMT_PRIVACY_PURCHASE_DAYS` (365). Preserve the sibling local object directory or the separate cloud journal prefix through backups/restores; do not restore that journal to an older snapshot. See [account privacy implementation and offline restore runbook](../docs/ACCOUNT_PRIVACY_2026_10_14.md).

The [final combined backend review](../docs/evidence/backend-final-review-2026-10-14/review.json) checks the attack fixes together with account erasure, database migrations and process recovery. Discovery responses now report the actual remaining snapshot lifetime. Host reboot/power-loss and production rollout remain separate acceptance checks.
