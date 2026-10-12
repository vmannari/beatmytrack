# Beat my track backend

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

Local API development (Python 3.10+; deployment image uses 3.12):

For this Windows PC, use `scripts/dev.ps1 -Action BackendStart`. It starts the
isolated WSL Docker stack at `http://127.0.0.1:18181` and saves the game's connection
and development key for normal editor launches. `BackendStop` stops the stack
without deleting data. This avoids the existing unrelated service on port 8080.
See [PC setup and Google client-ID steps](../docs/ACCOUNT_SIGN_IN.md).
The generic manual API setup below is for other separately configured environments.

```powershell
python -m venv .tools/backend-venv
.tools/backend-venv/Scripts/python -m pip install -r backend/requirements.lock
.tools/backend-venv/Scripts/python -m pip install --no-deps -e backend
# Set BMT_DATABASE_URL to a disposable PostgreSQL 17 database.
# Set BMT_OBJECT_DIR to an ignored development directory.
# Set BMT_GODOT_BIN to the exact binary from godot-version.txt.
# Set BMT_GAME_PROJECT to the absolute game directory; import it first.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendMigrate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendRun
```

Start `scripts/dev.ps1 -Action BackendWorker` in a second PowerShell process using
the same configuration. The script enforces the pinned engine; on a Linux host the
equivalent service command is `python -m bmt_backend.worker`.
The API's `/docs` and `/openapi.json` describe the exact request/response contract;
`/healthz` is process liveness and `/readyz` checks database/schema/storage readiness.
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
