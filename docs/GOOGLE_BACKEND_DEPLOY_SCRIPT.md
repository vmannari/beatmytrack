# Google backend deployment script — 2026-10-07

Requirements B01–B07/B19/B20/B23/Q01. This entry point updates the existing retained Google Cloud staging backend. It does not provision a fresh project or provide a production release procedure.

From the repository root, preview locally:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-backend.ps1
```

Apply the reviewed update:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-backend.ps1 -Apply
```

The process-scoped execution-policy option works with this machine's script policy without changing its saved policy. Optional `-Config` and `-Python` parameters select a different private config/backend environment. The defaults reuse `.tools/gcp-staging/config.json` and `.tools/backend-venv/Scripts/python.exe`. Docker, the authenticated Google Cloud CLI and the pinned Linux engine must already be prepared as described in `backend/deploy/gcp/README.md`.

The updater checks remote ownership, matching existing API/worker/job images and SQL deletion protection before building. It creates a uniquely identified successful SQL backup, checks the old verification queue is empty, runs migrations, updates worker/API/job images, runs native/storage/worker acceptance, validates and adds immutable official-track revisions, and checks HTTPS health/readiness/bootstrap. Updates preserve existing runtime settings and secret bindings; no credentials enter the script. Historical track revisions and records remain pinned to their original contracts.

Run in a quiet testing window with artificial-driver producers stopped and no concurrent races or source edits. The queue check is a snapshot, not an admission lock or zero-downtime protocol migration. The source guard detects concurrent edits; an interruption can leave a partial rollout. Consult `update-receipt.json` in the owned rendered directory before recovery. Automatic rollback/resume is intentionally absent; reconcile migrations and images before retrying. The local lock prevents overlapping invocations, and a killed process can leave `update.lock`; verify the recorded PID has stopped before removing that one file. The successful SQL backup does not constitute a rehearsed full GCS disaster restore.

Changed files: `scripts/deploy-backend.ps1`, `backend/deploy/gcp/update.py`, `backend/tests/test_gcp_update.py`, this report, GCP runbook, development status and phase status.

Actual validation: `.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/update.py` printed the local retained plan without cloud access. `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_gcp_update.py backend/tests/test_gcp_staging.py -q` passed 35 tests with one existing Starlette/httpx deprecation warning. Tests cover cloud-free preview, rejection of disposable configurations, changed-source refusal, remote catalog Python compilation, successful rollout ordering and failed-backup refusal before migration. Direct PowerShell invocation initially hit the machine execution policy; the process-scoped invocation above was then tested.

No cloud deployment/build/push, live migration, Google sign-in acceptance, UI changes, Android export or device test was performed. Phone attachment was not checked. Real-cloud execution and recovery acceptance remain outstanding; the mocked tests do not prove those passed. No Git commit was created in the extensively modified shared workspace.
