# Weekly Rivalry cold-start delay — 2026-10-06

Requirements WR03–WR08/B19/B20/B23/Q01. The owner reported a long “Finding this week's rivalry” wait and confirmed that it eventually finishes with Join this week.

Cloud logs identify the delay: the first expired-session request took **15.917747 seconds at the Cloud Run frontend**, while the application handled it in 63.6 ms and returned 401. Normal session recovery then produced a 200 current-rivalry response in 85.7 ms; later authenticated requests took 84.41 and 61.75 ms. The large initial difference is consistent with the API's configured scale-to-zero startup, including its pinned native-verifier/readiness warmup. Startup CPU boost was already enabled.

The retained staging API now has a **service-level minimum of one warm instance**, retaining the service maximum of two, existing 1 CPU/1 GiB resource limits and zero-overflow connection budget. Its immutable image, API URL, worker, authentication, tracks, accounts, database schema and canonical simulation are unchanged. No client release/build or sign-in reset is required. [Cloud Run minimum instances](https://docs.cloud.google.com/run/docs/configuring/min-instances).

The repeatable staging command now accepts optional api_min (default zero), strictly permitting integer zero/one within the replica cap. The actual retained private configuration sets api_min=1; previous disposable defaults remain zero. Updating a service-level scaling setting does not require a source/image rollout. No expired review lease or retention guard was weakened to apply this narrowly scoped metadata change.

## Actual checks and commands

- An isolated pinned app diagnostic used a 50 ms authenticated fixture response. One request completed, adapter busy became false, model returned not_joined and the visible page busy became false. The exploratory fixture was removed after confirming the loading UI works normally; its observed log is retained. No saved player session/cloud data was touched.
- Scaling regression: **27 passed**. It preserves the default zero minimum, permits one warm instance and rejects two/negative/boolean/string minimums without increasing max/DB caps. Ruff passed.
- Actual owned cloud service describe verifies minScale=1/maxScale=2 and the unchanged image digest sha256:bec69858e2a6d2494d96a0169076f8e2f497c84f9d36e0ebb5dd02a8c0fdbca0.
- Post-update verified HTTPS: health 200 in **180.15 ms**, readiness 200 in **452.29 ms**, and an unauthenticated rivalry-current request correctly returned 401 in **95.96 ms**. The last test proves warm routing/auth rejection, not an authenticated standings response; the real authenticated 60–85 ms requests are separately recorded in the sanitized cloud logs.
- Pinned Windows real-cloud client diagnostic: **21 checks, zero failures**, including TLS health/readiness, normal guest reads, protected endpoint/development-login rejection and unused Google handoff cancellation.

~~~powershell
# SDK invoked through its installed bundled Python/lib/gcloud.py, with explicit project:
gcloud --project=beat-my-track run services update bmt-stg-e7a444ab-api --region=europe-west1 --min=1 --max=2 --quiet
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_gcp_staging.py -q
& .tools/backend-venv/Scripts/ruff.exe check backend/deploy/gcp/staging.py backend/tests/test_gcp_staging.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_cloud_staging.gd -CommandTimeoutSeconds 120
~~~

Latency evidence includes only route/status/duration/timestamp fields; no tokens, request bodies or player names. The CLI used existing operator credentials and the existing Windows-trusted public-root bundle. Godot used normal TLS trust after the owner's exact-host Avast exception.

## Cost, files and limits

The official regional EUR SKU catalog reviewed October 5 gives minimum-instance idle CPU SKU 7EBB-8579-2C98 and memory SKU 740D-08F2-7A11, each EUR0.000002199 per CPU/GiB-second. One CPU plus 1 GiB for 86400 idle seconds yields **EUR0.3799872/day**, approximately €0.38 additional idle cost before credits/free-tier allowances. Active requests are charged at their corresponding active rates. No commitment/account upgrade was made; the €10 project alert and retained-data protections remain.

Source changes: backend/deploy/gcp/staging.py and backend/tests/test_gcp_staging.py. Documentation: this report, staging runbook, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. Ignored staging configs/helper receipts persist the actual floor. [Sanitized timings, price calculation, test logs and scoped checkpoint](evidence/rivalry-loading-2026-10-06/README.md).

This reduces ordinary idle scale-to-zero waits; provider instance replacement/restart and heavy-load delays are still possible. It is not a production availability/capacity guarantee. No UI/camera/physics/rules/auth code or schema changed, so no UI screenshot or broad simulation regression was required. No Android export/device test or phone attachment check was performed. A deliberately forced production cold restart and real Google-session rotation were not executed during this change; existing authenticated server logs and an isolated UI fixture provide the observed evidence.
