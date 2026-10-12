# Worker shutdown, diagnostics and availability — 2026-10-05

Owner authorized items 1–3 of the code backlog: worker shutdown, diagnostic logging and accurate worker availability/progress. Requirements: B01–B07/B19/B20/B23, WR03–WR08, RW05–RW07 and Q01. This is a source/test checkpoint. Existing WSL services and player data were not restarted, migrated or deployed; no NAS/cloud resources were provisioned.

## Implemented behavior

- `worker_lifecycle.py` supervises one sequential job thread. SIGTERM/SIGINT handlers only record a stop request and monotonic timestamp; database calls, event wakeups and cleanup run outside the handler. Race and track-validation claim paths check stop requests before admission commits. Idle waits wake promptly. Repeated signals do not extend the grace period.
- `BMT_WORKER_SHUTDOWN_GRACE_SECONDS` defaults to five seconds. During grace, a claimed job may complete normally. At the deadline, a cancellation event stops persistent-engine polling or transient/version subprocess execution. The owning job thread handles subprocess cleanup. Cancellation leaves the existing fenced race/validation lease and evidence intact; it does not classify inputs as invalid or publish unverified results. Existing lease expiry and attempt limits apply. A final-attempt interruption can still require the existing manual retry; this slice does not reset attempt budgets or change recovery policy.
- Verifier and SQLAlchemy pool cleanup also run for `--once`, failed iterations and verifier-cleanup failures. Previous signal handlers are restored. Transient child execution is cancellable; Windows cleanup terminates the launcher/child tree with a bounded native fallback. Canonical simulation, engine/rules/physics contracts, scoring and receipts are unchanged.
- Heartbeats carry `running`, `draining` or `stopped` lifecycle independently of job phase. Atomic initial publication and locked merging preserve build identity under concurrent publication; draining/stopped states cannot be revived by an idle/job heartbeat. Health excludes draining/stopped workers immediately after successful notification. A matching live worker establishes availability; merely having a different build does not.
- JSON logs retain allowed worker/run IDs, verification duration, queue wait, shutdown duration and signal number. Success and failure diagnostics use constant event names; exception text, credentials, player IDs and replay bodies remain excluded from extra fields.
- Competition health adds matching available, draining and recently stopped counts; five-minute successful verification throughput, terminal infrastructure failures/rejections and failure fraction; mean/max verified end-to-end completion latency; and each active worker's last queue wait at claim. Rates use a fixed 300-second window; failure fraction is `failed / (verified + failed)` with null when there is no denominator. Rejected inputs are reported separately. Completion latency is submission-to-finish, including queue/retry time; queue wait is age since original submission at the most recent claim. These are measured observations, not a capacity promise or a percentile histogram. Existing track-validation counts/queue age and API liveness remain separate.
- Production Compose exposes the grace setting; PC Compose provides a 30-second termination allowance and exposes the same setting. NAS Compose retains its existing 210-second allowance. No runtime service restart was performed.

## Changed files

