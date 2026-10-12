2026-10-05 readiness/replica failures: `/healthz` performs no dependency IO; `/readyz` coalesces requests with a two-second HTTP deadline, two-second success cache and 30-second on-demand deep-storage interval. API storage errors invalidate caches immediately. `BMT_READINESS_CACHE_SECONDS`, `BMT_READINESS_STORAGE_CACHE_SECONDS` and `BMT_READINESS_TIMEOUT_SECONDS` configure these bounded defaults. Keep external probe timeouts above the application's deadline. Synthetic separate-process tests cover shared sessions, concurrent retries/resource consumption, storage faults, killed/stale workers and SQL finalization recovery. No existing services were restarted/migrated. [Actual checks and limits](../../docs/BACKEND_READINESS_REPLICAS_2026_10_05.md).

2026-10-05 worker lifecycle: SIGTERM/SIGINT stop claims and mark draining, with a configurable five-second canonical finish grace, cooperative cancellation and verifier/pool cleanup including `--once`. Set `BMT_WORKER_SHUTDOWN_GRACE_SECONDS` below the platform termination allowance, reserving time for existing bounded database/object IO and cleanup. PC Compose grants 30 seconds; the NAS template retains 210 seconds. An unavailable heartbeat DB or SIGKILL relies on stale-heartbeat/lease expiry. This source change did not restart existing services. [Actual checks and acceptance](../../docs/BACKEND_WORKER_LIFECYCLE_2026_10_05.md).

2026-10-05 scalability repairs: current head is `0014_storage_lifecycle`. Online retention uses publication/read pins; the default backup pauses only GC and streams immutable objects while writers continue. Explicit `BMT_BACKUP_MODE=offline` retains the stopped-writer path. Role pool budgets and optional S3 configuration are documented in [the repair report](../../docs/BACKEND_SCALABILITY_FIXES_2026_10_05.md) and [load tooling](../LOAD_TESTING.md). No existing service was migrated or deployed.

2026-10-04 artificial test drivers require migration `0012_test_drivers` and matching API/worker/verifier artifacts. They are explicitly gated by `BMT_TEST_DRIVERS_ENABLED=true` plus development authentication. Production configuration rejects this flag. The local PC launcher accepts `BackendStart -TestDrivers`; fill/fleet/tick/watch tools run through normal verified race uploads into isolated test boards and groups. No existing service or production rollout was performed. See [setup, actual verification and limits](../../docs/TEST_DRIVERS.md).

2026-10-04 Weekly Rivalry requires migration `0011_weekly_rivalry` and matching
API/worker images. The standalone verifier now includes derived ghost recording
and the pure bridge elevation sampler. Keep the existing rules v18 / physics
0.50 contract; no driving rule changes accompany rivalry. Migrate a backed-up
database to the current head using the existing deployment procedure, then run
the rebuilt API and worker together. Existing official tracks are identified by
the reserved `developer` identity, not the creator's display name. New weekly
groups need five eligible published tracks; no sample player field is seeded.
This task tested disposable local services only and did not rebuild/restart the
existing services, migrate their database or deploy to the NAS/production.
See [implementation and actual verification](../../docs/WEEKLY_RIVALRY.md).

2026-10-03 launch-start update: the current source uses rules v18 / physics 0.50.
Rebuild API and verifier together before online client acceptance; existing running
services were not rebuilt by this task. v18 adds a tick-zero launch input marker,
reaction assistance and early-pedal delay. Historical board rows remain pinned.
See [launch start](../../docs/LAUNCH_START.md) for actual tests and limits.

# DS925+ deployment and cloud migration

The [second/third review repairs](../../docs/CODE_REVIEW_REPAIRS_2_3_2026_10_03.md) require the archive/head endpoints and complete worker heartbeat contract alongside migration `0010_archive_drafts`. Competition health checks Python compatibility against the raw verifier and every pinned build/vehicle field; an old heartbeat cannot establish readiness. Retention inspects at most 1,000 entries per batch and returns `next_object_cursor`; pass its JSON through `--object-cursor` for the next batch. Applying uses `--online` with the pinned adapter; `--offline` remains available with stopped writers. Directory cursors are best-effort; begin another cycle after directory-changing cleanup. Actual SQLite/engine/client results and unavailable PostgreSQL/device/NAS acceptance are recorded in that repair document. This repair task did not restart or deploy services.

