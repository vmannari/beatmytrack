# Backend performance fixes — 7 November 2026

The five issues in the [performance and cost review](BACKEND_PERFORMANCE_COST_REVIEW_2026_11_06.md) are addressed in source. Rejected appearance writes stop repeating, idle workers reduce empty scans, load tests send an accepted recorded trajectory, Profile reads avoid unrelated catalogue work, and retention looks up retry references through indexes. No live deployment or infrastructure resize was performed.

Requirements: **BPF01** bounded appearance recovery; **BPF02** idle polling and durable wake hints; **BPF03** representative accepted-race load tooling; **BPF04** owner-scoped Profile reads; **BPF05** indexed retention; **BPFQ01** regression tests, original failure evidence and a task-only checkpoint. Existing Daily/loading and native-engine work was preserved.

## Changes and evidence

**BPF01 — Appearance recovery.** The client persists a SHA-256 fingerprint of an HTTP 422 rejection alongside its existing acknowledged baseline and pending edit. Identical writes stay suspended across explicit refresh and restart; local edits, changed baselines and an advertised server appearance contract allow another attempt. Other cars continue syncing. Local values are preserved and rejection is never presented as successful synchronization. Transient/ownership failures back off from 60 to 300 seconds; a successful pass or local edit restores the ordinary interval. Account, origin, in-flight edit and atomic-save fences remain.

The bootstrap adds a stable `appearance_contract` hash of the server catalogue and validation version. Increment `vehicle_appearance.CONTRACT_VERSION` for validator changes that do not change that catalogue. Older servers remain usable: clients use an empty token until a supporting server is deployed. The new optional local recovery metadata is bounded and validated. Native sync tests cover restart suppression, changed-contract retries, independent cars, pending preservation, successful recovery and transient backoff.

This resolves the retry mechanism found in the review. The exact private field behind the historical live 422s remains unknown; validation was not loosened to accept an unidentified payload.

**BPF02 — Workers.** A competition scan probes an empty publication queue once, removing its duplicate probe. Consecutive idle waits grow to five seconds only while the PostgreSQL notification listener is working; a hint or completed job resets the wait. A missing listener retains a one-second maximum fallback. The dedicated publication worker grows its 250 ms idle wait to at most one second, using its existing one-connection pool. Queued and retried publication intents now emit the existing lossy work hint only after commit, so an idle competition worker can respond promptly. Rollback sends no hint. Durable queue scans, priority, leases, reserved maintenance and shutdown behavior remain authoritative.

The migrated empty-database probe falls from **11 to 10 SELECTs per competition scan**; publication remains one. With a working listener and fully settled waits, the two roles imply roughly **259,200 empty SELECTs/day**, versus the review's 1,296,000. Without a listener, the fallback estimate is 950,400/day. These are source-derived idle estimates before query duration and other roles, not production query totals or bill savings. The dedicated publication fallback can add up to 750 ms versus its former polling bound; committed hints provide another wake path through the competition worker.

**BPF03 — Load tooling.** An offline pinned-engine recorder exports a genuine five-lap **12,757-tick / 2,130-sample** trajectory. It is separate from historical physics fixtures. Wire preparation preserves both current trajectory envelopes and legacy replay proofs without sharing mutable data. The synthetic adapter understands trajectory duration; canonical mode checks the fixture against freshly prepared current geometry before seeding.

The read mix now exercises discovery v3 and Daily metadata, limits and lap standings. Preparation uses the real discovery projections, daily-cutoff builder and histogram snapshots outside request timing. Existing database triggers populate flying-lap minima from the synthetic accepted seed facts. All seed data remains explicitly artificial and isolated. Unexpected HTTP 4xx responses and terminal verification failures now fail the workload's limits.

The real loopback canonical run completed **81 requests**: 56 HTTP 200, five 201, three 202 and seventeen 304. **Three submitted races verified**, the queue drained to zero, and no configured limit failed. This verifies the repaired pipeline locally; it does not establish sustainable cloud or PostgreSQL capacity. CLI regression tests also retain the deliberately impossible latency limit and require its failure.

**BPF04 — Profile.** Latest-version selection and the outer page constrain version IDs through indexed owner-track subqueries. A single joined read supplies Track payload data; the authenticated owner supplies the creator name. Finish counts remain one grouped query. Draft/publication rules, archived-track behavior, paging and private ownership remain covered.

The first joined candidate removed individual Track reads but still let SQLite scan the catalogue's published index. The final subqueries eliminate that plan. Matched fully migrated SQLite probes, five samples/case:

| Unrelated tracks | Before median | Final median | SQL statements including one caller lookup |
|---:|---:|---:|---:|
| 0 | 5.108 ms | 2.329 ms | 15 → 3 |
| 50,000 | 71.999 ms | 2.422 ms | 15 → 3 |

All twelve per-row Track lookups disappear; the endpoint's page and finish-count work uses two statements after authentication. These are local component measurements. PostgreSQL plans and production latency remain unmeasured. Regression tests assert owner/paging/draft/archive results, statement counts and indexed version lookups.

