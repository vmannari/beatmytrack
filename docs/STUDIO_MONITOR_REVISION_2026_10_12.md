# Backend Studio monitor revision — 12 October 2026

The owner requests a published-only server catalogue, useful track filtering/shape previews, working device/OS heatmaps, one statistics package per race, richer player investigation and a monitor guided by `temp/backend-gui/BMT_Studio_Prototype.html`. This revision changes the data flow and operator workflows together. It does not establish that the entire production requirements inventory is complete.

Requirement references: `STUDIO-LOCAL-DRAFTS-01`, `STUDIO-CATALOGUE-01`, `STUDIO-RACE-PACKAGE-01`, `STUDIO-HEATMAP-SCOPE-01`, `STUDIO-PLAYER-01`, `STUDIO-MONITOR-01`; related existing BMT-018/030/033/034/036/050/051/070. The prototype supplies hierarchy and investigation direction. Its sample people, revenue, uptime, crashes, monthly free slots and scores are illustrative; they are not shipping facts. Approved policies remain everyone included with an admin real/artificial flag, one initial publishing slot/no monthly refill, and one UTC calendar month for monthly ad-free access. Guest telemetry remains unavailable.

## Heatmap diagnosis

A read-only live check at **2026-10-12 04:33 UTC** found schema `0027_client_quality`, quality collection enabled/schema 1, and **zero frame, segment or process-exit rows/reports/samples**. Product collection was running with zero pending events. Receipt: [live-readonly-diagnosis.json](evidence/studio-monitor-revision-2026-10-12/live-readonly-diagnosis.json). No live player record was changed.

The previous collector waited ten minutes to flush spatial cells and five minutes for frames, had no race-end flush, and cleared observations when support/foreground temporarily became unavailable. Short races could finish before supplying a heatmap. This is a confirmed collection defect; it is not proof that any particular installed client ran that collector. The deployed backend has received no such observations, and backend-generated artificial races have no renderer, handset or OS measurements. No historical cells or device identities are reconstructed from verifier trajectories.

The new source is a signed-in client attempt, finalized on completion, exit or restart. One immutable event UUID equals its preallocated attempt UUID. HTTP retries reuse it, and ingestion/projector retries have one effect. Actual package ingress and projection now produce heatmap observations in the owned loopback browser fixture. Screenshots contain clearly seeded observations and are not live player metrics.

## Revised behavior

| Requirement | Implemented behavior |
|---|---|
| Local drafts | Save/edit/delete/test/idle recovery stay on the device. No autosync, remote draft master, editor/draft telemetry or implicit publication from a completed race. Existing local files/journals and historical server records are preserved. |
| Explicit publication | Publish uploads the exact saved document and bounded creator trajectory to a separate processing intent. A valid pinned creator lap atomically commits a published version, accepted creator evidence and slot debit. Failed verification creates no track catalogue entry. Duplicate/uncertain delivery retains exact identity and evidence. |
| Published catalogue | Latest published version per track or all published versions; name/creator/ID search, biome, visibility, official/community, rating and qualified-finisher filters; publication/name/creator/rating/finisher sorting. Prepared route thumbnails and immutable-version shape, creator, cases and accepted-source links. |
| Heatmaps | Exact published version with device model, OS version, build and outcome filters; actual route plus 20 m cells; presence or slow-sampled-second share; frame histogram, route segments, collection freshness, bounds and actionable empty states. Different versions' coordinates/segments are never merged. |
| Player investigation | Canonical account hero, authoritative real/artificial flag, access state, server timeline, observed journey, linked cases, published creator catalogue and entitlement/resume context. Display name is not recovery proof. Production spend/compensation remain unavailable. |
| Pulse / competition / reliability | Prepared activity and mature return cohorts, source-aware investigation links, exact score/result provenance, compatible worker contracts, queue/failure context and publication-processing counts. No invented crash-free rate, API uptime or revenue. |
| Support / monetisation | Readable case activity and linked context, permitted revision-fenced transitions, existing audited moderation previews; financial-source coverage before purchase delivery records and development catalogue controls. Simulations never become player spend. |
| Product analysis | A seven-day explicit publication-request journey replaces private editor/save funnel presentation. Historical creator facts retain their original definition and are marked historical-only. Local draft metrics are explicitly unavailable. |

An explicit publication is server processing requested by the creator, rather than a remote editable draft. Its source objects are retained for durable retry/provenance. Existing queued authoring jobs are parked with original metadata retained and leases fenced, releasing admission counters. Existing legacy draft rows/objects are not deleted, because deletion was not requested. They are omitted from current catalogue and administrative track reads. Old draft APIs fail before a write; compatibility authoring is available only in explicit test fixtures, never development/production configuration.

Publication retains the existing **one creator validity lap**, followed by a **five-lap ordinary-race manifest**. It uses the shared timestamped-trajectory checker, without full physics reproduction or required ghosts. Ordinary race authority and normal results-first behavior remain unchanged. A long-lived local draft refreshes its key only before its first explicit upload; uncertain uploads keep the original key. Known exact owned publication intents retain permanent deduplication even when the original transport key is older than 90 days. Different bodies are rejected.

