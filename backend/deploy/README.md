# DS925+ deployment and cloud migration

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
host utilities. API/worker stop briefly while PostgreSQL's custom-format dump and an
object archive are captured. This gives one consistent recovery point for database
references and immutable files. The script restarts only previously running writers,
including after failure. Reads through the API are unavailable during this window.

```sh
sh backend/deploy/backup.sh /volume1/backup/bmt/2026-09-28T220000Z
```

The destination must be new. A completed backup has `database.dump`, `objects.tar`,
`backup.info`, `SHA256SUMS` and `COMPLETE`. A missing completion marker is a failed
backup. No secrets or live PostgreSQL data-directory files are copied. Keep release
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

This does not delete tracks, replays, ratings, PBs or idempotency records. Those need
a separate accepted retention and account-deletion policy.

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
