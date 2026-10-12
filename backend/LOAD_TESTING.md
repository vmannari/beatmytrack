# Backend capacity lab

Run from the repository root with the pinned backend test environment. The lab starts real loopback HTTP API processes, independent workers and bounded clients. It creates and removes its own SQLite file or random PostgreSQL schema. It never targets a deployed API, reads `BMT_DATABASE_URL`, resets another schema, or changes the PC development stack.

```powershell
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --players 1000 --tracks 100 --clients 8 --duration 15 --scenario reads --workers 0 --output build/load/reads.json
```

SQLite is a functional smoke test. For capacity measurements, supply a **disposable loopback PostgreSQL 17** connection through `BMT_LOAD_DATABASE_URL`, or an ignored env file containing that variable. `--database-env` also accepts the existing `BMT_TEST_DATABASE_URL` convention. PostgreSQL runs create only `bmt_load_<random UUID>` schemas and use a separate bounded connection pool; the schema is removed on completion or a handled failure. A killed parent can leave its own schema behind for explicit recovery.

```powershell
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 100000 --tracks 1000 --clients 8 --duration 30 --scenario reads --workers 0 --p95-budget-ms 200 --output build/load/100k.json
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 10000 --tracks 100 --tie-every 10000 --clients 8 --duration 30 --scenario reads --workers 0 --p95-budget-ms 200 --output build/load/ties.json
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 1000 --tracks 100 --actors 150 --clients 8 --duration 30 --scenario joins --workers 0 --p95-budget-ms 200 --latency-budgets backend/load_budgets.json --output build/load/monday.json
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 1000 --tracks 100 --replicas 2 --clients 8 --duration 30 --scenario reads --ghosts --workers 0 --p95-budget-ms 200 --latency-budgets backend/load_budgets.json --output build/load/ghosts.json
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 1000 --tracks 100 --clients 8 --duration 60 --scenario mixed --canonical --workers 2 --arrival-rate 20 --require-drained --queue-age-budget-seconds 15 --drain-seconds 45 --output build/load/canonical.json
```

`reads` mixes discovery, top/adjacent rankings, histograms and conditional rivalry snapshots. `--ghosts` includes representative derived 20 Hz recordings. `joins` starts without memberships, reports first joins separately, and exercises the Monday reservation path with real skill calculations. `mixed` issues race tickets, uploads full lossless replays, polls batches and continues creating attempts after verification. All authenticated actors share one NAT address. Retry keys and per-actor jobs survive duplicate requests during a run.

Fixtures are explicitly synthetic, isolated normal-shaped players/PBs so public-ranking SQL is exercised. Their seeded scores are not canonical verification evidence. The default synthetic worker isolates API/database costs. `--canonical` uses the exact engine and real verification for **new submitted attempts**; it never validates fabricated seed scores. No real Google account, development bypass or shipping artificial driver population is required.

The report contains endpoint p50/p95/p99, request/response compressed body bytes, HTTP status counts, invalid responses, scheduled latency and dropped arrivals, SQL statements/durations, pool waits/peaks, API RSS, Python and canonical-engine worker RSS, queue depth/age/drain, PostgreSQL `EXPLAIN ANALYZE BUFFERS` plans and post-load recovery. Logs are adjacent to the report. Body measurements exclude headers/TLS/proxy traffic. Seed construction time is excluded. Reports contain no bearer/database credentials.

Use `--arrival-rate` for a bounded open loop that counts saturation; the default closed loop measures completed throughput but slows offered load as the server slows. Both modes keep in-flight requests bounded. Latency, error fraction, queue age and drain requirements produce a nonzero exit code on violation. The optional JSON budget file overrides endpoint p95 limits; its first-join/ghost/around allowances are **provisional engineering gates**, not accepted NAS/device service objectives. Keep strict failed reports as evidence when adjusting a proposed gate.

An intentional overload should fail its gates and then report recovered reads:

```powershell
.tools/backend-venv/Scripts/python.exe -m bmt_backend.loadtest --database-env .tools/load-postgres.env --players 1000 --tracks 100 --actors 150 --clients 96 --arrival-rate 200 --duration 10 --scenario reads --workers 0 --p95-budget-ms 200 --output build/load/overload.json
```

Repeat population scales with the same host, PostgreSQL limits, concurrency, warm/cold policy and background workload. This lab is not a NAS, proxy/TLS, cellular, real-Google or phone measurement. Test at the intended deployment limits and measure longer sustained arrival rates before selecting production capacity. The tool itself can become the bottleneck; generator drops and scheduled latency make that visible.

Regression checks:

```powershell
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_scalability.py backend/tests/test_loadtest.py backend/tests/test_s3_storage.py backend/tests/test_persistent_verifier.py -q
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_scalability.gd
.tools/backend-venv/Scripts/python.exe -m pytest backend/deploy/test_operations.py -q
wsl -d Ubuntu --exec python3 '/mnt/c/Codes/Godot/Beat my track/backend/deploy/test_backup_wrapper.py' -v
```

Set `BMT_TEST_DATABASE_URL` to a disposable PostgreSQL instance for PostgreSQL parametrizations. Canonical checks need the pinned Godot binary and imported project; Windows needs normal certificate-store access. The CLI tests run actual HTTP processes, verify report metrics and require an intentionally impossible latency budget to fail. Query-count and race/fault tests catch regressions even when machine-dependent timing varies.