Runtime: `backend/bmt_backend/{worker.py,worker_lifecycle.py,verifier.py,track_validation.py,operations.py,observability.py,config.py}`. Deployment: `backend/deploy/{compose.yaml,compose.pc.yaml,.env.example,README.md}` and `backend/README.md`. Tests: `backend/tests/{test_worker_lifecycle.py,worker_signal_probe.py,test_verifier.py}`. Project status: `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report. No schema or gameplay/UI changes; no screenshots are needed for this JSON/logging slice.

## Actual verification

Evidence: [test reports and scoped checkpoint](evidence/backend-worker-lifecycle-2026-10-05/README.md). Batches overlap and must not be summed.

- Final affected regression batch: **212 passed, 12 skipped** across disposable SQLite and PostgreSQL. Skips include POSIX signal cases on Windows and existing inapplicable SQLite/PostgreSQL or unavailable retained-fixture cases. Tests cover queue fencing/projections, creator lifecycle, moderation/health, idempotency and interrupted race/validation/rivalry recovery.
- Final lifecycle/verifier batch: **57 passed, 4 skipped, 20 deselected** (`not postgres and not godot`); the four skips are POSIX signal cases on Windows. Includes cleanup, concurrent initial heartbeats, diagnostic redaction, timer cancellation, retained leases and recovery without duplicate PBs/rivalry points, plus corrected verifier fault injection.
- Real Linux process signals in a network-isolated disposable container: **4 passed**. SIGTERM completes a released job within grace; SIGTERM and SIGINT cancel a blocked job after a one-second test grace; SIGKILL retains durable evidence. Replacement processes recover after explicitly simulated lease expiry. Each case asserts no second claim after draining and exact PB/queue outcomes. Signal completion cases must exit within five seconds. This uses controlled verifiers and SQLite; it is not a deployed Cloud Run timing measurement.
- Pinned native Godot batch (`4.7.2.stable.official.ed1daf0bf`): initial **57 passed, 2 failed**. Both failures were fault-injection hooks still patching `subprocess.run` after execution moved into the cancellable wrapper. They now patch that boundary while preserving wrong-engine/script-error fail-closed assertions; the final lifecycle/verifier batch passes both. Persistent-engine isolation/recycling, canonical rewind/launch and retained native replay checks passed in the native batch.
- Earlier focused run: initial **9 passed, 2 failed** (creator proof included in metric window; sandbox child-termination restrictions). The metric fixture now explicitly places the setup proof outside its measured window; native subprocess tests pass with desktop process access. Initial Linux harness counted a setup worker as still active and then asserted one stopped worker; it now explicitly retires setup and asserts both stopped workers. Assertions for actual availability, result uniqueness and recovery were retained.
- The previously configured PostgreSQL test URL was unreachable. An initial batch was interrupted; a single setup check confirmed connection timeout. No production database was contacted or changed. A fresh PostgreSQL 17 container on a random loopback-only port supplied generated test schemas; final tests passed and the container was stopped/removed. The private existing test environment file was not rewritten.
- Ruff and scoped whitespace validation pass. Both Compose files parse successfully with inherited database configuration, worker command and configurable grace intact. The scoped patch is reverse-checked against the final working tree. Unrelated dirty work remains preserved.

## Actual commands

Commands ran from the repository root using `.tools/backend-venv/Scripts/python.exe`; existing Python dependencies were reused. Desktop subprocess/database batches used approved normal process access. The PostgreSQL override below existed only in the test process.

```powershell
$env:BMT_TEST_DATABASE_URL = 'postgresql+psycopg://postgres@127.0.0.1:32768/bmt_tests'
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_worker_lifecycle.py backend/tests/test_review_followups.py backend/tests/test_review_reliability.py backend/tests/test_scalability.py backend/tests/test_domains.py backend/tests/test_track_lifecycle.py backend/tests/test_admin.py -q --tb=short --junitxml=docs/evidence/backend-worker-lifecycle-2026-10-05/final-regression.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_worker_lifecycle.py backend/tests/test_verifier.py -q -k 'not postgres and not godot' --tb=short --junitxml=docs/evidence/backend-worker-lifecycle-2026-10-05/final-lifecycle.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_persistent_verifier.py backend/tests/test_verifier.py -q --junitxml=docs/evidence/backend-worker-lifecycle-2026-10-05/verifier.xml
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/worker*.py backend/bmt_backend/operations.py backend/bmt_backend/observability.py backend/bmt_backend/verifier.py backend/bmt_backend/track_validation.py backend/bmt_backend/config.py backend/tests/test_worker_lifecycle.py backend/tests/worker_signal_probe.py backend/tests/test_verifier.py
```

Linux signal tests used the existing image with current Python/tests bind-mounted read-only, no network, no live volumes and disposable `/tmp` data:

```powershell
wsl.exe -d Ubuntu -- docker run --rm --network none --entrypoint python -e PYTHONPATH=/app --mount 'type=bind,source=/mnt/c/Codes/Godot/Beat my track/backend,target=/app,readonly' --mount 'type=bind,source=/mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-worker-lifecycle-2026-10-05,target=/evidence' bmt-backend:local -m pytest /app/tests/test_worker_lifecycle.py -q -k real_signals -p no:cacheprovider --junitxml=/evidence/linux-signals.xml
wsl.exe -d Ubuntu -- docker run --detach --rm --name bmt-worker-lifecycle-pg-20261005 --network bridge -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=bmt_tests -p 127.0.0.1::5432 postgres:17-bookworm
wsl.exe -d Ubuntu -- docker port bmt-worker-lifecycle-pg-20261005 5432/tcp
wsl.exe -d Ubuntu -- docker stop bmt-worker-lifecycle-pg-20261005
wsl.exe -d Ubuntu -- docker ps --filter label=com.docker.compose.project=bmt-pc-dev --format '{{.Names}} | {{.Status}}'
```

Final status: original API healthy/up 12 hours, worker up 12 hours, database healthy/up 30 hours. The temporary PostgreSQL container is gone.

## Remaining acceptance

The grace bounds canonical finish time before cancellation; total shutdown also includes existing bounded SQL/object IO and cleanup. A blocked or unavailable heartbeat database delays or prevents drain notification, so stale-heartbeat expiry remains the fallback. SIGKILL cannot execute cleanup or notify health; existing lease expiry and fencing preserve authority. Worst-case real provider/database stalls within Cloud Run's termination allowance, attached native Godot termination on the target Linux host, and mixed-build rollout/claim routing still require separate deployment acceptance. This does not repair the other findings in the exception review or implement backlog items 4–7.

No phone/device test, Android build, NAS/cloud deployment or full gameplay physics regression was performed; device attachment was not checked. No engine/simulation source changed. Existing API/worker services must be rebuilt/restarted together through the established entry point in a separately authorized rollout, with the existing scalability schema requirements respected.
