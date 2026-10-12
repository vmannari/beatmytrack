# Native Google storage and repeatable staging — 2026-10-05

Owner authorized backlog items 6–7: native Google Cloud Storage, repeatable staging deployment and cleanup. Requirements B01–B07/B19/B20/B23/RW05–RW07/Q01. Owner supplied project `beat-my-track` and reports credit expiry in about 80 days. That interval is approximate; no precise billing expiry or current price estimate is inferred.

Implementation/tooling is complete locally. **Live Google-provider/deployment acceptance is not performed:** Google Cloud CLI is absent on Windows PATH and Ubuntu WSL; no local ADC environment/user file was found. No billed resources, image push, Google identities or credits were used. Existing WSL services/player data remain untouched. Source changes preserve previous lifecycle/readiness/scalability work.

## Storage implementation

`gcs_storage.py` uses the installed `google-auth`, `requests` and pinned HTTP dependencies; no new runtime package/API vendor is added. ADC discovery is lazy. Attached Cloud Run service-account identity or an operator's ADC provides short-lived credentials; no key files, credentials or release secrets are committed.

Native JSON API publications use gzip bytes, canonical SHA256 keys and `ifGenerationMatch=0`. A duplicate verifies the existing SHA256 document. Successful acknowledgement checks exact name, positive generation, compressed size and transport MD5. Content encoding metadata is omitted and identity download encoding requested to avoid unwanted provider decompression; bounded gzip decoding then verifies the canonical digest. Deletion first reads the generation and conditions deletion on that generation. Listings are prefix/shard scoped, bounded and reject malformed/repeating cursors.

Provider requests have connect/read limits and never follow redirects. Request/stream/credential errors become generic storage errors without echoing credentials. Refresh after 401 occurs at most once; callers cannot fall back to anonymous access. Auth refresh/discovery is serialized with a bounded lock wait. Provider/auth-library retry behavior remains outside canonical simulation; real ADC/latency acceptance remains pending.

`make_blob_store` keeps publication/read database pins around GCS. `object_archive.py` accepts GCS and streams the existing portable gzip-object archive format. Local and S3 defaults remain available. Provider tests cover existing-object corruption, malformed acknowledgements, bounded response/decoded sizes, generation mismatch, token refresh, scope/lazy ADC, pagination, pin retention and archive round-trip to a new local store.

## Staging implementation

The [runbook](../backend/deploy/gcp/README.md) and `staging.py` prepare/apply/remove explicitly disposable resources. Local prepared configuration is ignored under `.tools/gcp-staging`; project-specific [deployment plan](evidence/backend-gcs-staging-2026-10-05/staging-plan.json) and [cleanup preview](evidence/backend-gcs-staging-2026-10-05/cleanup-plan.json) are reviewable evidence. Plans contain no passwords or tokens.

Initial proposed caps: four-hour lease, EUR 40 review budget, maximum two API replicas and one worker. Config allows only bounded replicas, positive budgets at most EUR 50, expiry within 72 hours, recent reviewed pricing and a 40-connection budget including revision overlap/operations/reserve. These are script guards/estimates, **not provider spending enforcement**. Pricing fields deliberately remain unset until the operator checks current regional/service costs.

Default API ingress is private Cloud Run IAM. Development authentication/test-driver flags are false. Public staging requires explicit config and real Google audiences. Managed Cloud SQL sockets attach to API/worker/jobs; migration/app secrets and identities are separate. Runtime has create/read/list object rights; the operator diagnostic identity has deletion rights. All image consumers use one registry digest. A source/image change requires a fresh owned staging environment; arbitrary mixed-build rolling upgrades are refused rather than assuming the unrelated exception-review issues are repaired.

Cloud SQL/bucket creation uses atomic ownership labels in JSON API requests. All names are derived from the deployment owner. Preflight checks CLI identity, project, billing and GA worker-pool support. Provisioning reuses owned secret version 1/passwords on repeats; secrets/passwords do not enter arguments or ordinary output. A SQL ownership guard exists before migration, preserving interruption recovery and refusing adoption of nonempty/differently owned databases. Application privileges are restricted and the ownership guard is inaccessible to the app role.

Cleanup checks **all** ownership before deleting anything, rechecks each target, removes compute before data and removes its project-level Cloud SQL IAM bindings. It never deletes the project/billing account, disables shared APIs or touches differently owned resources. A local expiry watcher is included but requires a powered-on authenticated host; no cloud-side scheduler/spend cap has been provisioned.

`cloud_smoke.py` checks schema/app privileges, the existing native golden manifest/ticks/laps and real immutable-object operations under a unique diagnostic prefix, then deletes only its test hashes. It creates no players, PBs, rewards or memberships. Operator HTTP smoke uses `X-Serverless-Authorization`; a mismatched service URL/image receipt cannot receive that token. Proxy trust remains disabled rather than introducing a wildcard; public-edge/client-IP and real Google browser acceptance remain separate checks.

## Changed files