The October reliability fixes require migration to the current Alembic head
(currently `0014_storage_lifecycle`, including `0013_scalability`, `0012_test_drivers`, including `0011_weekly_rivalry`, `0008_review_reliability`,
`0009_track_lifecycle` and `0010_archive_drafts`) and a matching rules-v18 canonical verifier image. Keep historical boards pinned; an
old in-flight contract fails explicitly instead of being rescored with new rules.

The [bridge-exit checkpoint repair](../../docs/BRIDGE_EXIT_CHECKPOINTS.md) adds
v17 gate orientation near ramp ends while retaining the v16 exact-crossing layer
checks. The local PC API/worker were rebuilt successfully on 2026-10-03; both
contain the exact workspace checkpoint source. Live readiness/manifest and
desktop/Linux verification of actual Over and under and Dust cloud five-lap
recordings pass with unchanged ticks. This supersedes the earlier WSL lock and
mixed-build observations. No NAS/production rollout was performed.

The earlier [Dust cloud repair](../../docs/DUST_CLOUD_CHECKPOINTS.md) introduced
route-continuous bridge gate layers in v15, and the
[fast bridge repair](../../docs/BRIDGE_ENTRY_CHECKPOINTS.md) introduced crossing
layer validation in v16. Both remain covered by the current verifier.
Migrations and canonical verification were tested locally. The release image needs
rebuilding with the matching verifier before rollout; no NAS/production rollout was
performed. See [review fixes and acceptance](../../docs/CODE_REVIEW_FIXES_2026_10_03.md).

The authenticated `/v1/admin/competition-health` endpoint and console System page
report worker freshness/build, race and track-validation backlog, oldest job age,
recent arrivals/completions/failure codes, an explicitly approximate wait estimate
and object-volume free space. API readiness remains independent of workers.
Defaults are `BMT_MAX_QUEUED_RUNS=128`, `BMT_WORKER_STALE_SECONDS=300` and
`BMT_RETENTION_DAYS=90`; tune against deployed measurements. A stopped worker must
trigger an operational alert even when `/readyz` succeeds. Optional
`BMT_BACKUP_MARKER_PATH` points to a read-only mounted latest successful `COMPLETE`
marker. Add that mount and environment value in a Compose override; without them,
backup status is honestly `not_configured`. Marker freshness does not prove restore.

Discovery stores compact preview projections. For an existing installation, repeat
`python -m bmt_backend.maintenance --backfill-discovery` until `backfilled` is zero;
each invocation processes at most 100 legacy versions. Optional
[`search-indexes.sql`](search-indexes.sql) adds PostgreSQL lower-case trigram indexes
matching substring search. It requires authorized database-owner extension setup;
execute outside a transaction because indexes build concurrently. No application
runtime database privilege is expanded. Short terms and broad combined searches
can still scan metadata; verify actual plans after backfill.

Reference-aware race retention is opt-in. `python -m bmt_backend.maintenance
--retention` reports candidates without changing records or files. After a backup,
review the counts and run the same command with `--apply-retention --online` to
coordinate with shared publication/read pins while writers continue. Repeat bounded
batches and pass the returned cursor. The explicit `--offline` alternative requires
stopping API and every worker, then restarting writers after maintenance. Retention protects every immutable track version, current PB
replay, creator publication proof and permanent resume grant/wallet. It retires old
terminal non-PB attempts and expired expendable tickets/races/receipts, retains
legacy idempotency tombstones, and removes only aged unreferenced SHA256 JSON objects
inside the resolved object root. Only coordinated `--online` GC may run with active writers.
No player data or deployed objects were pruned during this repair.

Local PC development: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendStart` builds the shared API/worker image before starting services. Python is bind-mounted, but canonical Godot validation code is baked into the image. The build checks the pinned engine and exact golden replay before replacing services; a failed build leaves the running backend intact. Accounts and tracks remain in existing volumes. See [bridge validation follow-up](../../docs/BACKEND_BRIDGE_VALIDATION.md).

Account-menu follow-up: migrate to `0005_unique_username` and set
`BMT_GOOGLE_WEB_CLIENT_ID` as well as `BMT_GOOGLE_CLIENT_IDS` for browser sign-in.
The game's API URL and `BMT_PUBLIC_BASE_URL` must be the same origin registered in
Google's Authorized JavaScript origins. See [account setup](../../docs/ACCOUNT_SIGN_IN.md).

This is a deployment package, not evidence of a deployed server. Run commands from
the repository root on the Linux container host unless stated otherwise. The NAS
must have Synology Container Manager and a Compose version supporting health-based
dependencies, one-shot migration completion and resource limits. Confirm with
`docker compose version` and `docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml config --quiet`.
Do not expose `docker compose config` output: it includes database passwords.

## Prepare the pinned verifier

The repository pins **4.7.2.stable.official.ed1daf0bf**. Obtain a trusted **Linux
x86_64 standard Godot binary** matching that entire string and independently verify
its published checksum. Put the executable at `backend/deploy/vendor/godot` (ignored
by Git). Set `GODOT_SHA256` in `.env` to the verified executable SHA256. If no trusted
matching build is available, server verification deployment is blocked: a different
engine must not be substituted. No download URL or current release is assumed.

The initial build was tested using the [official 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable),
with archive SHA256 and SHA512 verified before extraction. Its Linux executable
SHA256 is `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.
See [actual container/replay/restore results](../../docs/BACKEND_V1.md); these do not
claim a physical NAS deployment.

