# Bounded readiness and replica failure tests — 2026-10-05

Owner authorized backlog items 4–5: inexpensive bounded health probes and multi-instance failure tests. Requirements: B01–B07/B19/B20/B23, RW05–RW07 and Q01. This source/test checkpoint preserves earlier worker-lifecycle/scalability repairs and unrelated dirty work. No existing WSL API/worker/database was restarted or migrated; no NAS/cloud resources or live player data were changed.

## Readiness behavior

`/healthz` is an asynchronous liveness response with no database, storage or verifier IO. `/readyz` retains its successful `{status: ready, schema: ...}` contract and schema/storage checks, but coalesces concurrent callers into one dependency IO job per API instance. Waiting callers yield to the event loop rather than consuming request-pool threads.

Defaults are a two-second HTTP deadline, two-second successful schema/readiness cache and 30-second deep-storage freshness window. Deeper storage checks still exercise immutable write/read and validate the returned probe document. They run on demand when storage freshness expires. Schema-only refreshes cannot extend the storage freshness window. Failures cache for one second. Schema mismatch returns `503/SCHEMA_NOT_READY`; dependency faults return `503/DEPENDENCY_UNAVAILABLE`; stalls return `503/DEPENDENCY_TIMEOUT`.

The deadline applies both to the shared job and each caller, so repeated invalidation cannot extend a request indefinitely. A late successful job remains a timeout rather than restoring readiness. Cache invalidation uses a generation fence, preventing an older in-flight success from masking a newly observed failure. API storage errors invalidate schema/readiness and storage freshness immediately; ordinary database exception handlers invalidate readiness. Existing middleware handling remains unchanged.

The background job is a single daemon IO thread. A blocked job occupies that one slot; further probes fail within their response deadline without creating more IO jobs. Underlying SQL/provider/filesystem operations retain their own bounded settings or OS behavior; an HTTP deadline does not forcibly kill an IO thread. API shutdown invalidates the probe and waits at most its configured deadline. A new lifespan refreshes caches and keeps any outstanding old job fenced.

PostgreSQL schema probing sets a transaction-local statement timeout through a bound `set_config` call. Returning the connection rolls this back; the ordinary application statement limit is unchanged. Tests inspect every connection in the API's own pool. Existing schema/DB pool, blob pin/publication, object integrity and canonical-verifier rules are preserved. No new public diagnostic endpoint, provider SDK, dependency, schema migration or simulation change was introduced.

Configuration is exposed in both Compose templates and `.env.example`:

| Setting | Default | Allowed maximum |
| --- | --- | --- |
| `BMT_READINESS_CACHE_SECONDS` | 2 | 5 |
| `BMT_READINESS_STORAGE_CACHE_SECONDS` | 30 | 60 |
| `BMT_READINESS_TIMEOUT_SECONDS` | 2 | 5 |

Values must be positive integers. Keep infrastructure probe timeouts above the application deadline; current Compose's probe timeout already exceeds the default. Cached readiness deliberately allows a short detection delay. With continuing requests, defaults can retain unobserved DB/schema success for up to two seconds and unobserved storage success for up to 30 seconds before a fresh check, plus its two-second response wait. Probe cadence adds its own detection delay. This is not a replacement for ongoing competition-health/queue monitoring.

## Separate-process failure harness

`replica_process_probe.py` is test-only, outside the runtime package and Docker image. Tests launch two distinct Uvicorn API processes plus separate worker processes. Each has its own engine, pool, caches and memory. They share only a disposable database and immutable-object directory. SQLite uses a temporary file; PostgreSQL uses generated `bmt_load_<uuid>` schemas in an explicitly supplied disposable database. Configs/logs live under pytest temporary directories.

Tests exercise ordinary HTTP routes, session tokens and transactional idempotency with an explicitly labeled fixture identity verifier and controlled canonical-verifier double. These prove protocol/state/failure handling; they do not validate real Google signatures, real canonical handling, capacity or provider integration. Test diagnostic routes, pause/fault controls and fake identity verification are never added to production `create_app`.

Covered cases:

- Challenge on one API, sign-in on the other, alternating authenticated requests, refresh across instances, fresh API restart and logout observed across instances.
- Browser start/prepare/complete/poll crossing instances, with single-use handoff preserved.
- Repeated submissions with the same identity/key producing exactly one Run, one pending admission and one PB.
- Concurrent PostgreSQL submissions with a publication barrier: both APIs must pass the initial no-existing-Run check before either completes publication/admission. Concurrent resume retries consume exactly one banked credit and create one receipt. PostgreSQL refresh reuse still revokes the replacement session on both instances; reuse detection is not relaxed.
- Object write failure and lost acknowledgement after durable object publication: a retry on the other API completes without duplicate admissions/results. The affected API becomes unavailable for readiness while liveness remains healthy.
- Object reads unavailable in a worker and SQL failure during finalization: another worker recovers the retained Run/evidence after explicitly simulated lease/backoff expiry.
- Actual forced worker termination and stale worker finalization. The stale worker returns an intentionally different, faster controlled result; it must not replace the verified Run/PB. Assertions check exact final timing and uniqueness, rather than relying on PB upsert alone to hide a broken lease fence.
- A stalled storage probe under 20 real HTTP callers: one probe thread remains occupied, all callers return timeout/503, liveness and the other API remain responsive, and readiness recovers after storage is released.
- PostgreSQL readiness timeout remains transaction-local across every connection in the API's pool.

Concurrent-write cases requiring PostgreSQL row locks are skipped for SQLite rather than weakening serialization assertions. Lease expiry/backoff is deliberately advanced in disposable test data instead of waiting four minutes. No player records, artifacts, reward grants or memberships are seeded into the live backend.