Runtime: `backend/bmt_backend/{config.py,storage.py,gcs_storage.py,cloud_setup.py,cloud_smoke.py}`. Deployment: `backend/deploy/{object_archive.py,.env.example,README.md,gcp/staging.py,gcp/README.md}`; `backend/README.md`. Tests: `backend/tests/{test_gcs_storage.py,test_gcp_staging.py,test_cloud_setup.py}`. Status/docs: `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this report and [scoped evidence/checkpoint](evidence/backend-gcs-staging-2026-10-05/README.md). No game/simulation, schemas/golden physics fixtures or UI source changed. Cloud bootstrap's ownership table is operational staging metadata, not a game contract migration.

## Actual verification

Test batches overlap and must not be summed.

- Provider/native-GCS/S3 batch: **25 passed, 1 skipped**. The skip is the intentionally opt-in real GCS contract; no external account is contacted by default.
- Initial orchestration batch: **19 passed**. Later added nested-job/redeployment and preflight checks; the final combined affected batch covers them.
- Final affected cloud/provider/storage/readiness/scalability batch: **98 passed, 3 skipped**. Skips: unconfigured real GCS acceptance and two existing inapplicable SQLite/PostgreSQL cases. Generated schemas/app roles used a separate disposable PostgreSQL container; no private existing test environment was rewritten.
- Native Windows staging smoke passes with actual pinned canonical verification, real PostgreSQL application permissions and isolated GCS HTTP transport. Asserts 12,757 ticks, exact five-lap proof/full expected manifest, zero player/Run writes and removal of diagnostic objects.
- Separate local image `bmt-gcs-staging:20261005-local` built/rebuilt successfully. Exact Linux SHA/version check, curated project import, 12,757-tick five-lap fixture and ten-second rewind regression pass. The final smoke-module revision is in the rebuilt image. No image was pushed and no running image/container was replaced.
- Packaged Linux smoke checker in that image: **1 passed**, using only the disposable PostgreSQL container and isolated GCS transport. Runtime package/environment, exact Linux verifier and app privileges are exercised. An initial mounted-test-path fallback failed and was corrected; assertion strength retained.
- Ruff, scoped whitespace and reverse patch validation pass. Local `init`, `plan`, `cleanup` preview and `--help` commands succeed for the actual target; UTF-8 JSON artifacts parse. Cleanup preview performs no cloud calls.

Initial checks caught a mock CLI `--help` being mistaken for deploy, and smoke assumptions about fixture fields. The existing golden format is `expected_manifest` and has per-lap expectations in the build checker; smoke now uses that format and the same exact lap proof. The first image was rebuilt after the fix. No failing canonical invariant was removed/relaxed.

The temporary database was stopped/removed. Final existing WSL status remained API healthy/up 14 hours, worker up 14 hours, database healthy/up 32 hours. No NAS/cloud rollout, full new physics regression, Android build/device test or real provider/Google OAuth acceptance was performed; phone attachment was not checked. Backend-only changes require no UI screenshots.

## Actual commands

Existing `.tools/backend-venv/Scripts/python.exe` and Ubuntu Docker were used. Private config/preview generation never called Cloud APIs. Process/database/image tests ran with approved normal desktop access.

```powershell
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py init --project beat-my-track --hours 4
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py plan
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py cleanup
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/staging.py --help
$env:BMT_GCP_SETUP_TEST_DATABASE_URL = 'postgresql+psycopg://postgres@127.0.0.1:32770/bmt_tests'
$env:BMT_TEST_DATABASE_URL = $env:BMT_GCP_SETUP_TEST_DATABASE_URL
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_setup.py backend/tests/test_gcp_staging.py backend/tests/test_gcs_storage.py backend/tests/test_s3_storage.py backend/tests/test_storage.py backend/tests/test_readiness.py backend/tests/test_scalability.py -q --tb=short --junitxml=docs/evidence/backend-gcs-staging-2026-10-05/regression.xml
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/gcs_storage.py backend/bmt_backend/cloud_setup.py backend/bmt_backend/cloud_smoke.py backend/deploy/gcp/staging.py backend/tests/test_gcs_storage.py backend/tests/test_gcp_staging.py backend/tests/test_cloud_setup.py
wsl.exe -d Ubuntu -- docker run --detach --rm --name bmt-gcs-staging-pg-20261005 --network bridge -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=bmt_tests -p 127.0.0.1::5432 postgres:17-bookworm
wsl.exe -d Ubuntu -- docker port bmt-gcs-staging-pg-20261005 5432/tcp
wsl.exe -d Ubuntu -- docker build --platform linux/amd64 --file backend/Dockerfile --build-arg GODOT_SHA256=8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e --tag bmt-gcs-staging:20261005-local .
wsl.exe -d Ubuntu -- docker run --rm --network container:bmt-gcs-staging-pg-20261005 --entrypoint python -e BMT_GCP_SETUP_TEST_DATABASE_URL=postgresql+psycopg://postgres@127.0.0.1:5432/bmt_tests --mount 'type=bind,source=/mnt/c/Codes/Godot/Beat my track/backend/tests,target=/acceptance-tests,readonly' --mount 'type=bind,source=/mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-gcs-staging-2026-10-05,target=/evidence' bmt-gcs-staging:20261005-local -m pytest /acceptance-tests/test_cloud_setup.py -q -k staging_smoke -p no:cacheprovider --tb=short --junitxml=/evidence/linux-smoke.xml
wsl.exe -d Ubuntu -- docker stop bmt-gcs-staging-pg-20261005
wsl.exe -d Ubuntu -- docker ps --filter label=com.docker.compose.project=bmt-pc-dev --format '{{.Names}} | {{.Status}}'
```

## Remaining live acceptance

Install/authenticate the Google Cloud CLI and operator ADC, verify the exact remaining credits/expiry/eligible services and regional pricing, review private/public access and Google client IDs, then use the existing plan with a current lease/estimate. Only an explicit applied run can prove GCS/IAM generation semantics, provider round-trip/restore/revocation, Cloud SQL sockets/managed-role grants and actual Cloud Run/worker deployment/cleanup. Credits have not been consumed by this task.

The runbook documents those commands and scopes. This tool is for a disposable staging environment, not production rollout or automatic cloud spending enforcement. Public/cellular/proxy capacity, real account sign-in, provider stalls and production monitoring/backups remain acceptance work; the earlier unrelated exception-review issues remain open.
