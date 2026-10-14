# Published catalogue and player investigation workspaces

Owner request, 2026-10-12: use `temp/backend-gui/BMT_Studio_Prototype.html` as the direction for useful content and player investigation views; drafts stay on the mobile, track browsing needs sorting/filtering and route previews, and Player support needs a coherent investigation workspace. This slice addresses BMT-030/033/036 (content/discovery context) and BMT-050/051 (redacted player support), within the larger Studio revision.

The prototype's **Tracks & creators**, immutable track detail, and **Player support** define the hierarchy: purpose, scope, compact summary, useful search/filter table, version-pinned route/context, and a player profile with evidence timeline plus support sidebar. Its demonstration counts, monthly free-slot example, fabricated device/revenue identities and synthetic scores are not live requirements. The approved one-initial-slot/no-refill and UTC-calendar-month policies remain.

## Implemented contracts

- `GET /v1/admin/catalogue/tracks`: published immutable versions only; latest published version per track by default, with all-published-version browsing. Search by track/creator/ID/biome, and filter biome, visibility, official/community, creator, minimum rating and minimum qualified finishers. Sort publication date, track name, creator, average rating or qualified finishers in either direction. No draft state or draft detail is exposed by this workspace.
- Route thumbnails and detail shape use the existing stored discovery projection, at most 96 finite bounded points. Catalogue reads fetch no content objects and invoke no compiler, geometry builder or verifier. Missing prepared previews remain explicitly unavailable. The schematic is a lap route, not road width/elevation.
- Track detail follows exact accepted server submissions, pinned tick-rate time, published versions, creator and linked cases. Raw contract fields are behind a disclosure. Exposure/selection comes from prepared signed-in discovery facts in the selected UTC day window, separate from lifetime catalogue metadata. Missing observations remain unknown; a selected card is not a race start.
- `GET /v1/admin/catalogue/players`: everyone by default, including artificial drivers identified by the authoritative account flag. Search and account/population/provider filtering, account-created/name sorting, bounded per-page server submission/PB/publication/case context, and retained last-observed activity **day**, without pretending it is precise online time.
- Player detail presents profile, server evidence timeline, access/resume policy, linked support cases, prepared player journey and an investigation sidebar. Existing audited development purchase controls and cursor-based redacted history remain available under their current permission/configuration gates. Production revenue, recovery, compensation, guest linkage and device identity remain unavailable.
- Both roles read; existing owner commands retain their explicit preview/reason/idempotency workflow. New catalogue routes are read-only and `Cache-Control: no-store`. Account access, race counts, cases and prepared journey context share a read-only database snapshot. GET does not create an entitlement row or wallet.
- Metadata pages are capped at 100 rows and offset 10,000. The creation-time anchor excludes later inserts, with deterministic identifier tie ordering. Mutable rating, visibility, name and publication changes can reorder subsequent pages; this is disclosed in the API rather than claiming a frozen historic database. Filters and the list return route persist across detail/back navigation.

## Files and compute

New module `backend/bmt_backend/studio_catalogue.py`, assets `admin_ui/catalogue.js`/`catalogue.css`, additive migration `0030_studio_catalogue.py` (after `0029_race_statistics`), focused tests `backend/tests/test_studio_catalogue.py`, and fixture/browser hooks `scripts/studio_catalogue_browser_checks.py`. Root integration registers the router/assets and calls `catalogueView()`/`wireCatalogue()` in the existing shell.

The migration adds published name/finishers/rating sort indexes, account-created/name indexes and player/track case indexes. It changes no business data. The track list uses prepared metadata and discovery counters, never joins raw race submissions/PBs/events to sort its catalogue. Per-player server aggregates are restricted to this page's account IDs and use existing account indexes. Substring search and exact filtered totals still depend on catalogue size; no full-text dependency is added.

Prepared discovery reads are capped at 1,000 fact rows for the selected page/window and disclose truncation. Shape costs are bounded by page-size × 96 points. There is one catalogue GET per manual view/filter/page, with no polling or individual shape requests. This is an admin traffic contract, not an on-device/network-performance claim.

