# Menu loading and histogram response speed — 2026-10-10

Requirements: MLOAD01 (immediate Free Race hero), MLOAD02 (independent optional reads), MLOAD03 (populated Rivalry restart/entry), MLOAD04/HOPT03–HOPT05 (fast stored server histograms), RR06/WR01–WR02/WR08–WR10/TD06/TD08/B05/B07/R01/Q01. The owner reports slow Free Race and Rivalry content and clarifies that obtaining histogram data from the server itself must be nearly immediate. This supersedes delaying the hero until optional score/comparison replies arrive. Unknown data must still never be presented as an empty population, or as the previous track's scores.

The client changes are local. A matching histogram server image is built and verified locally, **not published or deployed**. The observed running development backend remains image `61b0accbcfaa3e9e9bdf444273c655bbde853b28a7a5901748854dfebfd7a9f6`, schema `0020_challenges`.

## What caused the delay

`TrackBrowser._load_cloud_detail()` awaited the public leaderboard before starting the authenticated comparison request. `_show_detail()` then withheld the already-resolved hero until the comparison finished. A cloud track lacking compiled geometry also withheld its available metadata hero during download/compilation. Rivalry snapshots lived only in memory, and explicit entry/page activation refreshed them even when recently fetched.

The previously implemented durable histogram backend was absent from the running image. It is documented in [Stored histograms](STORED_HISTOGRAMS_2026_10_10.md). The current source also includes migration 0023's scoped invalidation, needed to prevent an artificial reset from invalidating unrelated/public comparison data.

## Client behavior

- Free Race draws an available track's hero and local PBs immediately. A cold cloud selection draws its metadata route/title/scenery before downloading or compiling the race geometry; its race action remains disabled until geometry is ready. Resolved tracks can race while optional reads are pending.
- Leaderboard and comparison requests start concurrently. Each can populate its own section first, and merging either result preserves the other's data. Existing selection/car/account lifetime guards and duplicate-read coalescing remain. Loading/error/confirmed-empty states stay distinct; the new hero never carries the old track's histogram. No fabricated counts, extra source controls or diagnostic labels were added.
- A bounded atomic presentation cache persists up to 32 recent compatible comparison snapshots for ten minutes, scoped to server/account/population, with the existing content/physics/car/rules key. JSON restores the typed count/edge arrays and uses the existing default marker color. Personal scores cannot cross accounts. The normal selection request still fetches current server data once.
- Rivalry persists one confirmed snapshot per server/account/car/population and pinned physics/rules/compiler/handling scope, for at most 24 hours. Active snapshots cannot survive their remaining week deadline. Cached snapshots are presentation-only: cached membership cannot issue a ticket, and its Race action remains gated until a successful fresh server response. Countdown elapsed time is corrected on restore. Confirmed nonmembership clears persisted membership; Continue clears the completed week.
- Entry, activation and overview returns reuse a snapshot fetched within 30 seconds instead of starting redundant membership reads. Explicit Refresh and periodic/verified-result refresh remain available. First truly uncached entry retains the existing populated-first-load wait and cancellation/account fences; no membership or standings are invented.

## Actual measurements

Read-only live HTTP probe using an **existing artificial diagnostic driver's** development login. No profiles, races, scores, track content, settings or deployments were changed; one diagnostic auth session was issued. Five requests per route reused an HTTP session. The second probe added a transport baseline. [Final live receipt](evidence/menu-loading-speed-2026-10-10/live-latency.json):

| Running service route | Median whole HTTP request |
| --- | ---: |
| Health (no histogram work) | 118.98 ms |
| Bootstrap | 144.05 ms |
| Underpass race/lap comparison | 209.84 ms |
| Ajorata race/lap comparison | 217.77 ms |
| Blind spot race/lap comparison | 214.20 ms |
| Those tracks' leaderboard reads | 147.05–172.54 ms |

The preceding bounded probe measured comparison medians 211.34–247.14 ms and an individual maximum 525.27 ms. The final probe shows an approximate 119 ms connection/HTTP floor on this connection; this is not a guaranteed minimum for other clients. Histogram calculation time and complete remote HTTP latency must not be equated.

The prepared **exact image package**, tested against an owned disposable PostgreSQL 17 database with 1,000 synthetic drivers/1,000 verified attempts, measured **4.698 ms median** for the comparison calculation. First read: three SQL statements; subsequent reads: two; **zero lap-history reads** throughout. An earlier workspace-source run measured 3.596 ms. These exclude authentication, HTTP transport and live-host load. [Exact package benchmark](evidence/menu-loading-speed-2026-10-10/server-postgres-report.json).

Final graphical delayed-network client fixture: initial hero construction **48.555 ms**, comparison cache restore **0.799 ms**, Rivalry membership cache restore **3.447 ms**. The latter two measure disk/read-model hydration, not complete screen rendering or real HTTP. First-frame assertions confirm the hero and restored five-track standings exist while replies are held. The shared comparison Loading caption appears once. [Client timing](evidence/menu-loading-speed-2026-10-10/client-timing.json).

## Prepared server update

Local image `bmt-menu-read:20261010`, image ID `sha256:d16a4a17e3cb64db4d1d654c818f2076a3b633399ede76a19f75d563987d872d`, derives from the exact observed development image. It overlays only the histogram routes/helpers/cache/storage/configuration/idle worker and existing migration chain 0021–0023. All **114 packaged canonical-game files are byte-identical**, as are unrelated backend files. [Image proof](evidence/menu-loading-speed-2026-10-10/server-image-proof.json), [server-only patch](evidence/menu-loading-speed-2026-10-10/server-image.patch).

