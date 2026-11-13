# Telemetry reliability fixes — 2026-11-12

The owner requested fixes for the findings in the telemetry review. This change
fixes consent cleanup, Unicode batch delivery, source-specific loss accounting,
worker failure diagnostics, and the two failing backend tests. The original
review and failing reproductions remain under
`build/reviews/telemetry-2026-11-12/`.

## Requirements and behavior

| ID | Change | Evidence |
| --- | --- | --- |
| TFX01 | Withdrawal clears menu bins and active quality capture immediately. A consent generation fences ordinary request completions even if sharing is switched off and back on before completion. Stale telemetry upload callbacks also cannot mutate the new consent lifetime. | Native regression covers completion while off and after off/on, and prevents pre-withdrawal diagnostics from reappearing. |
| TFX02 | Server counts supplied compact UTF-8 fields without ASCII expansion or inserting omitted defaults. Client halves a batch on HTTP 413; a rejected singleton is counted and removed so valid siblings can drain. Normal request spacing and durable per-event ACK removal remain. | One shared 50-event Unicode fixture is normalized and packed by actual GDScript and accepted by backend ingress. Multi-event splitting, exact ACK identities and singleton recovery pass. |
| TFX03 | Each account/source gets a durable cumulative watermark. New clients negotiate `loss_counter_version=2` and emit a UUID `counter_id` for each account-scoped lifetime. Local bookkeeping retains at most 32 scopes; eviction or withdrawal creates a fresh lifetime when needed. | Independent installs, restart, reset, out-of-order snapshots, duplicates, account changes, local eviction, withdrawal and SQL rollback pass. |
| TFX04 | Standalone worker initializes the existing JSON logger and reports safe first-party source locations, stage, exception type and bounded owner-partition IDs. Failure-recording outages are logged without terminating recovery. | Actual worker `main()` runs with injected stage and failure-recorder failures; logs omit private exception text and paths. |
| TFX05 | Request-trace test selects `http_request` records and explicitly enables success sampling. Overview restores bounded pending/failed publication counters with cap flags. Original publication-health assertions remain. | Both previously failing tests and nine retained admin cases pass. |
| TFX06 | Preserve bounded race-time collection, account separation, legacy backend behavior and existing physics/owner data. | Original product/quality/network/privacy regressions pass; no canonical simulation source was edited. |

## Contracts, persistence and rollout

Migration **`0077_telemetry_loss_sources`**, following the existing local 0076
head, adds `product_loss_sources(player_id, source_id, counters)`. Projection
reads/writes one fixed-size source row at a time under the existing account
partition owner, in the same transaction as metric effects. Counter state is
kept outside the growing profile JSON. Replayed or lower snapshots contribute
zero; independent lifetimes contribute independently.

Source watermarks remain for the account lifetime so an old cumulative client
cannot be counted again after raw receipt retirement. Additive bounded erasure
removes those rows under the existing owner fence, without changing persisted
deletion-stage numbering. The worker receives CRUD rights; API/admin receive
SELECT only. Migration upgrade/downgrade preserves existing profile evidence.

Historical per-player maxima have no source identity to reconstruct. Projection
claims the old watermark once for the first legacy source, preserving existing
prepared totals instead of adding that history again. Historical multi-device
undercounting cannot be reconstructed from the old maximum alone. Legacy
no-install clients retain their shared legacy baseline; old servers retain the
original cumulative reporting/cadence. A downgraded server cannot reclassify
already-scoped totals as legacy losses, and queued modern summaries wait for
their negotiated capability.

The payload schema documents optional `collection_summary.counter_id` and the
UTF-8 byte definition. The common Unicode fixture is
`backend/tests/fixtures/telemetry_utf8_batch.json` (63,686 compact UTF-8 bytes;
the same content exceeds 64 KiB with ASCII escaping). Actual client packet IDs
are regenerated normally and have the same bounded lengths.

Rollout order is migration, reviewed grants, then matching API/product worker;
the client enables scoped loss records only when advertised. No migration or
grant change was applied to a running service, and no deployment was performed.
PostgreSQL execution, concurrency and effective-role qualification remain for
the available disposable PostgreSQL environment; the previously configured
local service was unavailable during review and was not retried here.

## Authored files

- Client: `game/backend/backend_client.gd`, `product_telemetry.gd`,
  `client_quality.gd`, `network_health.gd`, and new `telemetry_loss_counters.gd`.
- Backend: `telemetry.py`, `telemetry_projection.py`, `telemetry_models.py`,
  `product_worker.py`, `observability.py`, `app.py`, `admin.py`,
  `database_privileges.py`, `studio_erasure.py`, and migration 0077.