## Network, compute and retention

The client samples frames into eight counters and positions at **1 Hz**, in memory. There is no diagnostic HTTP or newly started disk worker during driving, including background/pause. A bounded persistence worker already started before the race gate can finish. Finish/exit/restart freezes one package, persists it atomically in the existing account/origin-partitioned outbox and schedules transport under the existing minimum 60-second request spacing. Several finished races can share one batch; each race still has one event. A process killed before finalization cannot supply that unfinished attempt; no streaming or inferred completion is substituted.

The package has at most **128 cells, 32 segments, 3,600 sampled seconds, eight frame buckets and 16 KiB properties**. The batch remains at most **50 events/64 KiB**; the existing queue remains 1,000 events/2 MiB/24 hours. An unpublished local timed race may send generic device/frame/outcome counts, with no track identity, geometry, name, biome or local authoring data. Creator practice is excluded. Device model and OS version use actual platform API values, bounded to 80 characters; no unique hardware ID, cosmetic condition or control trace is added.

Actual Windows native measurements: **2,790 bytes/event, 3,061 bytes/complete sample JSON packet** at the capture bounds; frame update mean **0.402 µs**, varied cell sampling **77.7 µs** at one Hz, finalization **1,068 µs**. These are desktop fixture observations, not phone/TLS/radio acceptance. The publication HTTP fixture separately measured **23,801 decoded / 10,346 request-wire bytes** for its one explicit track/evidence upload; track sizes vary.

Ingestion checks published references and, when present, ticket ownership/version with bulk indexed lookups. It stores a recent race receipt under the existing ingress transaction fence. The paced product worker folds a batch into one row per UTC day/version/device/OS/build/outcome context, using one grouped fact read and one aggregate write per new context. It does not issue per-cell SQL, fetch race proof objects or invoke a verifier. Competitive work keeps priority over diagnostic projection. No vendor, extra service or continuous browser polling is added.

The local server computation fixture processed **100 packages with 128 cells each** into **one prepared row**, with one diagnostic fact SELECT/INSERT plus bounded cleanup. Actual desktop SQLite observations: ingress median **28.618 ms** per ten-event local request, full 100-event product projection **87.587 ms**, prepared report **30.68 ms** and **6,490 decoded response bytes**. These include local middleware/database overhead and do not establish PostgreSQL throughput or load acceptance. Evidence: [diagnostic-compute.json](evidence/studio-monitor-revision-2026-10-12/diagnostic-compute.json).

Reports read at most 500 prepared groups by default/1,000 maximum, merge at most 1,024 cells and 32 segments, and expose omitted samples and truncation. Cell merging has bounded memory with deterministic bottom-hash selection. Selectors expose at most 200 observed contexts; direct exact URL filters remain usable. UTC-day resolution includes entire buckets for a partial-day request and is stated in the view. Histograms merge actual counts; p95 is the containing bucket range, not an average of race percentiles. Process-exit observations remain a separate source: no inferred track/current-player attribution, device/OS attribution, stack trace or crash-free denominator.

Race receipts retain eight days; the event age limit is seven days. Prepared facts follow the existing 180-day retention. Cleanup uses indexed age/day ordering and bounded deletion. Publication intents/evidence currently retain permanent effect deduplication. The catalogue caps pages at 100 rows/offset 10,000 and route shapes at 96 prepared points; no per-thumbnail downloads or geometry compilation occur. Creation-time anchors exclude later inserts, while mutable ratings/names/visibility can still reorder pages.

## Verification and evidence

Aggregate results below record the final stable migration/client/UI passes. Component results:

- Client collection: **46 quality + 55 product + 14 actual App lifecycle checks**, zero failures. Final root App recheck again passed **14/14** after draft guards. It uses actual App/Game callbacks and manually completed session fixtures; it is not an additional claim of driven races.
- Explicit publication: actual 2,605-tick local creator lap, **31 native local checks**, plus two actual HTTP/native tests with **81 checks** covering real geometry/trajectory acceptance and existing race/rewind/rating/result behavior.
- Numeric outbox restoration: a real atomic save/restart preserves queued Android process-exit integer reasons despite Godot JSON parsing numbers as floats. Only finite bounded integer-valued numbers are normalized; fractional values remain invalid.
- Client HTTP adapter: **14 checks**, preserving expired-token refresh and exact mutation key/body across retry, and verifying the retired draft adapter emits no request.
- Catalogue: seven backend checks, a 2,000-row actual indexed name-sort plan with no temporary sort, and no raw race/PB/event reads for the track listing.
- Diagnostic tests: malformed/private payload rejection, published-only spatial data, exact duplicate effects/device/OS scope, ticket ownership/version, bounded memory/count-preserving merge and real publication queue age/counts.
- Bundled Node syntax and presentation contracts; Ruff on changed server/test/helper sources. JSON authoring schema updated; runtime ingress rejects retired streaming and private draft events.

Actual root commands:

```powershell
.tools/backend-venv/Scripts/python.exe .tools/studio_monitor_live_read_20261012.py
.tools/backend-venv/Scripts/python.exe scripts/profile_studio_race_statistics.py
.tools/backend-venv/Scripts/python.exe scripts/test_studio_monitor_postgres.py
.tools/backend-venv/Scripts/python.exe scripts/test_studio_monitor_console.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_statistics_app.gd
```