Both the API (track validation) and worker (race verification) use that engine.
`stage_verifier.py` copies an explicit canonical source/resource set into a minimal
project, excluding menus, textures, the native music extension and legacy content.
The image build checks the binary checksum, exact version, Godot import output and
the Windows-recorded five-lap regression (12,757 ticks with matching per-lap ticks).
Script errors or cross-platform replay divergence fail the build even if Godot exits
zero. Export templates are not
required because the server runs source scripts headlessly, without exporting.

## Configure and start

```sh
python3 backend/deploy/init_env.py
# Edit backend/deploy/.env privately:
# BMT_PUBLIC_BASE_URL=https://your-api-domain
# BMT_GOOGLE_CLIENT_IDS=allowed-client-id.apps.googleusercontent.com
# GODOT_SHA256=<independently verified executable checksum>
chmod 600 backend/deploy/.env
docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml config --quiet
docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml build
docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml up -d
docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml ps
curl --fail http://127.0.0.1:8080/readyz
```

Generate the configuration on the NAS, or copy it securely from an administration
machine with Python. Keep it outside backups that are publicly accessible. The init
script uses exclusive creation and never overwrites credentials. The API runtime
database role owns its schema for migrations but has no superuser, database-creation
or role-creation privileges. Postgres initialization scripts run only on an empty
volume; changing `.env` passwords later also requires rotating database roles.

Set up a DSM reverse proxy rule: HTTPS on the chosen public hostname and port 443 to
`http://127.0.0.1:8080`. Install a valid certificate for that hostname. Permit inbound
443 only as needed; keep DSM administration, Docker and PostgreSQL off the public
internet. The API binds loopback; PostgreSQL has no host port; the verifier has only
the internal network. The API also has an egress network to fetch Google's signing
certificates. `BMT_TRUSTED_PROXY_IPS` defaults to `127.0.0.1`; set it to the exact
immediate DSM proxy address(es) visible inside the API container (often the Docker
bridge gateway for a host reverse proxy). Never use `*` or trust the whole internet.
Configure DSM to overwrite forwarded client headers and verify spoofed headers from
an untrusted peer are ignored. Only Uvicorn's trusted-proxy handling determines the
client address used by request limits. Share URLs come from the fixed HTTPS origin.

Configure reverse-proxy request size and read timeouts to cover the API's bounded
track/replay payloads and track validation (up to 90 seconds). Apply edge/IP request
limits before broad public registration. Until the immediate proxy address is trusted,
all proxied requests share the proxy's IP quota; confirm client IP/rate behavior and
tune edge/application limits together before public load. The direct-image command
ignores forwarded headers, while Compose enables only the configured allowlist.

The starting resource limits are API 640 MiB/1 CPU, worker 768 MiB/1 CPU, PostgreSQL
768 MiB/1.5 CPU, and migration 256 MiB/0.5 CPU. One replay runs per worker. These are
initial limits for a 4 GB NAS, not capacity claims. Account for DSM, storage services,
backups, peak track compilation and any other applications before increasing limits.
Read-only API/worker root filesystems, nonroot users, dropped capabilities, bounded
temporary space and rotating logs are set in Compose. Database and objects live in
separate named volumes, surviving container/image replacement.

## Verify the installation

Check `/healthz`, `/readyz`, migration success, API and worker logs. Then use a real
configured Google ID token with the nonce challenge flow, publish a track with its
creator completion proof, download it from another account, submit a complete replay,
wait for validation, query the exact rules-key leaderboard, and update a rating from
the other account. Also submit a forged/incomplete race and confirm it never appears
as verified. `/readyz` alone cannot prove this flow. Use the current `/docs` request
schemas instead of copying credentials into shell history.