- Tests/contracts: new `game/tests/test_telemetry_reliability.gd`,
  `backend/tests/test_telemetry_reliability.py`, shared Unicode fixture, payload
  schema, and the existing request-trace/publication-health tests.
- This document and additive AGENTS/development-status entries.

The development launcher regenerates `game/core/build_identity.gd` and project
version metadata from the current workspace. These generated identities include
concurrent source work and are excluded from the authored source checkpoint.
Concurrent `game/core/app.gd` changes were observed and preserved; this task did
not edit that file. `backend/bmt_backend/privacy.py` is byte-exact to task start;
erasure integrates through the additive hook instead.

## Actual validation

All Python commands used `.tools/backend-secure-venv/Scripts/python.exe`, with
`PYTHONPATH=backend` (also `backend/tests` for the original review probes).

1. Broad backend regression:

   ```text
   -m pytest backend/tests/test_telemetry_reliability.py backend/tests/test_product_analytics.py backend/tests/test_client_quality.py backend/tests/test_network_health.py backend/tests/test_product_domain_events.py backend/tests/test_telemetry_parallel.py backend/tests/test_telemetry_counter.py backend/tests/test_request_trace.py backend/tests/test_race_statistics.py backend/tests/test_shader_profiles.py backend/tests/test_privacy.py backend/tests/test_failure_sites.py -q -m "not postgres and not godot" -k "not postgres" --tb=short
   ```

   **164 passed, 22 deselected.** A later focused run including the two newly
   added account-isolation/rollback cases passes **18/0**. The final stronger
   migration-preservation test passes separately. The broad/final runs cover
   166 distinct backend test cases without PostgreSQL execution.

2. Retained admin suite: `-m pytest backend/tests/test_admin.py -q -m "not
   postgres and not godot" -k "not postgres" --tb=short`: **9 passed, 1
   deselected**. These bring the distinct production backend test cases to 175.

3. The original two review reproductions pass unchanged, along with the
   migration test: **3/0** in `original-probes-fixed.log`.

4. Client commands used the exact pinned
   `4.7.2.stable.official.ed1daf0bf` through:

   ```text
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_<case>.gd -CommandTimeoutSeconds 90
   ```

   Each subprocess has a separate task-owned `APPDATA` profile and empty
   `BMT_API_URL`. Network transports/credentials are synthetic. Results:

   | Case | Assertions | Failures |
   | --- | ---: | ---: |
   | telemetry_reliability | 74 | 0 |
   | product_telemetry | 55 | 0 |
   | client_quality | 57 | 0 |
   | network_health | 28 | 0 |
   | account_privacy | 27 | 0 |

   Total **241/0**, with no matched script/root-certificate errors in accepted
   runs. Initial sandbox startup was blocked by the Windows certificate store;
   approved isolated reruns with store access completed normally.

5. Ruff passes for every authored backend source/test and the migration. The
   retained Starlette deprecation and SQLite expression-index reflection
   warnings remain; they are not hidden or converted into success claims for
   PostgreSQL.

The final retained product microbench observes enqueue p95 23 microseconds,
maximum 69 microseconds, a 129-microsecond main-thread full-queue snapshot and
13,934-microsecond worker save. These are single Windows headless observations,
not a device, radio, whole-frame or comparative performance claim.

## Retained attempts and limits

- The first new duplicate fixture accidentally regenerated `session_id` for a
  reused event ID, correctly producing `ID_CONFLICT`. The fixture now replays
  the same payload; backend deduplication was not weakened.
- The first native shared-fixture check compared JSON-restored floats to native
  integer dictionaries and packed the unnormalized float envelope. The test
  now verifies all values recursively and packs the normalized integer event,
  as production does. All 50 Unicode rows remain asserted.
- The existing product suite initially found an extra legacy loss summary on
  account switching. The fix retains the original legacy cadence; its three
  exact event-count/ACK assertions are unchanged and pass.
- Initial direct PowerShell execution-policy rejection and sandbox native
  startup failure remain recorded. Accepted runs use the pinned launcher;
  owner processes and owner saves were not accessed or restarted.

Evidence, exact logs, task-start controls, source hashes and a forward/reverse
verified task-only patch are under `build/telemetry-fixes-2026-11-12/`.
No device attachment query/test, APK/AAB/export, live backend request, deployment
or main-index write occurred. No visible UI change requires screenshot
acceptance. Reload/rebuild, coordinated backend rollout and Android/TLS/radio
qualification remain; whole-workspace prepared-asset/export readiness is not
claimed for concurrent work.
