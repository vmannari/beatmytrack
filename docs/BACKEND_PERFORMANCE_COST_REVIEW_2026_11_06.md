# Backend performance and cost review — 6 November 2026

The deployed backend has spare capacity at its present workload. The clearest immediate defect is repeated rejected appearance uploads. Most spending comes from the always-available worker, warm API and PostgreSQL instance; reducing bytes or registry storage has little effect on today's bill. Fix wasted work and repair the load workload before changing capacity.

Requirements: **BPC01** inspect current source and deployed allocations; **BPC02** measure aggregate requests and resource use; **BPC03** reproduce query/worker issues locally; **BPC04** reconcile exported costs; **BPC05** prioritize recommendations with evidence and limitations. This task is a review, with diagnostic/report additions only.

## Prioritized findings

**1. P1 — Stop retrying unchanged, permanently rejected appearance edits.** A bounded live log read found **1,468 HTTP 422 PUTs to `/v1/me/appearances`** in 24 hours, roughly **33%** of the nearby Monitoring request total of 4,466. All were served by `bmt-stg-e7a444ab-api-pubfix-1793737941`; median service latency was 42.50 ms. These represent failed sync work, not successful player activity.

[`appearance_sync.gd`](../game/backend/appearance_sync.gd:25) polls every 30 seconds while recovery remains pending. Each refresh GETs the collection, persists the pending edit, and PUTs it. The [failure branch](../game/backend/appearance_sync.gd:139) leaves a 422 pending and breaks the per-car loop, allowing repeated submissions and delaying later cars. The server's [strict appearance validation](../backend/bmt_backend/appearance_routes.py:13) can return 422. Preserve the local edit, remember the rejected payload/contract fingerprint, suspend identical permanent failures until something relevant changes, and let independent cars sync. Transient failures still need bounded backoff and recovery.

The exact live rejected field, account, vehicle and device are unknown. Logs contain no request bodies or identities. Cross-request gaps have a 10.17-second median, so they do **not** prove that one 30-second timer produced every failure. A safe reason-code/catalog-version diagnostic would resolve the rejection cause without recording private payloads. Evidence: [request aggregate](evidence/backend-performance-cost-review-2026-11-06/appearance-request-summary.json), [source analysis](evidence/backend-performance-cost-review-2026-11-06/request/findings.md).

**2. P2 — Reduce empty worker scans while preserving wake-up latency.** A fully migrated, empty SQLite probe of actual current worker functions measured **11 SELECTs per competition scan** and **one per publication scan** after warmup. Competition also probes the publication queue twice. At the [one-second competition wait](../backend/bmt_backend/worker_lifecycle.py:37) and [0.25-second publication wait](../backend/bmt_backend/publication_worker.py:39), this implies approximately **1.296 million empty SELECTs/day/instance**, before query execution time, discovery, telemetry or periodic maintenance.

Use adaptive idle waits and eliminate duplicate probes. Competition already has notification hints; publication needs explicit wake-up support or a latency-aware fallback because its one-connection pool disables the existing listener. Simply lengthening every sleep would delay newly published work. This is a current-source query-count estimate, **not** a measured production query total or attribution of the live database CPU. Evidence: [idle probe](evidence/backend-performance-cost-review-2026-11-06/worker/idle_probe_result.json).

**3. P1 before sizing — Repair the load lab's accepted-race workload.** [`pack_replay()`](../backend/bmt_backend/load_fixtures.py:43) emits controls/rewinds without `race_proof`; the [load runner](../backend/bmt_backend/loadtest.py:197) submits it, but the [current verifier](../backend/bmt_backend/verifier.py:389) requires a trajectory. Three local producer/decoder/verifier checks confirmed rejection before a native engine starts. The read mix also uses legacy `/v1/tracks`, omitting present discovery and Daily flows. Old synthetic/canonical load results cannot establish today's accepted-race throughput or unit cost. Update fixtures and request mix, then measure successful completion latency, backlog, SQL usage and resource peaks under sustained load. Evidence: [capacity and cost checks](evidence/backend-performance-cost-review-2026-11-06/infra/review.json).

