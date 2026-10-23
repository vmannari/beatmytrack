# Prompt backend publication verification — 2026-10-18

PVL01 isolates explicit publication verification from competition and background work. PVL02 warms its engine and checks the durable queue every 250 ms while idle. PVL03 requests one-second status polling for the first ten seconds, then restores 2.5 seconds. R01 preserves authoritative track/creator-proof validation, leases, retries, ownership, original immutable evidence, permanent request identities and atomic publication/slot effects. Q01 requires reproduced regressions and actual process/native checks.

## Result and scope

The earlier read-only Snowmen diagnosis found 212 seconds from submission to publication, principally waiting behind artificial generation; see [the original observation](PUBLICATION_WAIT_STATUS_2026_10_18.md). Its cooperative scheduling repair remains intact. The present change additionally keeps publication work independent of a busy competition process, continuous human races and maintenance. The service supervisor starts one publication process inside the existing worker container, including with product telemetry disabled. Existing competitive-worker publication processing remains a fallback. No worker instance, service, scheduler, database migration or resource-setting increase is introduced.

Three new immutable oval documents published through the real local HTTP API, blob store, database, separate worker process and pinned Godot 4.7.2 in **0.506 / 0.482 / 0.503 seconds** (median **0.503 seconds**), while the competition process's global engine slot was deliberately held. A separate memory-instrumented run measured **0.537 / 0.515 / 0.529 seconds**. Neither worker had compiled these documents beforehand; the publication engine itself was warm. The real physically driven creator trajectory was checked and exactly three published versions, verified creator runs and consumed slots resulted. [Timing receipt](evidence/publication-speed-2026-10-18/latency.json), [memory receipt](evidence/publication-speed-2026-10-18/latency-memory.json).

These are local HTTP/SQLite/local-storage fixtures, not a before/after comparison with Snowmen, a cloud latency guarantee or a worst-case large-track/queue measurement. End-to-end player feedback also includes network and the existing client's one-second lifecycle timer. No client update is required to honor the shorter server polling hint. Long waits and infrastructure failures retain existing bounded polling/backoff.

The added Python process and Godot engine together sampled approximately **241–252 MiB RSS** across startup and three publications on Windows. This is additional memory, not full-service or peak memory; Linux/cloud memory, contention and representative larger-track latency remain rollout acceptance checks. The process uses one database-pool connection with no overflow and keeps the original bounded engine/geometry caches. Its heartbeat does not advertise a competition build, so it cannot falsely make race verification available.

## Changed files

- `backend/bmt_backend/publication_worker.py`: publication-only execution, warm engine, bounded connection pool and original shutdown handling.
- `backend/bmt_backend/service_worker.py`: starts/supervises the publication process alongside competition and optional product processing; unexpected exits fail the service and stop peers.
- `backend/bmt_backend/worker_lifecycle.py`: configurable bounded idle interval; existing workers retain one second.
- `backend/bmt_backend/publications.py`: bounded initial polling hint; submission, verification and commit checks are unchanged.
- `backend/deploy/{compose.yaml,compose.pc.yaml,gcp/staging.py}`: deployment plans use the service supervisor, preserving instance/resource settings. Direct `bmt_backend.worker` remains the existing competition/diagnostic command.
- `backend/deploy/stage_verifier.py`: packages the optional `geometry_acceleration.gd` adapter now preloaded by the existing compiler. No native library is added to backend packaging; its original scalar fallback remains.
- `backend/tests/{test_publication_latency.py,publication_latency_probe.py,test_service_worker.py,service_worker_probe.py}`: authoritative native publication, independent OS process, polling, health isolation, signal/failure/cleanup coverage.

## Actual validation

| Check | Actual result |
| --- | --- |
| New polling/supervisor regressions against archived pre-task functions | Three expected failures reproduced |
| New publication scheduling and real native acceptance | Five passed; two PostgreSQL variants deselected |
| Memory-instrumented native acceptance rerun | Five passed; two PostgreSQL variants deselected |
| Final scheduling/competition-health isolation | Four passed; three unrelated/native variants deselected |
| Publication intents/priority, worker lifecycle, GCP plans, lightweight/persistent/native verifiers | **144 passed, six skipped, 28 PostgreSQL variants deselected**, 164.58 s |
| Actual Linux process supervision via WSL Ubuntu, standard-library harness | **12 passed**: SIGTERM/SIGINT delivery; telemetry disabled; competition/publication/product failures; zero-exit failure; launch/priority failures; bounded forced termination; orphan cleanup |
| PostgreSQL-only concurrent delivery/slot tests | Two setup errors: connections to the existing localhost:55439 test database time out; 29 unrelated cases deselected |
| Ruff on new/changed Python worker, process tests and deployment code | Passed |

The broad regression includes the existing build-mismatch, invalid trajectory, stale-lease, infrastructure retry, idempotency, one-slot atomicity (where supported), original native replay and standalone packaging checks. The two PostgreSQL-only concurrent tests skip on SQLite; four lifecycle tests require POSIX on the Windows pytest run. Real Linux process supervision was separately exercised without installing dependencies. No assertion or runtime acceptance check was weakened.

Initial attempts are retained: the first staged-project run lacked its class import cache; the next exposed the existing compiler's missing packaged `geometry_acceleration.gd` preload and timed out. Packaging was corrected, keeping scalar compilation. The native fixture initially expected an entitlement row before the normal lazy initializer; it now calls the existing initializer in its disposable database. Restricted Windows certificate-store reads produced the verifier's normal infrastructure rejection; host-access native runs passed. Godot uses disposable workspace APPDATA. The stopped stuck process was selected by this task's exact disposable fixture path. Existing FastAPI deprecation and SQLAlchemy index-reflection warnings remain.

Actual commands:

```powershell
.tools/backend-venv/Scripts/python.exe backend/deploy/stage_verifier.py --destination build/publication-speed-2026-10-18/canonical/game
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path build/publication-speed-2026-10-18/canonical/game --import
.tools/backend-venv/Scripts/python.exe build/publication-speed-2026-10-18/check_baseline.py
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_publication_latency.py -k 'not postgres' -q --tb=short
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_publication_latency.py -k 'not postgres and not real_publications' -q --tb=short
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_publication_intents.py backend/tests/test_publication_background_priority.py backend/tests/test_worker_lifecycle.py backend/tests/test_gcp_staging.py backend/tests/test_lightweight_verifier.py backend/tests/test_persistent_verifier.py backend/tests/test_verifier.py -k 'not postgres' -q --tb=short
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_publication_intents.py -k 'postgres and concurrent' -q --tb=short
wsl.exe -d Ubuntu --cd '/mnt/c/Codes/Godot/Beat my track' --exec env PYTHONPATH=backend python3 build/publication-speed-2026-10-18/linux_process_checks.py
```

Native tests set `BMT_GAME_PROJECT` to the imported standalone project and `APPDATA` to `build/publication-speed-2026-10-18/appdata`. `BMT_PUBLICATION_BENCHMARK_REPORT` selects each saved timing receipt. Source-only task checkpoint, archived functions, actual test logs/XML and Linux process receipt are under `docs/evidence/publication-speed-2026-10-18/`; helper scripts are retained there as well. Root Git metadata and unrelated concurrent changes are preserved.

These changes are local and reviewable. Matching API/worker rollout, PostgreSQL concurrent-claim validation, representative cloud latency/memory and owner experience acceptance remain. No live publication, account/queue mutation, deployment, phone attachment check/device test or APK action was performed. There are no visible UI changes in this task.
