# Limited shared-database Studio reporting, 2026-10-25

The owner explicitly approved limited reporting on the existing database to avoid the fixed cost of a second Cloud SQL instance. The mode is implemented, tested and deployed to private Studio. Reload `http://127.0.0.1:8182/admin` to load the updated controls; Google/MFA sign-in remains required. No additional database instance, schema migration, game API/worker update, player mutation or owner-process restart was performed. No physical-device test or attachment check was performed.

## Requirements and delivered behavior

- SSR01: explicit `shared_limited` mode, available only to the private admin workload with a separate `bmt_studio_report` credential. Default `replica` behavior is retained, including rejection of a primary and absence of automatic fallback.
- SSR02: one read-only report connection, role connection limit1, a cross-process PostgreSQL advisory transaction lock, total SQL budget capped at1,500ms, 200ms lock timeout, 3s idle-transaction timeout, 1MiB work memory and no parallel query/JIT. A busy or expired report fails closed and releases its snapshot/lock/slot.
- SSR03: up to seven UTC calendar days for the selected report/cohort window. Behaviour views, release comparisons and their reporting exports enforce the range before database work. The browser disables 30/90-day options and rejects oversized custom ranges; refresh remains manual. Retention follow-up preserves its existing D1/D7/D30 definitions rather than fabricating truncated metrics.
- SSR04: reader has no writer/inherited/admin privileges, schema CREATE or identity-table access. It receives only schema usage, metadata-function execution and SELECT on six reporting tables. Runtime checks validate the role's effective privileges and match cluster/database/schema to the primary. Every report opens a fresh consistent read-only snapshot, so acknowledged erasures are visible; no report cache is added.
- SSR05: Studio-only image and configuration rollout on the retained backend base. The generated reader password is created in an authorized operator job, stored directly in Secret Manager and bound as pinned version1; it is never returned or logged. Temporary credential-publication permission was removed after setup. Owner Google/MFA and IAM isolation remain unchanged.

## Changed files

Runtime: `backend/bmt_backend/{config.py,studio_settings.py,studio_reporting.py,studio_reporting_admin.py,studio_analysis.py,studio_exports.py,studio_release_reports.py,studio_identity.py}` and `backend/bmt_backend/admin_ui/{app.js,signin.js}`. Deployment helpers: `backend/deploy/gcp/{staging.py,studio_recovery.py}`. Checks: `backend/tests/{test_studio_shared_reporting.py,test_studio_signin_browser.py}` and `scripts/check_studio_live.py`. Documentation: this file, the deployment runbook and `docs/evidence/studio-shared-reporting-2026-10-25/`.

Concurrent unrelated workspace changes were retained. The image applies only the explicit Studio overlay to the deployed API image, preserving its schema/migrations, canonical verifier, assets and other backend behavior.

## Actual verification

Final source regression command from `backend/`, with `BMT_TEST_DATABASE_URL` and `BMT_LIMITED_TEST_DATABASE_URL` pointing to the task's isolated PostgreSQL17 fixture:

```powershell
../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_shared_reporting.py tests/test_studio_reporting.py tests/test_studio_identity.py tests/test_studio_signin_browser.py tests/test_studio_platform.py tests/test_studio_recovery.py tests/test_gcp_staging.py tests/test_gcp_update.py -q --disable-warnings --maxfail=2
```

Result: **126 passed, 1 skipped, 146 warnings, 47.59s**. The skip is the existing real-PostgreSQL-only assertion's SQLite parameter; its PostgreSQL parameter executes and passes. The exact deployed-image source snapshot was separately checked against a fresh database with its original migration version: **58 passed, 1 skipped, 61 warnings, 29.58s**. The SQL assertions include actual permission denial after switching read-only off, cross-process locking, cumulative deadline cancellation and recovery, exact counts/exports, and erasure visibility on the next request. An operator-boundary test confirms that generated-password DDL error text is not logged. Ruff and scoped `git diff --check` pass.

The real Edge fixture exercises both default and limited policies, including the seven-day custom-range rejection, login/enrollment/MFA, lock, cancellation and stale-popup fencing. [Limited-range native browser screenshot](evidence/studio-shared-reporting-2026-10-25/limited-range-desktop.png).