**4. P2 — Scope Profile publication reads to the owner and batch their payload data.** [`my_tracks()`](../backend/bmt_backend/tracks.py:180) builds a latest-version grouping over the catalogue before applying the owner restriction to the outer query. [`_payload()`](../backend/bmt_backend/tracks.py:94) also fetches each returned Track separately: a 12-item page adds 12 Track reads. A fully migrated SQLite probe confirmed this and catalogue-size sensitivity; noisy desktop medians were 17.8 ms with no unrelated tracks and 184.5 ms with 50,000. These are component observations, not PostgreSQL or live timings. Prefer an owner-scoped latest-version query with joined/batched Track data. PostgreSQL execution plans should establish the actual production aggregation cost; a small response alone does not establish bounded database work. See the [request findings and corrected migration-aware evidence](evidence/backend-performance-cost-review-2026-11-06/request/findings.md).

**5. P2 — Retention batches still scan retry history.** [`maintenance.py`](../backend/bmt_backend/maintenance.py:166) locates affected idempotency receipts through four unindexed JSON references. A bounded run-deletion batch therefore does not bound the receipt scan. On a fully migrated SQLite database, changing one matching receipt amid 1k/10k/100k records took median **0.867/9.214/96.867 ms**, with a full-table plan. Consider indexed reference records or suitable expression indexes, retaining exact retry semantics. This is a growth risk, not a measured current service slowdown. Evidence: [retention probe](evidence/backend-performance-cost-review-2026-11-06/worker/retention_scan_probe_result.json).

## What the live measurements show

Read-only configuration and Monitoring were captured around **23:32 Helsinki on 6 November**. The metric interval covers the preceding 24 hours; bounded log queries use slightly later endpoints. No metric pagination remained.

| Component | Live allocation | Observed average | Qualification |
|---|---|---|---|
| API | 1 CPU / 1 GiB; minimum 1, service maximum 2; concurrency 16; request billing | CPU 0.85%; memory 21.86% | Distribution-weighted sample means |
| Worker | Manual 1 instance; 1 CPU / 768 MiB | CPU 19.86%; memory 42.66% | Maximum sampled memory mean 62.91%, not an exact instantaneous peak |
| PostgreSQL | `db-custom-1-3840`, zonal, 10 GiB SSD | CPU 17.82%; memory 36.65% | Observed disk maximum about 460 MiB; aligned connection samples peak at 16 of configured 40 |
| Private Studio | 1 CPU / 768 MiB; service maximum 1; concurrency 8 | Not profiled in this metric set | Separate admin deployment |

The API recorded **4,466 requests**: 2,231 HTTP 200; 19 HTTP 201; seven HTTP 202; 566 HTTP 304; 162 HTTP 401; one HTTP 404; 1,468 HTTP 422; twelve HTTP 503. Mean service latency was **49.77 ms across all statuses**, not a successful-endpoint percentile or device latency. Metric delivery means latency samples number 4,467 rather than exactly matching the separate request series. Low-load averages do not certify peak throughput.

The nearby sanitized log read attributes ten 503s to results comparison and one to Daily lap standings; these can indicate snapshot preparation. It also found one 404 for the new profile-statistics endpoint. Current workspace Profile and concurrent Daily preparation changes must not be mistaken for the deployed service. Daily prewarming already exists as concurrent work and is not proposed here as an untouched feature.

Evidence: [inventory](evidence/backend-performance-cost-review-2026-11-06/cloud-inventory.json), [metrics](evidence/backend-performance-cost-review-2026-11-06/cloud-metrics.json), [roles and revisions](evidence/backend-performance-cost-review-2026-11-06/cloud-details.json), [error groups](evidence/backend-performance-cost-review-2026-11-06/cloud-usage.json).

## Actual costs and useful savings

The detailed export now contains billing rows, superseding the October report's empty-export limitation. A project-filtered, read-only aggregate SELECT completed, processed **3,715,352 bytes**, and returned 78 aggregate rows without pagination. It had a 100 MiB billing cap. No individual billing records were retained.

For the five completed UTC dates **1–5 November**, exported gross charges total **€14.341054** and credits **−€14.341160**. Net is **−€0.000106**, effectively zero at currency precision; the tiny reconciliation difference is not a promised refund. November 6 is excluded as incomplete.