No production development-auth bypass is enabled. For an isolated development server
see [the backend README](../README.md); never share its database with production.

## Backup and restore

The supplied scripts use Docker Compose, POSIX `sh`, `sha256sum`, `sed` and standard
host utilities. The default online mode pauses only object GC before PostgreSQL's
custom-format snapshot dump, then streams the immutable objects needed by that dump.
API reads, writes and workers continue. A crash before cleanup leaves GC paused until the
matching private recovery token releases it. Explicit `BMT_BACKUP_MODE=offline`
stops API/workers and restarts only previously running writers, including after failure.

```sh
sh backend/deploy/backup.sh /volume1/backup/bmt/2026-09-28T220000Z
```

The destination must be new. A completed backup has `database.dump`, `objects.tar`,
`backup.info`, `SHA256SUMS` and `COMPLETE`. The completion marker is written only after guard cleanup (or offline writer
restart) succeeds. A missing completion marker is an unaccepted backup. No secrets or live PostgreSQL data-directory files are copied. Keep release
image digests, canonical game sources, the verified Godot binary and encrypted
deployment credentials separately so the matching version can be recovered.

The restore script verifies checksums and restores only into an explicitly named
**different, empty Compose project**. It refuses existing application containers,
nonempty database schemas and nonempty object volumes. It does not start API/worker.
Archive extraction rejects absolute paths, traversal, symlinks, hard links, special
files and duplicate file entries. A restore failure can leave data in the new target;
investigate and use another fresh target name instead of rerunning over it.

```sh
sh backend/deploy/restore.sh /volume1/backup/bmt/2026-09-28T220000Z bmt-restore-check
# Choose an unused port, then start the restored deployment explicitly:
BMT_PORT=18080 docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml -p bmt-restore-check up -d
curl --fail http://127.0.0.1:18080/readyz
```

Use an isolated restore test with the original image/version first. Verify accounts,
immutable hashes, published tracks, PB rows, replay downloads and queue state before
switching proxy traffic. Test the restore procedure after every schema/storage change.
Schedule nightly backups initially, copy encrypted backups off the NAS, monitor
completion/disk capacity and retain multiple generations. A proposed nightly schedule
has up to 24 hours of data loss; no RPO/RTO is promised until measured and accepted.
Use PostgreSQL WAL archiving/managed point-in-time recovery when that objective needs
to improve. NAS RAID and snapshots alone are not a tested offsite recovery plan.

## Updates, monitoring and recovery

Build release images from a reviewed commit, record resolved base-image and release
digests, and retest before rollout. Tags in this initial manifest pin major families;
freeze tested digests in a release override for production reproducibility, and update
deliberately for security patches. Back up before migration; future migrations must
preserve rolling compatibility if zero-downtime updates become a requirement. A code
rollback across an incompatible schema requires the matching backup/image pair.

Watch HTTP error rate/p95 latency, process restarts, DB connections/slow queries,
volume free space, pending/expired verification jobs, validation duration/rejection
rate and backup age. Container `running` does not prove worker progress: inspect queue
age and logs. Alert when the oldest pending job exceeds the chosen service objective.
Uvicorn access logging is disabled to avoid logging raw paths/query strings; application
logs use allowlisted route/status/duration/request fields. PostgreSQL slow-query logs
omit parameter values. Do not log tokens or full replay/request bodies. Public launch still
needs a measured load test, external health alerting, a recovery drill and abuse review.

Schedule the bounded maintenance command hourly through DSM Task Scheduler to purge
expired request-rate buckets, login challenges and session records:

```sh
docker compose --env-file backend/deploy/.env -f backend/deploy/compose.yaml run --rm migrate python -m bmt_backend.maintenance
```

This default authentication cleanup does not delete track or race history. Opt-in
reference-aware race/object retention is described above. Account deletion and
shared-content retirement still require separate policies.

## Migration to cloud

1. Keep player UUIDs, track/version IDs, rules keys and SHA256 object keys unchanged.
   Provision managed PostgreSQL 17, a container service/VM and private storage/networking.
   Use verified database TLS (`sslmode=verify-full` with the provider CA) across hosts.
2. Run the tested image on the cloud host; restore a NAS backup into an isolated
   database and object volume, exercise real authentication and canonical verification,
   and measure the workload. The first cloud move can keep the filesystem adapter on
   one durable volume and one API replica.
