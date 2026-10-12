# Community discovery implementation — October 7–8, 2026

Requirements **B01–B07 / B19–B20 / B23 / R01 / V03–V05 / Q01**. The owner accepted the discovery/load/cost proposals and requested implementation. This slice replaces the partial, locally reordered community list with stable global queries while retaining the established menu art, carousel, publication return and canonical racer.

## Result

- **20-preview pages**, with a virtual carousel spanning the entire result set and at most **12 active cards**. The phone/client keeps **15 nearby pages / 300 previews**; evicted pages can be fetched again at their original positions.
- Global name/creator search and public filters run before paging. The search drawer makes an independent **250 ms debounced** lookup; it leaves the active gallery alone until Apply/selection. Cached suggestions remain available while the lookup runs. Broad searches offer **Browse all matches** rather than creating thousands of search buttons.
- **Recommended / New / Popular / Top rated**, plus **Favorites / My tracks**, under Filters. Personal collections fetch their exact logical IDs independently of community preview residency. Raced/Not raced retains the explicit device-history contract. The available count filter is labeled **Verified drivers**, using the actual distinct-finisher counter; it does not claim a completed-race total.
- Server ordering is retained when pages append. **Refresh** starts a new snapshot; scrolling continues/reloads the current one. Random samples the complete eligible snapshot and rechecks current visibility, including the case where most tracks were hidden since browsing began.
- Publication opens **Free Race → New**, selects its acknowledged public revision and locates that revision's page even if simultaneous publications put it beyond page one. The temporary handoff pin clears after a valid server result; withdrawal still removes it.
- Existing backends negotiate compatibility through bootstrap. The legacy path now stores/follows search continuation; modern feed controls are disabled when the server lacks protocol two. Its historical 1,000-entry behavior remains only on that compatibility path.

## Backend and cache contract

`POST /v1/discovery/tracks` accepts the normalized query, opaque snapshot cursor and optional absolute offset. `POST /v1/discovery/random` selects globally under the same query. Responses contain a stable snapshot ID, total-at-creation, absolute card indices, 20-item page, continuation cursor and page token. `locate_version` positions the initial page around an acknowledged publication without changing query eligibility. The query hash binds filters and ownership; cursors cannot be reused across a different query or account collection.

Migration **0019_discovery_snapshots**, following the concurrent **0018_player_country** prerequisite, stores only ordered immutable version IDs, not track documents or preview payloads. A common first query shares its result for **20 seconds**, including across API replicas through the database. Browsing snapshots expire after **30 minutes**; visibility is rechecked on every page/random read. A hide leaves an unavailable position until Refresh rather than shifting every following card. Expired snapshots are deleted in bounded batches on cache misses. Each API keeps at most 64 snapshot entries / 100,000 IDs in memory, with per-query coalescing rather than one global lock around cold database work.

PostgreSQL uses native trigram indexes for name/creator substrings, a recent verified-run index and existing publication/latest-version indexes. Large personal ID lists use one array parameter on PostgreSQL and a JSON table on SQLite. Discovery POSTs spend read budgets and bounded request-body allowances. No new search/cache service, runtime AI, analytics provider, payment integration or hosting resource was added. Cloud SQL's supported extension list was checked before packaging `pg_trgm`: [official extension documentation](https://docs.cloud.google.com/sql/docs/postgres/extensions).

**Provisional ranking defaults**, available for owner review: Recommended interleaves three trusted official choices with one community choice; all eligible tracks remain reachable. Popular orders by distinct actual verified drivers over the preceding seven days and excludes artificial identities, creator-test boards and test populations. Top rated uses five neutral 3.5-star prior observations to reduce single-vote dominance. Cards still show their actual rating average. New includes unrated publications, and Weekly Rivalry's eligibility thresholds are not used as a Free Race gate.

## Retained staging rollout

The existing development backend now advertises `discovery_paging_version: 2`. Successful pre-change Cloud SQL backup: **1791407633405**. Current immutable image:

`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:06081c2f82d50687fc152abeeeb675b2ebcea5a9479d664d18a4cdb9b80af9af`

The initial ownership/image guard caught a newer unrelated deployment and refused to roll it back. The final image is a minimal overlay over that actual deployed parent (`b486feaa…`). Existing authentication, country behavior, store/rivalry code, accounts, tracks, original share links and records are preserved. The schema prerequisite adds its approved country column/data before 0019; country UI/auth behavior was not replaced by this slice.

All **98 packaged game files** remain byte-identical to the parent; game digest **de432eebe52d9edbb1ad4476f13267cc4fd5b8687ff07a3f69afa248903d4a01**. The inherited engine/native contract stays physics **0.52**, compiler **22**, rules **v19**, five laps. Matching API/worker/migration/smoke/catalog templates use the new image. Existing CPU/memory/instance counts and protection/retention settings remain. This update adds no hosting instances or subscriptions.

The packaged native replay/storage/schema smoke passed after rollout. Public discovery and the actual Star menu/search were checked from an isolated guest session/cache; no saved owner session was read and no player race/PB/purchase was submitted. Snapshot cache rows are internal read-model state.

## Actual checks and measurements

Pinned **4.7.2.stable.official.ed1daf0bf**, through `scripts/dev.ps1`:

| Check | Actual result |
| --- | --- |
| Real virtual carousel / 5,000 server-shaped records, complete traversal, eviction/reload, stale queries, invalid pages, global search/favorites, sizing and five captures | **274 checks, zero failures**, graphical; earlier headless **268** before final sizing assertion |
| Actual public staging catalog, Star/download/selection, global search, feed controls, card footers, desktop/compact captures | **15 checks, zero failures; 28 public tracks** |
| Original publication regression | **22 checks, zero failures** |
| App flow / offline catalog / menu presentation / recovery | **99 / 21 / 48 / 86 checks, zero failures** |
| Discovery contracts on SQLite and owned PostgreSQL 17 | **18 pytest cases passed**, one existing Starlette warning |
| Real HTTP cloud library and durable publishing with protocol two explicitly negotiated | **2 tests passed**, including lost response, cache-index recovery, new revision and withdrawal |
| Existing auth/lifecycle/scalability batch | **58 passed / 3 skipped / 21 PostgreSQL cases deselected** |
| Updated legacy diagnostic | **6 checks, zero failures**; search now reaches 40 results through two requests; original analysis source/results retained separately |
| Ruff F/E9, task whitespace | Passed; normal repository CRLF notices only |

Owned PostgreSQL **17.11**, **1 CPU / 512 MiB**, **50,000 synthetic tracks / 100 authors**, sequential Windows TestClient, no TLS/mobile latency: warm page p95 **15–71 ms** by query; deep page p95 **28 ms**; random p95 **98 ms**. Cold broad queries **326–407 ms**, rare-name cold **26 ms**, creator cold **80 ms**. The rare-name plan uses the trigram bitmap index. This is a local sequential benchmark, not deployed concurrency/capacity proof; cold broad queries exceed the earlier provisional 200 ms target. [Exact benchmark and plan](evidence/discovery-paging-2026-10-07/postgres-50000.json). The labeled PostgreSQL lab and its private connection files were removed after testing.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_pages.gd -Graphical
$env:BMT_STAGING_API_URL = 'https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_live.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_discovery.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCatalog
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestMenus
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_review_followups.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendTestLifecycle
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/analyse_discovery_scale.gd
.tools/backend-venv/Scripts/python.exe .tools/discovery_pg_lab.py start
.tools/backend-venv/Scripts/python.exe .tools/discovery_pg_lab.py test
.tools/backend-venv/Scripts/python.exe .tools/discovery_pg_benchmark.py
.tools/backend-venv/Scripts/python.exe .tools/discovery_pg_lab.py stop
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_auth.py backend/tests/test_track_lifecycle.py backend/tests/test_scalability.py -q -k 'not postgres' --tb=short
.tools/backend-venv/Scripts/python.exe -m ruff check --select F,E9 backend/bmt_backend/discovery.py backend/tests/test_discovery_paging.py backend/bmt_backend/migrations/versions/0019_discovery_snapshots.py
```

Owned ignored operator `.tools/discovery_rollout.py`: `inspect`, `build`, `backup`, `migrate`, `deploy`, `smoke`. Frozen/overlay source, exact parent/image, successful backup and ownership checks protect the existing retained environment. Build checks the migration graph and actual native manifest as the runtime UID. No production deployment occurred.

Corrected intermediate failures remain in the task record: initial migration-number collision with concurrent country work; ambiguous ORM page join; PostgreSQL fixture's schema-prefix guard; fixture empty-string search; missing retained fixture metadata; publication pin persisting after withdrawal; missing migration prerequisite in the parent image; container home ownership causing a rejected native startup; card minimum size being overwritten by `_ready()`; two unused imports and a mistyped test path. Guards, assertions, native error detection and schema/ownership checks were retained. The failed migration stopped before SQL changes. Runtime packaging ownership was fixed rather than suppressing engine errors.

## Changed files and evidence

Runtime: `game/backend/discovery_pages.gd`, `cloud_tracks.gd`, `backend_client.gd`; `game/core/app.gd`; `game/ui/track_browser.gd`, `track_catalog.gd`, `track_discovery_provider.gd`, `track_filter_drawer.gd`, `track_search_drawer.gd`; backend `bmt_backend/discovery.py`, `app.py`, `middleware.py`, `security.py`, `migrations/env.py`, `migrations/versions/0019_discovery_snapshots.py`. Contracts: `backend/schemas/discovery-query-v2.schema.json`, `discovery-page-v2.schema.json`.

Tests: `backend/tests/test_discovery_paging.py`, `game/tests/test_discovery_pages.gd`, `test_discovery_live.gd`, protocol negotiation in `test_track_lifecycle.gd`, and the updated legacy `analyse_discovery_scale.gd`. Documentation: this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, task-start sources, source hashes, logs and scoped Git patch. Concurrent physics/rules, soundtrack, country and predictive-driver source work remains outside the task patch.

Inspected actual captures: [Star desktop](evidence/discovery-paging-2026-10-07/live-star-desktop.png), [compact Star](evidence/discovery-paging-2026-10-07/live-star-compact.png), [global search](evidence/discovery-paging-2026-10-07/live-global-search.png), [filter drawer](evidence/discovery-paging-2026-10-07/live-filter-drawer.png). Earlier clipped-card captures were replaced only within this task's evidence after correction; the prior publication-review captures are preserved.

## Remaining acceptance

Restart the desktop app to load the updated client. The test backend is already updated. Owner ranking/visual acceptance, actual phone touch/readability/frame-time/memory, long-session expiry handling and concurrent/unique-query workload remain to measure. Database snapshot ID storage and cold whole-query materialization need monitoring as catalogs/query diversity grow; cache miss timing is not an achieved 200 ms gate.

No Android export/install/device exercise or full Validate was performed; phone attachment was not checked. The separate current workspace physics **0.53 / rules v20** changes were intentionally excluded from this deployment and still need their own matching verifier rollout for online racing. This discovery task did not migrate old scores or change pinned rivalry contracts.