Live deployment/helper commands from the repository root:

```powershell
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --build-image build/studio-shared-reporting-2026-10-25/image-final
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --prepare-reporting build/studio-shared-reporting-2026-10-25/image-final/image.json --identity-config .tools/gcp-staging/studio-identity.private.json --report docs/evidence/studio-shared-reporting-2026-10-25/provisioning.json
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --deploy-image build/studio-shared-reporting-2026-10-25/image-final/image.json --identity-config .tools/gcp-staging/studio-identity.private.json --report docs/evidence/studio-shared-reporting-2026-10-25/deployment.json
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --validate-reporting build/studio-shared-reporting-2026-10-25/image-final/image.json --identity-config .tools/gcp-staging/studio-identity.private.json --report docs/evidence/studio-shared-reporting-2026-10-25/live-report-job.json
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --verify --identity-config .tools/gcp-staging/studio-identity.private.json --report docs/evidence/studio-shared-reporting-2026-10-25/live-access.json
.tools/backend-venv/Scripts/python.exe scripts/check_studio_live.py --expect-limited
```

Deployed immutable Studio image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/studio@sha256:cf37730d2883c1a604a11a89f859c0b4bcbec75f13225c5afa1d700799484f82`. Base API image remains `sha256:16c22624a9bf5f1995c8315fbf1554d62dc3707826ba6a9217ff0f2d65327c0e`, API revision `bmt-stg-e7a444ab-api-00099-ret`. [Image and overlaid source hashes](evidence/studio-shared-reporting-2026-10-25/image.json), [deployment receipt](evidence/studio-shared-reporting-2026-10-25/deployment.json).

The live read-check operator job passes **11 checks** through the restricted reader: four behaviour views, release discovery/comparison, five CSV exports and oversized-window rejection. Activity took414.81ms including cold connection work; retention45.44ms, journey58.27ms and engagement43ms in this one run. No selectable release build existed for a populated comparison, so selected-build capacity is not claimed. These are single-run measurements, not a traffic/load certification. [Exact sanitized function results](evidence/studio-shared-reporting-2026-10-25/live-report-functions.json).

The live job calls the same reporting functions with authorized read-only credentials; it does not mint an owner token, bypass or modify HTTP/MFA authentication, or claim authenticated browser-page coverage. Live access checks confirm readiness200, missing/invalid application credentials401 and anonymous Cloud Run invocation403. A fresh real browser confirms the actual seven-day policy, disabled wider options and Google handoff, with zero JavaScript errors or failed requests at1280×800 and390×844. [Access checks](evidence/studio-shared-reporting-2026-10-25/live-access.json), [real browser results](evidence/studio-shared-reporting-2026-10-25/live-browser.json).

[Cloud SQL inventory](evidence/studio-shared-reporting-2026-10-25/database-inventory.json) confirms only the original `bmt-stg-e7a444ab-db`. The proposed US$50–70/month reporting replica was not created. Existing database work, image storage, secret operations and brief operator jobs can still have usage costs; this is not a zero-cost or bill-savings certification.

## Retained initial failures and limits

The first broad check used an unavailable configured PostgreSQL port55439; tests were then directed to this task's separate local PostgreSQL fixture. Initial fixture SQL referenced a nonexistent column, embedded JSON colons as bind names, omitted model defaults and used an incorrect export URL. These fixture errors were corrected without weakening the permission/deadline/count assertions. Earlier failures and all source/image build directories remain in the task artifacts. A stray shell command after a passing Ruff invocation made no changes; the clean final Ruff command passes.

The local container was explicitly labeled for this task and is removed after checking that label. No owner container, database or process was reused or restarted.

Shared-database reports still compete for some primary CPU/IO; read-only credentials alone do not prevent that. The time/concurrency/window bounds limit exposure, not eliminate it. Busy/timeout failures are intentional; longer windows or materially higher report/data load should trigger a measured move to replica mode. Owner acceptance remains: reload and view the authenticated reporting pages with the real account. No physical phone/tablet or production load test was performed.