## Changed files

Runtime: `backend/bmt_backend/{app.py,config.py,readiness.py}`. Tests: `backend/tests/{test_readiness.py,test_replica_failures.py,replica_process_probe.py}`. Deployment/docs: `backend/deploy/{compose.yaml,compose.pc.yaml,.env.example,README.md}`, `backend/README.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report. Evidence and a slice-only review patch are under [backend-readiness-replicas-2026-10-05](evidence/backend-readiness-replicas-2026-10-05/README.md).

## Actual verification

Batches overlap and must not be summed.

- Initial readiness batch **14 passed**. Additional per-request deadline and storage-expiry tests bring the final readiness cases to **16**. The final readiness/auth batch is **50 passed**, after clipping successful readiness to storage expiry.
- Separate-process matrix: initial full batch **21 passed, 3 skipped**. Additional/strengthened stale-result, killed-worker, HTTP storage-stall and timeout-isolation batch **7 passed, 1 skipped**. Forced concurrent publication/admission after the barrier refinement **1 passed, 1 skipped**. All final cases have been exercised; these overlapping batches are not one combined total. SQLite skips are production PostgreSQL row-lock or statement-timeout contracts.
- Affected readiness/authentication/browser/queue/worker/scalability regression batch **176 passed, 6 skipped**. Four skips are POSIX signal cases on Windows; two are existing inapplicable database cases. This ran before the final storage-expiry clipping refinement; the final 50 readiness/auth tests verify that refinement.
- Coalescing test uses 80 concurrent async callers and asserts one schema query and one blob write/read. Deadline tests use 40 concurrent stalled callers, a one-second configured test deadline and no second IO job while the first is blocked. Repeated invalidation also cannot extend the one-second request deadline. Schema mismatch, corruption/SQL/provider errors, generation fencing, lifecycle reopening, cache bounds and response-data isolation pass.
- Both Compose files parse with inherited DB settings and all readiness settings intact. Ruff and scoped whitespace checks pass. The review patch is reverse-checked against the final working tree.
- Initial smoke test: one pass/one fixture failure. Its publishing retry key was seven characters, below the existing required minimum; it now uses a valid fixture key. The invariant was retained. The initial failed XML remains evidence with synthetic bearer/refresh values redacted. Windows harness cleanup now handles the venv launcher and child process tree; a restricted orphan check found none.

No phone/device test or Android export/install was performed; device attachment was not checked. There are no visual/UI changes requiring screenshots. No new full physics replay regression or long capacity benchmark was run because simulation, verifier and scoring source did not change.

## Actual commands

Representative successful commands ran from the repository root with the existing backend virtual environment. Process/database tests used approved normal desktop process access. The PostgreSQL URL was temporary process configuration; private existing test settings were not modified.

```powershell
$env:BMT_TEST_DATABASE_URL = 'postgresql+psycopg://postgres@127.0.0.1:32769/bmt_tests'
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_replica_failures.py -q --tb=short --junitxml=docs/evidence/backend-readiness-replicas-2026-10-05/replicas.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_replica_failures.py -q -k 'dead_or_stale or stalled_storage or postgres_probe_timeout' --tb=short --junitxml=docs/evidence/backend-readiness-replicas-2026-10-05/replicas-final-faults.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_replica_failures.py -q -k concurrent_submission --tb=short --junitxml=docs/evidence/backend-readiness-replicas-2026-10-05/concurrent-admission.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_readiness.py backend/tests/test_auth.py backend/tests/test_auth_postgres.py backend/tests/test_browser_auth.py backend/tests/test_worker_lifecycle.py backend/tests/test_review_reliability.py backend/tests/test_scalability.py -q --tb=short --junitxml=docs/evidence/backend-readiness-replicas-2026-10-05/regression.xml
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_readiness.py backend/tests/test_auth.py -q --tb=short --junitxml=docs/evidence/backend-readiness-replicas-2026-10-05/final-readiness.xml
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/readiness.py backend/bmt_backend/app.py backend/bmt_backend/config.py backend/tests/test_readiness.py backend/tests/test_replica_failures.py backend/tests/replica_process_probe.py
wsl.exe -d Ubuntu -- docker run --detach --rm --name bmt-readiness-replicas-pg-20261005 --network bridge -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=bmt_tests -p 127.0.0.1::5432 postgres:17-bookworm
wsl.exe -d Ubuntu -- docker port bmt-readiness-replicas-pg-20261005 5432/tcp
wsl.exe -d Ubuntu -- docker stop bmt-readiness-replicas-pg-20261005
wsl.exe -d Ubuntu -- docker ps --filter label=com.docker.compose.project=bmt-pc-dev --format '{{.Names}} | {{.Status}}'
```

The disposable PostgreSQL container was removed after checks. Original WSL status remained API healthy/up 13 hours, worker up 13 hours and DB healthy/up 30 hours. No Google Cloud credits were used.

## Remaining acceptance

Measure real Cloud SQL/object-provider latency, TLS/proxy routing, probe cadence and graceful shutdown on the target deployment before choosing final settings. A provider or filesystem operation may outlive the response deadline; one occupied daemon IO slot stays unavailable until it finishes or the process is replaced. Ordinary API faults do not all invalidate readiness immediately (middleware still has its own handling), so documented cache/cadence bounds apply. A hung/stale worker still follows established heartbeat/lease expiry and attempt limits.

This does not implement Google Cloud Storage/staging deployment (items 6–7), restore mixed-protocol rollout compatibility, route incompatible worker builds or repair other exception-review findings. The process harness uses uniform compatible builds and controlled verifier outputs. Production capacity, real Google sign-in, native verifier crash testing against a real provider, NAS/cloud deployment and phone acceptance remain separate checks.