SQLite regression uses the same backend files selected by the PostgreSQL harness plus `test_commerce.py`/`test_track_lifecycle.py`, with `-m 'not postgres' -k 'not postgres'` and JUnit `build/studio-monitor-revision-2026-10-12/sqlite-regression.xml`. Existing inherited test-database configuration points to an unavailable PostgreSQL peer; initial broad SQLite-labelled runs therefore encountered unrelated connection setup errors. The owned PostgreSQL runner supplies its own private loopback URL and verifies its random task label before cleanup. Migration 0030 initially lacked PostgreSQL arithmetic-expression grouping; corrected DDL was checked against both dialects. Development commerce fixtures had inherited retired authoring configuration; they now enable the production draft fence and use explicit verified publication, retaining their slot/refund/idempotency assertions. These failed attempts are not counted as passes.

Pinned Godot **4.7.2.stable.official.ed1daf0bf** and matching templates were checked. Doctor reports **no attached device**. No physical-phone network/performance test, Android export/install, full gameplay Validate, production migration, deployment, live write or provider purchase was performed. Initial sandbox-only Godot/ADB checks could not access their normal user log/config directory; authorized local checks succeeded without changing the engine pin. Browser screenshots are loopback fixture evidence only.

Final stable backend runs: **162 passed / 7 skipped / 77 deselected** in the SQLite-only selection, and **240 passed / 7 skipped** in the owned PostgreSQL-backed regression (which also includes matching SQLite fixture variants). The seven skips are duplicate concurrency cases requiring PostgreSQL row locks; those cases run against PostgreSQL. PostgreSQL migration, duplicate delivery, parallel projection and one-slot concurrent publication checks passed. The test container was removed after its ownership label check. Final browser **27 checks passed**, including the publication workspace, and six pure presentation contracts passed. The final product projection follow-up passed **28 SQLite tests**, including a partial-step guard and strengthened overflow guard: 129 candidates across three journey frontiers are bounded to 128, affected uncertainty is marked, and all completed/partial proved journey tuples are retained. A separately tested valid partial step after more than 18 earlier alternatives is also retained when the total is below 128.

Selected previews: [filtered heatmap](evidence/studio-monitor-2026-10-12/quality-filtered-1440.png), [published tracks](evidence/studio-monitor-2026-10-12/tracks-1440.png), [player investigation](evidence/studio-monitor-2026-10-12/player-1440.png). The combined browser evidence covers 1440/960/390 pixels, actual local ingress/projector, scoped filters, absence states, role/action fences and zero remote application requests. Visual review corrected primary-button hover contrast and a partially hiding mobile navigation rail; closed navigation is also hidden from pointer/focus interaction.

## Remaining production work

| Workspace/source | Practical limit still outstanding |
|---|---|
| Release quality | Deploy schema-2 backend and updated clients, then measure a physical handset. No crash stacks, Play-vitals feed, proven crash-free denominator, or enhanced incident-specific logs/capture. |
| Money / ads | Real Play fulfillment, production signed ad rewards, impression/revenue feeds, refunds/reconciliation and complete entitlement reversal remain unavailable. Current controls are development controls. |
| Support / trust | Verified recovery, production compensation, individual staff SSO/MFA, external issue synchronization and operational alert ownership remain unavailable. |
| Sessions / discovery / creator health | Prepared signed-in journeys, exposure/selection and published-track reach exist. Full session replay/explorer, causal attribution, impression opportunity denominators and private editor/draft metrics do not. |
| Reliability | Current queue/worker/storage evidence exists. API uptime/p95/error budgets, cloud backup ingestion, incident ownership and demonstrated restore/RPO/RTO acceptance do not. |
| Configuration / experiments / audit | Immutable contracts and existing role-scoped audit records are inspectable. Mutable remote configuration/activation/rollback, experiments/assignment evidence and individual administrator attribution do not exist. |
| Fleet / verification contracts | Existing local/client versus deployed compiler/physics skew remains a rollout concern. This monitor revision does not silently repin old tracks or alter competitive eligibility. |

There is no fabricated backfill for missing heatmaps or private draft activity. Existing published previews without a prepared projection remain unavailable. Preserved historical drafts are dormant server storage rather than a current monitoring source; deletion/migration of that history and its retention policy are separate decisions.

Changed files and exact task-only patch are listed in `docs/evidence/studio-monitor-revision-2026-10-12/checkpoint.json`. Component contracts, commands and limitations are also recorded in [catalogue/player workspaces](STUDIO_CATALOGUE_2026_10_12.md), [client statistics](STUDIO_RACE_STATISTICS_CLIENT_2026_10_12.md), and [local drafts/publication](STUDIO_LOCAL_DRAFTS_2026_10_12.md). The checkpoint is incremental against the saved dirty workspace; unrelated gameplay/asset changes and private configuration are excluded. `git apply --check` passed against an owned copy of the saved source baseline. The shared Git index was not staged and no commit was created.
