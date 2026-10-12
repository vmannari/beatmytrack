# Google Cloud staging deployment — 2026-10-05

October 6 follow-up: the owner added the Avast exception. The Windows PC app now uses this cloud origin with normal TLS verification; live client 21/configuration-controller 8 checks pass. The test lease was renewed to October 6 15:36:57 Helsinki, with an actually exercised cleanup-task fallback at 15:41:57. [Current PC connection and remaining Google/device acceptance](GCP_PC_CONNECTION_2026_10_06.md) supersede the pending-PC/old-deadline status in this historical record.

Requirements B01–B07/B19/B20/B23/WR03–WR08/RW05–RW07/Q01. The owner completed Google CLI login and explicitly requested the remaining staging deployment. This is an applied staging follow-up to [the storage/deployment implementation](BACKEND_GCS_STAGING_2026_10_05.md), not a production rollout.

The API, worker, PostgreSQL, private GCS, registry and secrets are deployed in project `beat-my-track`, region `europe-west1`. API: https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app. The API is publicly reachable with application authentication; real Google audiences are configured, development authentication and artificial test drivers are disabled. No existing WSL player data was imported or deleted. Existing local services remain available.

API and worker use one immutable digest: `sha256:bec69858e2a6d2494d96a0169076f8e2f497c84f9d36e0ebb5dd02a8c0fdbca0`. Godot is exactly `4.7.2.stable.official.ed1daf0bf`, pinned Linux SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. The applied schema is `0015_exception_recovery`.

## Live checks and limits

- Migration and real native/GCS diagnostic jobs completed successfully. Golden native verification reproduced **12,757 ticks**, the expected manifest and lap ticks `[2634, 2532, 2531, 2530, 2530]`. Two private immutable objects passed publication, duplicate, read and listing checks and were deleted. Diagnostic player writes: **zero**.
- Corrected `/health`, `/ready` and `/v1/bootstrap` checks returned success over verified HTTPS. Cloud Run API and worker conditions are Ready. Public invocation was confirmed by the service's explicit `allUsers` invoker binding; authenticated game endpoints still require real account proof.
- A separate read-only execution checked the actual worker heartbeat and exact canonical build compatibility: status ready, one active/available worker and zero queue depth. It created no races or accounts. See [worker health](evidence/gcp-staging-deployment-2026-10-05/worker-health.json).
- The real game client in an isolated Linux project/container passed **21 checks, zero failures** against the public API with ordinary TLS trust: health, readiness, bootstrap, guest discovery, unauthenticated profile rejection, development-login rejection and Google browser start/prepare/pending/cancel. It creates no authenticated identity and does not validate an interactive Google login.
- Maximum two API instances, minimum zero, concurrency 16, one CPU/1 GiB per API. One manually scaled worker, one CPU/768 MiB. Cloud SQL PostgreSQL 17, Enterprise zonal `db-custom-1-3840`, 10 GiB SSD, no disk autogrowth, connector enforcement and 40 DB connections. App pools have zero overflow. Staging data has no automatic/final/retained SQL backups and is disposable.
- Separate migration/runtime/diagnostic identities use attached ADC. Admin/app DB secrets are separate and version-pinned; no service-account keys were downloaded. The real app-role privilege check passed. The bucket has uniform access, public access prevention and no soft-delete retention.

## Cost and cleanup

CLI 587.0.0 is installed under the user's Google Cloud SDK directory. The project initially had billing disabled despite an existing open EUR billing account. The authorized project was linked to that account; its display name is My Billing Account. No account upgrade or service commitment was performed. Current remaining credits and exact expiry are not available from the public catalog/budget API; the owner's approximately €300/80-day report remains the source.

Regional prices were checked in the authenticated Cloud Billing SKU catalog in EUR, supplemented by the primary pricing documentation. [Recorded rate review](evidence/gcp-staging-deployment-2026-10-05/pricing-review.json). A conservative €1/hour envelope yields about €4 for the original four-hour lease, ignoring free-tier savings and including small job/registry/storage/network overhead. This is an estimate, not a provider cap. The local configuration also retains a €40 review guard.