## Actual verification

Run in `backend/`:

```powershell
& ../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_catalogue.py -q --tb=short
& ../.tools/backend-venv/Scripts/python.exe -m ruff check bmt_backend/studio_catalogue.py bmt_backend/migrations/versions/0030_studio_catalogue.py tests/test_studio_catalogue.py ../scripts/studio_catalogue_browser_checks.py
```

Run at the workspace root:

```powershell
& .tools/backend-venv/Lib/site-packages/playwright/driver/node.exe --check backend/bmt_backend/admin_ui/catalogue.js
```

Actual results: **7 backend tests passed**, Ruff passed and bundled-Node JavaScript syntax check passed. Tests cover admin authentication/no-store/read-only, published-only list/detail, literal SQL-search escaping, all metadata sorts/filters, anchored paging, missing observations, cached preview bounds/no blob or verifier, pinned timing, factual player/context redaction and GET without initialized balances. A 2,000-row owned SQLite catalogue plus `ANALYZE` verifies the actual name-sort SELECT uses `ix_studio_published_name` without a temporary sort and the list executes no raw race/PB/event SQL. Tiny three-row fixtures correctly prefer a selective state index and an in-memory sort; the production-sized guard preserves its index assertion.

Browser hooks seed only a newly owned loopback fixture (35 published route shapes, one private draft, one case/journey). They exercise filter/back persistence, paging, empty state, support tabs/development preview and 1440/960/390-width containment and capture. Final combined browser outcomes and screenshot locations are recorded by the root Studio revision report; these hooks are not a claim that a browser suite already ran.

No phone test, client export, deployment, provider call or live-data mutation was performed by this slice. PostgreSQL and combined browser acceptance belong to the final root verification. The backend publication workflow and one-package race statistics/heatmaps are separate concurrent slices; this module alone does not migrate or delete historical server drafts.

## Pulse, reliability and competition presentation follow-up

The root requested a coherent prototype-led presentation for the existing operational/evidence sources. New `admin_ui/monitor_views.js` and `monitor_views.css` expose:

- `monitorPulse(d, params)`: one additional **prepared** product-analytics GET beside the existing overview. Latest fully observed complete-day activity, distinct period activity and latest mature exact D7 keep their own denominators. Current incomplete days are visibly separate; unavailable days break the activity trace. Crash-free sessions remain unavailable instead of deriving a false rate from Android process exits. The investigation queue links real pending/failed/rejected/projection work to relevant evidence, without inventing an incident or affected-player ranking. An unavailable product source preserves successful operational records and presents missing activity as unknown. Abandoned/auth-invalid requests remain fenced by the shell.
- `monitorCompetition(d, kind)`: pinned scope/state, actual roster, track-by-track best/result point table, stored/evidence rank and point differences, accepted-source links and actionable descriptions of provenance inconsistencies. Assigned slot count comes from `d.slot_count` if exposed by the root; otherwise only retained result slots are shown. No entrants, official ranks, ghosts, progression rewards or scores are invented. Contract details are collapsed; the primary view explains what an operator can investigate. Source gaps do not mutate official scores. Result lookup maps keep presentation work proportional to the bounded result/roster/slot arrays.
- `monitorReliability(d, health)`: formats an already fetched competition-health snapshot, with no extra query. Compatible worker count, actual queue, oldest age, five-minute infrastructure-failure denominator, current lifecycle and source-specific storage/backup evidence lead to investigation links. API uptime/p95, remote free capacity, restore success, alert ownership and historical release stability remain explicitly unavailable. Receipt-to-terminal verification latency is kept separate from driving and API request latency.

The additional CSS is confined to `.mon-view` and prefixed helpers; it uses the prototype's card/grid hierarchy, readable 14px body, source notes, bounded evidence tables and responsive layout. Existing global styles, shell rendering and operations wiring remain root-owned. This improves presentation and decision paths; it does not establish that all original production-monitor requirements are complete.