3. Implement/test the S3-compatible storage adapter behind the object-store interface;
   upload existing objects using identical keys and verify every checksum. Do not mount
   a FUSE bucket and assume the local adapter's atomic hard-link/filesystem semantics.
4. Switch the storage adapter only after backfill verification and rollback tests. Then
   place stateless API replicas behind a load balancer and scale replay workers against
   queue age. Keep a bounded connection pool per replica; use a pooler when measured
   connection pressure warrants it. Separate worker pools by pinned rules/engine version.
5. Quiesce NAS writes, take the final consistent backup/copy, restore/catch up, run checks,
   switch the stable DNS origin and resume traffic. Keep the NAS snapshot read-only until
   rollback retention expires. A later near-zero-downtime move can use managed logical
   replication after a rehearsed compatibility design.

At larger scale, use query measurements to add leaderboard/discovery caches and
histogram aggregates, CDN delivery for public immutable tracks, object retention/GC,
partitioned race history and dedicated asynchronous workers. Keep private ghosts
authorized. Add an external broker only when the PostgreSQL job queue becomes the
measured bottleneck. Real-time multiplayer belongs in a separately deployed session
service; it does not run inside HTTP handlers or this replay worker. Neither 100k nor
1M registered players determines capacity without concurrency, request mix, replay
lengths, retention and load measurements.

## Sources used for these decisions

The DS925+ has a 64-bit Ryzen V1500B and 4 GB base memory according to
[Synology's specification](https://www.synology.com/en-global/products/DS925%2B).
Compose waits for dependencies only when their health/completion conditions are
declared; see [Docker startup ordering](https://docs.docker.com/compose/how-tos/startup-order/).
The plain Python image and one process per container follow
[FastAPI container guidance](https://fastapi.tiangolo.com/deployment/docker/).
Custom PostgreSQL dumps are portable logical backups suitable for restore into
another PostgreSQL host; see [PostgreSQL 17 pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html).


## Scalability configuration and backups

API pools default to four connections with zero overflow; worker pools use two. Connection/pool waits are three seconds; PostgreSQL statements are bounded. Budget all API/worker/migration/backup/admin pools against the configured 40 database connections before scaling. A worker caches only immutable tracks; its pinned engine is recycled and its process remains separate from HTTP. Measure verification service time and queue age on the NAS before selecting worker count. Increasing replicas without enough CPU or memory reduces capacity.

Public track validation always queues. `BMT_ALLOW_SYNC_TRACK_VALIDATION=true` is only for explicitly configured non-production tests/development. New clients negotiate compact inputs/gzip/batched status from bootstrap; unadvertised servers receive legacy canonical frames and individual polling. Update API/worker together, then verify the client contract; no deployment is included in this task.

`python -m bmt_backend.maintenance --retention --apply-retention --online` uses shared publication pins and bounded resumable batches. Closed weeks archive after the retention interval, keeping scores and membership while releasing optional evidence; public PBs, creator proofs and immutable track versions stay protected. `--offline` remains an alternative with all writers stopped. Dry-run remains the default. Run another complete object scan after a changing-directory cleanup. Timestamped v2 retry keys expire; legacy keys and permanent fulfillment/grant identities remain protected.

`backup.sh` defaults to `BMT_BACKUP_MODE=online`. It acquires the shared GC guard before `pg_dump`, streams immutable objects, writes checksums/completion, then releases the guard. A crash leaves GC paused, while API and workers continue. Recover using the private `GC_RECOVERY_TOKEN` with `python -m bmt_backend.backup_guard end --token <saved-token>`; the token must match the active guard. The completion marker is written after successful cleanup; guard-release or writer-restart failures keep it absent. Rehearse restore into a different empty project with the matching image/schema before switching traffic. The task tested pg_dump/archive/restore with live synthetic writes; the complete Compose wrapper needs target-host acceptance.

The optional `compose.cloud.yaml` selects an explicitly configured private HTTPS S3-compatible endpoint, bucket/prefix and credentials. Use it only after provider integration, access controls and backup/restore have been tested. `BMT_COMPOSE_CLOUD=1` adds that override to backup/restore helper commands. Provider backups stream bounded verified objects into the same portable archive; restore to a fresh **local** object volume (`BMT_COMPOSE_CLOUD=0`) first, verify hashes/PBs, then rehearse a separate verified transfer to the chosen provider before enabling its runtime configuration. Credentials are supplied privately and never included in artifacts. Default NAS configuration retains the local adapter and isolated worker network.