The image includes durable stored sixteen-bin grids/frequencies/own times, dirty-only background refresh, separate lap revision, bounded shared generation caches and cheap candidate/frame overlays. Requests never generate a histogram or scan attempts. Existing adaptive refresh defaults and player-job priority remain. Competitive PB updates, population deduplication, exact counts, pinned frames and public/artificial isolation remain unchanged. The additive 0021 predecessor preserves existing unlimited challenges; the image does not introduce challenge attempt-limit behavior.

An authorized rollout must first recheck the live parent image and preserve configuration, make a successful fresh database backup, publish the exact image, apply migrations 0021–0023, and prepare initial snapshots with the matching worker before switching the API. Then verify the live race/lap packet counts, actual HTTP latency and worker priority. Empty/invalidated snapshots correctly return unavailable rather than fabricated data; warming before the API switch matters. No rollout or remote migration has been performed.

## Files and actual checks

Changed client/runtime files: `game/ui/track_browser.gd`, `game/ui/track_discovery_provider.gd`, `game/backend/weekly_rivalry_client.gd`, `game/backend/menu_snapshot_cache.gd`, `game/core/app.gd`. Tests: new `game/tests/test_menu_loading_speed.gd`, updated `test_unified_histograms.gd`, `test_menu_loading.gd`, `test_rivalry_entry.gd`. The latter disables persistence for its deliberate cold-reset scenarios; restart persistence is covered by the new suite. Existing coherent local-geometry selection and eligibility checks were retained. This report and the two project status documents record the task. The server runtime implementation already existed in the workspace; its exact-parent packaging/verification is new work.

Commands use pinned Godot **4.7.2 stable ed1daf0bf** via `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, isolated `APPDATA=build/menu-speed-*-user`, and evidence environment variables scoped to this directory. Existing Windows certificate-store access was required because the sandbox denied the engine's startup read.

| Actual command | Outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_menu_loading_speed.gd -Graphical -CommandTimeoutSeconds 90` | **30 checks, zero failures**; independent replies, restart caches, counts, account/population/week fences, cached-ticket rejection, three captures |
| `TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical -CommandTimeoutSeconds 90` | **150 checks, zero failures**; counts/markers, 16-bin grids, delayed selections and three menu sizes |
| `TestScript -ScriptPath res://tests/test_rivalry_entry.gd -Graphical -CommandTimeoutSeconds 90` | **70 checks, zero failures**; cold/preloaded entry, account changes, cancellation, automatic enrollment, errors and guests |
| `TestScript -ScriptPath res://tests/test_menu_loading.gd -CommandTimeoutSeconds 90` | **39 checks, zero failures**; local compile supersession/cache eviction, metadata-first cloud download, optional scores and geometry |
| `TestApp -CommandTimeoutSeconds 90` | **99 checks, zero failures**, including five-lap start/results and saved PBs |
| `TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90` | **424 scripts, zero failures** |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_histogram_snapshots.py backend/tests/test_domains.py -k 'not postgres and (histogram or results_comparison)' -q --tb=short --junitxml=.../server-cache.xml` | **16 passed, 63 deselected**; existing Starlette/httpx deprecation warning |
| `.tools/backend-venv/Scripts/python.exe build/menu-speed/live_latency.py` | Successful live timing/readiness; schema 0020, no race/score/content writes |
| `.tools/backend-venv/Scripts/python.exe build/menu-speed/prepare_server.py` | Offline local exact-parent image build, SQLite migration smoke, comparison route and unchanged canonical-file proof pass; no upload/deploy |
| `.tools/backend-venv/Scripts/python.exe build/menu-speed/test_server_image.py` | **16 passed, 1 skipped, 62 deselected** against the exact image package/owned PostgreSQL, then benchmark exit zero and owned container removed |
| Scoped `git diff --check` / task patch reverse-check | Pass |

The PostgreSQL skip is the SQLite parametrization of a PostgreSQL consistency fixture. Initial exact-image coverage found one retained assertion failure when only migration 0022 was packaged: an artificial reset invalidated a public snapshot. Including existing migration 0023's scoped invalidation corrected it without changing the assertion. [Initial receipt](evidence/menu-loading-speed-2026-10-10/server-image-initial-tests.log). The first client cache test found JSON's untyped numerical arrays differed from the live typed arrays; restoration now normalizes them, retaining exact count assertions. Initial certificate-store/CLI sandbox restrictions and WSL build-context mapping were corrected. No failing product requirement was weakened.

Inspected [first hero with both replies held](evidence/menu-loading-speed-2026-10-10/free-race-first-frame.png), [comparison ready before the leaderboard](evidence/menu-loading-speed-2026-10-10/histogram-before-leaderboard.png), and [restored Rivalry before the network reply](evidence/menu-loading-speed-2026-10-10/rivalry-restored-before-network.png). These are delayed-network presentation fixtures, not live races or invented shipping standings. [Task-only client checkpoint](evidence/menu-loading-speed-2026-10-10/scoped-change.patch) excludes unrelated pre-existing/concurrent work.

## Remaining acceptance

A OnePlus Pad 2/OPD2403 tablet (`f0ba474a`) was attached; **no phone was attached and no physical-device test was performed**. An initial sandbox ADB check failed, then normal certificate/device access confirmed that list. No Android export/install, full Validate, physics regression/merge, remote migration, production deployment or purchase was performed. Client changes require rebuilding/restarting the app; the running development server remains unchanged pending the explicit deployment authorization required by [AGENTS.md](../AGENTS.md).

Remaining checks: authorized development rollout and initial snapshot warmup, post-rollout whole-HTTP/device measurements, owner review under a cold account/track selection and changed championship week, and large-population cold process/RSS validation. The sub-five-millisecond measurement covers the tested server calculation, not every possible population size or remote network.