Actual new command:

```powershell
& .tools/backend-venv/Lib/site-packages/playwright/driver/node.exe --check backend/bmt_backend/admin_ui/monitor_views.js
& .tools/backend-venv/Lib/site-packages/playwright/driver/node.exe scripts/test_studio_monitor_views.js
```

Syntax passed and **5 presentation-contract checks passed**. Checks cover one scoped source GET, latest complete/mature denominators, missing-source/immaturity not becoming zero, cancellation, trace gaps, actual competition slot count, source-review explanations and non-mutating rendering, escaped names, real worker mismatch/failure rate and unavailable production-health sources. These pure presentation checks use owned fixtures and do not replace the root's final browser/visual acceptance.

## Final integration corrections and supporting workspaces

The PostgreSQL migration run caught ungrouped arithmetic in the rating-expression index. `0030_studio_catalogue` now explicitly groups `(rating_sum * 1.0 / nullif(rating_count, 0))`. PostgreSQL and SQLite offline DDL both compile to `ON track_versions ((rating_sum * 1.0 / nullif(rating_count, 0)), id) WHERE state = 'published'`. An actual SQLite application of all seven indexes and rated/unrated semantics passed. Root's final PostgreSQL result remains the authoritative PostgreSQL acceptance.

Combined browser acceptance initially caught two catalogue navigation problems: an outgoing table could satisfy the row-count assertion before a new page finished, and initial links omitted the response anchor / explicit zero offset while returned links included them. The view now canonicalizes response anchor and `offset=0` into its current history state (without another request), and row/detail/back links preserve that scope. The helper waits the actual GET and completed render; the original exact initial/Previous href equality assertion remains. The browser agent then reported **22 combined checks passed** before the subsequent case/monetisation refinements; root's final combined run covers the final state.

`operations.js` now presents support cases as a status-filtered bounded investigation table and readable newest-first notes/report/appeal/decision timeline with linked player/content context. It retains the **Activity** heading, existing command selectors and authoritative `allowed_transitions`. Shared modal/dialog-generation handling supplies accessible naming, focus return and stale/auth fences. Existing quarantine/restoration actions receive an explicit visibility preview, bounded reason and acknowledgement. No compensation, identity recovery or new moderation authority was introduced. The exact existing file baseline was saved before edits under `build/studio-revision-2026-10-12/catalogue-before/operations.js`.

Read-only publication processing list/detail uses the existing `/v1/admin/publications` metadata API, with current queued/failed counts, processing/retry evidence, creator, committed-version and accepted creator-run links. It reads no document or trajectory object and provides no retry/spend/refund command. Publication attention in Pulse consumes the root's bounded `d.publications` overview counts, preserving its single additional prepared-product GET. The failure-cap lower bound remains explicit. Reliability now consumes root's `pending_publications` field ahead of the historical validation count, so publication work is included in its queue story.

`commerce.js` now follows the prototype's financial-source coverage → operational purchase investigation → development-catalogue controls hierarchy. It retains existing product/purchase GETs, player/provider/state/date/cursor scope and adds visible record/product search. Simulation remains **no payment** and excluded from financial totals; verified spend, ad proceeds, settlement/refunds and reversal ledger stay unavailable. Existing product preview/revision/idempotency/auth commands are unchanged. Cursor backtracking is bounded by scope and auth generation, preserving the investigation filters instead of navigating browser history into another workspace. Its prior file was saved under `build/studio-revision-2026-10-12/catalogue-before/commerce.js`.

Final local checks after these corrections: **7 catalogue backend tests passed**, Ruff passed, changed JavaScript syntax checks passed, and **6 presentation-contract checks passed** (including financial-source order/absence and new publication queue fields). Browser/layout checks on the final case/publication/monetisation state are coordinated with the root browser agent. No deployment, live mutation, provider API, phone test or client export was performed by this work.