An actual **€10 gross project-only monthly budget alert** was created, with 50/80/100% thresholds and credits excluded from the budget calculation. It is an alert, not spending enforcement. Other project budgets and billing accounts were not changed.

The lease expires **2026-10-05 23:15:08 UTC / October 6 02:15:08 Helsinki**. A hidden local cleanup watcher is running. Limited-user Windows task `BMT-staging-cleanup-e7a444ab` is a fallback at 02:20 Helsinki, with StartWhenAvailable, WakeToRun and three five-minute retries. It loads a frozen owner/config, refuses deletion before expiry and invokes the same remote ownership checks. These require an authenticated Windows host; they are not a cloud-enforced spending cap. Keep the PC powered on/connected through cleanup, or run explicit cleanup sooner. Remote ownership is checked before any deletion; the project and billing account remain.

The first private stage (`aef88b56…`) was removed after diagnosing the reserved health path. All 12 owned compute/data/registry/secret/account resources were removed successfully; [actual cleanup receipt](evidence/gcp-staging-deployment-2026-10-05/first-environment-cleanup.json). Shared project/APIs/billing and differently owned resources were retained. The replacement stage has owner `e7a444abdf684b7cbd228d9e7948c65e` and the same original deadline.

## Changes made during deployment

Cloud Run's frontend returned a Google HTML 404 for `/healthz` while `/readyz` and bootstrap succeeded and internal liveness probes reported 200. Its documented reserved-path behavior motivated `/health` and `/ready` aliases, retaining older local/NAS paths. Both new paths receive the existing middleware operations exemption; a test initially caught database access through the new liveness alias, and the middleware was corrected without weakening that check. [Cloud Run reserved paths](https://docs.cloud.google.com/run/docs/known-issues#reserved-url-paths).

The current CLI's missing-worker response (`Cannot find worker pool`) is recognized only during an explicitly allowed missing-resource inspection. Permission failures remain fatal. The build refuses a missing owned registry before Docker/auth/push. The first replacement push raced unfinished provisioning and failed with repository not found; after provisioning completed, the cached build/push passed. One new-account IAM binding needed an idempotent provisioning retry after propagation. Both interruptions are retained as failed attempts, not reported as first-pass success.

Actual game-client testing found that a valid empty 204 Google browser-cancel response was rejected as a malformed auth-token response. `valid_response` now accepts an empty dictionary only for POST on that specific cancellation endpoint and continues rejecting a malformed body/wrong method. The test repeats real handoff cancellation against Cloud Run.

Changed source: `backend/bmt_backend/{app.py,middleware.py}`, `backend/deploy/gcp/{staging.py,README.md}`, `backend/tests/{test_gcp_staging.py,test_readiness.py}`, `game/backend/backend_client.gd`, `game/tests/test_cloud_staging.gd`. Documentation/evidence: this report, development/phase status and `docs/evidence/gcp-staging-deployment-2026-10-05/`. Ignored `.tools/gcp-staging` contains operator configuration, public local CA bundles, build receipts, diagnostic drivers and cleanup helpers; credential payloads are not committed. Canonical simulation and golden fixtures were not changed in this deployment slice. Concurrent source/art/editor work is preserved.

## Actual commands and outcomes

Commands were run from the repository root. The ignored diagnostic driver imports the shipped `staging.py` and uses explicit project-scoped CLI arrays; passwords/tokens use stdin/JSON bodies, never command arguments. It records operation names and sanitized errors. Native SDK execution used bundled Python plus `lib/gcloud.py`; local TLS verified against a bundle of already Windows-trusted public roots because Avast intercepts Google HTTPS. No verification was disabled or system trust added.