**BPF05 — Retention.** Migration **0075_receipt_reference_indexes**, following 0074, adds four partial expression indexes for `run_id`, `ticket_id`, `race_id` and `receipt_id` in retry responses. Missing/null references consume no index entry. Retention renders only these fixed JSON paths as SQL literals so SQLite and PostgreSQL can match the indexed expressions; caller data remains bound. Receipt retirement and permanent retry identity retain their original semantics.

PostgreSQL indexes build concurrently. Re-running an interrupted build skips existing valid indexes and recreates an invalid named index. SQLite migration/rollback/re-upgrade checks preserve receipt contents. A 2,000-unrelated-receipt regression requires all four indexes in the actual update plan and verifies that only four matching receipts retire. PostgreSQL SQL compilation is checked, but concurrent migration recovery and PostgreSQL execution plans still require an owned PostgreSQL integration run before rollout.

## Validation

- **66 distinct backend tests passed** across the new, existing and environment-corrected suites. Four existing Windows-inapplicable signal tests skipped; PostgreSQL parametrizations were excluded. Focused final tests for the partial indexes, fixture reads and contract passed.
- **120 native sync checks passed**: 68 in `test_appearance_sync.gd`, 52 in `test_sticker_appearance_sync.gd`, using pinned Godot 4.7.2 and isolated profiles.
- The real canonical loopback workload verified three races with no errors or remaining queue.
- Scoped Ruff and task-file whitespace checks pass. Existing expression-index reflection and TestClient deprecation warnings remain.

The initial new tests had two fixture errors: raw DBAPI binding of an unencoded JSON value in EXPLAIN and incomplete verifier settings. Both were corrected without relaxing the assertions. The first root-directory pytest invocation lacked the backend import path. One existing backup subprocess also needed that path; its repeat passed with `PYTHONPATH` set explicitly. Load seed attempts exposed the missing source timestamp and duplicate manual flying-lap insertion; the final implementation uses the existing database triggers instead. Initial XML results remain alongside successful repeats.

The older native sync fixtures still edited retired Pickup/Classic/Formula IDs. The first fixture therefore stalled after missing expected retired-car data; its derivative retained two Pickup failures. Those scenarios now use the selectable Forklift/Hovercraft/Electric IDs with the original assertions. The stalled owned tests were identified by process IDs and exact command lines and stopped; existing owner processes were untouched. Diagnostic output is streamed with bounded timeout handling thereafter. Headless sync runs retain the existing Windows certificate-store warning. The canonical RPC correctly rejected that sandbox startup warning; normal authorized certificate-store access completed the workload without disabling its error gate.

PostgreSQL integration was not run; local tool checks did not discover a PostgreSQL or Docker runtime. No cloud, owner-data or device test was substituted for that missing integration coverage.

## Reproduction and rollout

Commands run include the following, from the repository root unless a working directory is shown:

```powershell
$env:PYTHONPATH = Join-Path (Get-Location) 'backend'
.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_performance_cost_fixes.py -q
.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_profile_statistics.py backend/tests/test_maintenance.py backend/tests/test_cost_maintenance.py backend/tests/test_worker_lifecycle.py backend/tests/test_run_confirmation.py backend/tests/test_publication_background_priority.py backend/tests/test_appearance_sync.py -k 'not postgres' -q
.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_loadtest.py -q
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-fixes-2026-11-07/run_native.py res://tests/test_appearance_sync.gd
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-fixes-2026-11-07/run_native.py res://tests/test_sticker_appearance_sync.gd
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-fixes-2026-11-07/measure_fixed_reads.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-fixes-2026-11-07/worker/idle_probe.py
# Working directory: backend
../.tools/backend-secure-venv/Scripts/python.exe -m bmt_backend.loadtest --canonical --players 50 --tracks 5 --actors 2 --clients 1 --duration 4 --scenario mixed --workers 1 --max-requests 80 --require-drained --drain-seconds 15 --output ../docs/evidence/backend-performance-fixes-2026-11-07/load-native.json
```

The source changes are confined to appearance client/state/bootstrap validation metadata, worker scheduling/hints, Profile reads, retention predicates/index metadata and migration 0075, load fixtures/tooling and their tests. The [evidence directory](evidence/backend-performance-fixes-2026-11-07), [checkpoint receipt](evidence/backend-performance-fixes-2026-11-07/checkpoint-result.json) and [task-only patch](evidence/backend-performance-fixes-2026-11-07/task-only.patch) record commands, outcomes, hashes and original controls.

Rollout requires an authorized migration, matching API/worker release and updated client. The client can consume the additional bootstrap field before or after the server update. The migration is additive; the new reference query remains correct without its indexes but retains its former scan cost. The manually allocated worker and database still incur their existing resource charges; no realized production savings are claimed. No device query/test, APK export/install, owner-save change, live backend request, deployment or main-index write was performed.