| Service | Five-day gross | Share | Same-workload 30-day extrapolation |
|---|---:|---:|---:|
| Cloud SQL | €7.561680 | 52.73% | €45.37 |
| Cloud Run | €6.775977 | 47.25% | €40.66 |
| Other services combined | €0.003397 | 0.02% | €0.02 |
| Total | **€14.341054** | **100%** | **€86.05** |

The 27 October–5 November window gives a similar **€85.34/30 days** gross extrapolation. These are delivered usage-date charges, subject to provider lag/restatement, not an invoice, post-credit future bill, tax-inclusive quote, or forecast for more players. No cost-per-player claim is justified by these aggregates.

Reducing polling and retries frees capacity, but the manually allocated worker remains billable while idle. To turn that headroom into material savings would require measured changes to allocation, scheduling or architecture. Current official Tier 1 worker list prices put 1 CPU/768 MiB at **US$31.55 per 30 days** before credits/free tiers/tax; trimming it to 512 MiB saves only **US$0.80**. That is poor justification for risking native-operation memory headroom. The warm request-billed API's idle component is **US$12.96/30 days**; scaling its minimum to zero would trade some of that cost for cold-start latency and needs separate measurement. These USD examples are not added to the EUR export. Sources: [Cloud Run pricing](https://cloud.google.com/run/pricing), [worker instance billing](https://docs.cloud.google.com/run/docs/configuring/workerpools/manual-scaling).

Registry storage is about 2.51 GiB and contributes only €0.002393 over those five days. Packing/archival is disabled by default and not explicitly enabled in the observed role configuration; enabling it now adds SQL and maintenance work against negligible observed object costs. Its empty archival passes also perform writes. Keep it as a measured scaling option.

The current SQL price buys a zonal instance with seven daily backups, no PITR and no disk auto-growth. Disk is presently lightly occupied. Define recovery requirements and test restoration before treating a cheaper database or this configuration as ready for larger public use.

## Validation, corrections and scope

Existing focused Profile/Daily tests: **9 passed, 9 deselected** in the SQLite-only repeat. The initial combined attempt had **9 passed, 5 skipped, 4 setup errors** because the configured PostgreSQL endpoint was unavailable. That failure remains recorded; no PostgreSQL performance or behavioral pass is claimed. Local probes call actual application functions against isolated synthetic databases. Cloud reads use existing credentials, preserve verified TLS, and save only allowlisted metadata and aggregates.

An initial ORM-only query probe incorrectly suggested a missing lap-order index. Independent review found `ix_news_lap_rank` in migration 0038 and a Profile grouping index in migration 0008. The missing-index finding is withdrawn; the original unrepresentative measurements remain labeled as rejected evidence. This review recommends no duplicate lap index. The request evidence records the migration-aware correction. Its migration probe wrote complete results, but the redirected PowerShell wrapper returned 1 after reflection warnings; this is retained rather than labeled a clean command pass.

The initial sandbox cloud reader could not access the SDK credentials; normal authorized read access succeeded. A Cloud Scheduler metadata read failed, so this review does not claim a complete schedule inventory. Initial diagnostic lint found an import-order issue and a pairwise-iteration preference; both were corrected, and the three cloud-reader scripts pass Ruff. Existing probe warnings and initial serializer/test setup failures remain documented.

Commands actually run include:

```powershell
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/read_cloud.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/read_usage.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/read_request_summary.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/request/probe_requests.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/request/probe_migrated.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/worker/idle_probe.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/worker/retention_scan_probe.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-performance-cost-review-2026-11-06/infra/review_infra.py
```

The [task-only patch](evidence/backend-performance-cost-review-2026-11-06/task-only.patch) and [hash/check receipt](evidence/backend-performance-cost-review-2026-11-06/checkpoint-result.json) make the additions reviewable without staging or committing. The first packaging attempt encountered a UTF-16 PowerShell log; the packager normalizes diagnostic text to UTF-8 and preserves its contents before checking the patch.

Changed files are this report and its diagnostic/evidence directory. No shipping source, owner save, deployment configuration, deployed database content, cloud resource, Git main index or existing process was changed. BigQuery creates ordinary read-query job metadata. No device query/test, APK or production load test was performed. Concurrent backend Daily and game changes were preserved. Remaining work is implementation, migration-aware PostgreSQL verification, representative sustained-load measurement and any separately authorized rollout.