```powershell
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/run-live.py provision
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/run-live.py build
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/run-live.py deploy
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/run-live.py smoke
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/worker-check.py
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/collect-evidence.py
& .tools/backend-venv/Scripts/python.exe .tools/gcp-staging/run-live.py cleanup .tools/gcp-staging/config.first-live.json
```

Provision/build/deploy/smoke passed for the replacement. The first read-only worker-check execution used a nonexistent diagnostic dictionary field and failed; corrected assertions on status/available_workers/queue_depth passed. Latest successful worker execution is `bmt-stg-e7a444ab-smoke-r7lrh`. The actual native/storage execution was `bmt-stg-e7a444ab-smoke-c79fw`; later worker diagnostics override arguments for one execution only and do not change the job template.

Affected local batches, which overlap and must not be summed:

- Initial CLI missing-resource fix: 22 passed.
- First cloud-alias batch: 40 passed/one real liveness dependency failure. Final alias/readiness/orchestration batch: **41 passed**.
- Final orchestration after the missing-registry guard: **24 passed**.
- Authentication/browser regression: **44 passed**.
- Storage/setup regression: **20 passed, six skipped** (five local PostgreSQL cases lacking their temporary DSN and the operator-ADC opt-in provider case). The real Cloud SQL/GCS job passed separately.
- `scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/test_cloud_staging.gd`: passed with the pinned engine after allowing its normal application log; the initial sandbox attempt could not write that log.
- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd`: **28 checks, zero failures**.
- Windows `TestScript` live API attempt: **failed** on TLS handshake `-9984`. See pending PC acceptance below.
- Initial Linux client attempt against the full Windows game project: Windows-only music-extension errors plus one handoff cancellation failure. The minimal, read-only Linux client project excludes the music extension; after the cancellation fix, the final container run exited zero with **21 checks, zero failures**. It used the pinned deployment image and standard CA validation, with no player/session files.

Public receipts, XML results, source baselines and the scoped Git diff are in [evidence](evidence/gcp-staging-deployment-2026-10-05/README.md). `git diff --check` on the affected tracked files and `git apply --reverse --check` on that scoped patch both exit zero; Git only reports existing CRLF-to-LF normalization warnings. The cleanup watcher/fallback and existing PC URL were rechecked before handoff. Private billing IDs/tokens/passwords are excluded.

## Remaining PC and Google acceptance

The Windows game's current backend configuration remains on WSL while its staging TLS decision is pending. A certificate inspection proved Avast Web/Mail Shield issues the local replacement `*.a.run.app` certificate; the existing Windows-trusted root was exported as a public-only ignored proposal. Godot's default trust rejects that replacement. Linux normal trust succeeds. No debug CA has been applied to the game.

The owner was asked to either allow that already trusted CA only for this exact staging host in local Windows debug builds, or exclude the host from Avast scanning. Existing [AGENTS.md](../AGENTS.md) approval says "restricted to Google ad/resource domains"; it does not cover this new backend hostname. A host-scoped proposal keeps TLS/common-name verification enabled and stores the public certificate/config outside Git/release assets. Approval remains required before applying it or switching the PC game to the failing endpoint.

Add `https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app` to the existing Web OAuth client's Authorized JavaScript origins in [Google Auth Platform](https://console.cloud.google.com/auth/clients?project=beat-my-track), retaining localhost. No OAuth secret is needed. This owner-managed registration and a real browser login are not proven by successful start/prepare/pending/cancel tests.

No Android export/install or physical-device test was performed; phone attachment was not checked. No measured cloud load/capacity, real-Google race submission, NAS migration, data import, production rollout or backup/restore acceptance is claimed. Staging discovery is initially empty and does not inherit WSL identities/tracks/PBs. For a source change, create a fresh owned staging environment; do not rebuild/redeploy this owner as a mixed-image rollout. The copied runtime snapshot passed the canonical golden proof; later diagnostic/client-only files do not alter its immutable image.
