# Google Cloud staging

October 7: use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-backend.ps1` from the repository root to preview an update of the existing retained backend; add `-Apply` to execute. The reusable updater preserves the existing resource settings and data, with backup, ownership and acceptance checks. Use a quiet testing window; this is a retained-staging updater with no automatic rollback. [Commands, actual tests and limitations](../../../docs/GOOGLE_BACKEND_DEPLOY_SCRIPT.md). The disposable provisioning script below retains its changed-image refusal.

October 6 latest rollout: owner-authorized retained staging now runs compiler22 with matching immutable official-track revisions, backups and real Blind spot client-ticket acceptance. Compiler20 artificial-driver schedulers are paused pending new contract recordings. The disposable deploy guard remains unchanged. [Actual commands, checks and limitations](../../../docs/BACKEND_LATEST_2026_10_06.md).

October 6 latency follow-up: the retained API now keeps one service-level instance warm, with maximum two, after an observed 15.9-second first rivalry request. Optional api_min remains zero by default for new disposable staging and permits only zero/one. Actual min=1 adds about €0.38/day idle before credits/free tier; current image/auth/data are unchanged. [Commands, timings and limits](../../../docs/RIVALRY_LOADING_2026_10_06.md).

October 6 retention override: the owner requested keeping the previous tracks. All 27 official tracks and 34 original published links were copied with stable IDs/content; 26 current-build revisions preserve older rules snapshots. [Actual migration, retention and continuing costs](../../../docs/GCP_TRACK_RETENTION_2026_10_06.md). Automatic deletion is disabled, and local/remote retention guards reject cleanup. SQL deletion protection/seven daily backups and seven-day GCS recovery are enabled. The earlier testing deadline no longer authorizes deleting this data. The server remains retained staging.

Owner target: `beat-my-track`; owner reports credits expire in about 80 days from October 5, 2026. The owner-authorized staging deployment is now live in `europe-west1`; see [actual deployment, checks and remaining PC/Google acceptance](../../../docs/BACKEND_GCP_DEPLOYMENT_2026_10_05.md). The live configuration is ignored at `.tools/gcp-staging/config.json`. Exact remaining credit balance/expiry is still owner-reported, not verified through billing APIs.

October 6: the owner added the exact Avast website exception and the Windows app now uses staging with normal TLS trust. [Actual PC connection and renewed testing deadline](../../../docs/GCP_PC_CONNECTION_2026_10_06.md). The original cleanup did not execute overnight; its replacement scheduled-task authentication/ownership check was actually run and passed. Current lease: October 6 15:36:57 Helsinki, local task fallback 15:41:57. Real interactive Google and device acceptance remain pending.

`staging.py` provides `init`, `plan`, `deploy`, `smoke`, `cleanup` and `watch`. Commands are explicit argument arrays, always pin the project and default to a review plan. Mutations require `--apply` and the exact `--confirm-owner` identifier. Never use a production dataset with this disposable configuration.

## Architecture and limits

- One private Cloud Run API, scale-to-zero minimum and maximum two instances, one CPU/1 GiB and concurrency 16.
- One manually scaled worker pool, one CPU/768 MiB per worker; one or two workers are permitted by the connection budget.
- Cloud SQL PostgreSQL 17, Enterprise, zonal `db-custom-1-3840`, 10 GiB SSD without automatic growth, connector-only connections and 40 DB connections. Staging has no automated/final/retained backups; its data is explicitly disposable.
- A private GCS bucket with uniform IAM and public access prevention. Soft delete is disabled for this temporary bucket so cleanup does not leave billable retained test objects.
- Artifact Registry and Secret Manager. Root/app DB URLs are separate secrets pinned to version 1; passwords never enter process arguments, plans or logs. Cloud SQL user writes use authenticated JSON bodies. Secrets are reused on repeat runs.
- Runtime identity receives Cloud SQL client, app-secret access and bucket create/read/list permissions. Migration identity receives Cloud SQL client and only the admin secret. Diagnostic identity receives the app secret and bucket object-user permission to remove its own generated diagnostic prefix. No downloaded service-account keys are used.

Cloud SQL attachment uses the managed Unix socket in API, worker pool and jobs. The application role has table/sequence permissions but no create-role/create-database/replication/superuser privileges or access to the staging ownership guard. The migration job initializes an ownership guard before migrations, so interruption is resumable and a nonempty unrelated database cannot be adopted.

API, worker and migration/smoke jobs use one registry image digest. Existing resources with a different image are rejected: create a fresh staging owner/environment for source changes, then remove the previous one. This intentionally avoids the unresolved mixed-protocol/worker-build rollout gaps; it is not a general production upgrade mechanism.

## Prepare and review

Use the existing backend Python environment. The following commands write only local files:

```powershell
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py init --project beat-my-track --hours 4
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py plan
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py cleanup
```

The first command was already run in this workspace; it refuses to overwrite existing configuration. For a later session, create a different config path with `--config`, or review/update an unapplied configuration. The plan contains resource names, IAM grants, limits, expiry, image/secret bindings and deployment order; cleanup has its own exact removal preview. No resource is adopted or deleted without matching remote ownership labels/descriptions.

The current config uses a four-hour lease and EUR 40 review budget. **These are proposed caps/estimates, not provider enforcement.** Set `cost_reviewed`, `estimated_hourly_eur` and `pricing_checked_at` only after checking all-service pricing. Apply rejects stale pricing, expired leases, sample configs and estimated cost beyond the budget. Maximum initial budget is EUR 50. Ordinary Google budget alerts do not enforce this script's budget. [Cloud Billing budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets).

Install a current Google Cloud CLI and authenticate the operator through Google's browser flow. This workspace now has CLI 587.0.0 and an authenticated operator. Local ADC is absent; deployed containers obtain ADC through their attached identities. Local real-provider tests separately require operator ADC. No credentials should be pasted into chat or committed.

```text
gcloud auth login
gcloud auth application-default login
```

For native Windows, set the config's `gcloud` command array to the installed executable/wrapper, e.g. `['cmd.exe','/d','/c','gcloud.cmd']`. Its `docker` array is already prepared to use Ubuntu WSL and this repository's Linux path. Run from the existing Windows backend environment; Docker's temporary authentication directory is workspace-relative and removed after push. For another host, review these arrays and paths first.

Before mutations, preflight checks active CLI authentication, the exact active project, billing enabled and the installed GA worker-pool interface. The operator needs permission to enable service APIs and manage the named Cloud Run, Cloud SQL, GCS, registry, secret and service-account/IAM resources. Billing-link administration is not performed by this script.

## Apply, test and remove

Replace `OWNER_ID_FROM_CONFIG` with the full owner ID printed by the local plan. Start the cleanup watcher in a separate terminal before applying. It must remain running on a powered-on, authenticated machine; it is a local watcher, not a cloud-enforced spending cap or Cloud Scheduler deployment.

```powershell
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py watch --apply --confirm-owner OWNER_ID_FROM_CONFIG
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py deploy --apply --confirm-owner OWNER_ID_FROM_CONFIG
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py smoke --apply --confirm-owner OWNER_ID_FROM_CONFIG
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py cleanup --apply --confirm-owner OWNER_ID_FROM_CONFIG
```

Deployment creates only labeled resources, builds/checks the exact Linux engine and recorded canonical fixture, pushes and resolves an immutable digest, completes migration first, deploys API/worker and runs the native/storage smoke job. Initial API deploy discovers its URL; a same-image update sets the real browser origin before workers start. HTTP checks verify `/health`, `/ready` and `/v1/bootstrap` with the operator's identity token in `X-Serverless-Authorization`, preserving application bearer auth for later real-account tests. Cloud Run reserves some paths ending in `z`; `/healthz` was intercepted in the actual deployment. Existing `/healthz` and `/readyz` remain aliases for local/NAS probes. [Cloud Run reserved paths](https://docs.cloud.google.com/run/docs/known-issues#reserved-url-paths). Smoke jobs never create players, PBs, rewards or memberships.

Provisioning must finish before building/pushing. The build command now refuses an absent registry. If a newly created service account is temporarily unavailable to the IAM policy API, inspect the error and resume the same owned provisioning operation after propagation; ownership checks and existing secret versions remain enforced.

On any failure, inspect the named stage and run the cleanup preview/command. Cleanup first checks ownership of every existing target, then rechecks before each delete. It removes API/worker/jobs before data/registry/secrets/accounts and removes its Cloud SQL IAM bindings. It never deletes the project, billing account, enabled APIs or differently owned resources. Partial cleanup is safely retryable. Review `cleanup.json`; a failed cloud command is not reported as completed.

Private IAM ingress is the default. Browser/game account acceptance needs either authenticated proxy/headers or explicitly reviewed public staging with real Google client IDs. Public mode remains application-authenticated and has no development bypass. The HTTP server retains `--no-proxy-headers`: no wildcard proxy trust is introduced. Exact Cloud Run client-IP handling and public-edge abuse/rate behavior must be accepted before larger/public testing.

## Real GCS contract acceptance

The adapter has an opt-in real-provider test. Use operator ADC and a disposable bucket that the operator can create/read/list/delete objects in. Confirm its name explicitly:

```powershell
$env:BMT_TEST_GCS_BUCKET = 'OWNED_DISPOSABLE_BUCKET'
$env:BMT_TEST_GCS_CONFIRM_BUCKET = $env:BMT_TEST_GCS_BUCKET
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_gcs_storage.py -q -k real_gcs_contract
```

It uses a unique `bmt-contract/<uuid>` prefix and deletes only its test hashes. All other provider tests use an isolated HTTP transport. The staging smoke job repeats native verification and real storage checks from Cloud Run using attached identities; the actual deployed job passed. Real interactive Google sign-in, provider restore/credential revocation, proxy/cellular and measured capacity remain separate acceptance checks.

## Primary interfaces

The implementation follows [GCS conditional uploads](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert), [generation-conditioned deletion](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/delete), [Cloud SQL settings](https://docs.cloud.google.com/sql/docs/postgres/admin-api/rest/v1beta4/instances), [worker-pool deployment](https://docs.cloud.google.com/sdk/gcloud/reference/run/worker-pools/deploy) and [Cloud Run secret bindings](https://docs.cloud.google.com/run/docs/configuring/services/secrets). Bucket/SQL creation uses JSON API requests so ownership labels are atomic; the corresponding CLI create interfaces do not supply the needed labels uniformly.


## Isolated development population (October 6)

Owner-authorized simulated drivers are enabled on retained staging with a separate Secret Manager key, keeping Google accounts and public rankings separate. The minimal test-histogram API image preserves the exact canonical project and manifest. A 200-driver compact plan is populating all 27 current tracks through genuine verified races, and a focused test Weekly Rivalry is already populated. See [actual rollout, resumable commands and unfinished bulk population](../../../docs/CLOUD_TEST_DRIVERS_2026_10_06.md). The earlier disabled-auth descriptions apply to the original staging configuration; production defaults remain disabled.
