# Menu loading and histogram response speed — 2026-10-10

Requirements: MLOAD01 (immediate Free Race hero), MLOAD02 (independent optional reads), MLOAD03 (populated Rivalry restart/entry), MLOAD04/HOPT03–HOPT05 (fast stored server histograms), RR06/WR01–WR02/WR08–WR10/TD06/TD08/B05/B07/R01/Q01. The owner reports slow Free Race and Rivalry content and clarifies that obtaining histogram data from the server itself must be nearly immediate. This supersedes delaying the hero until optional score/comparison replies arrive. Unknown data must still never be presented as an empty population, or as the previous track's scores.

The client changes are local. Following explicit owner approval, the tested histogram image **is now deployed to the development API and worker**, digest `d16a4a17e3cb64db4d1d654c818f2076a3b633399ede76a19f75d563987d872d`, schema `0023_operational_read_indexes`. The initial review below measured its predecessor `61b0accbcfaa3e9e9bdf444273c655bbde853b28a7a5901748854dfebfd7a9f6`, schema `0020_challenges`. See the approved rollout record below.

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

The approved rollout rechecked the live parent image and preserved container configuration, made a successful fresh database backup, published the exact image, applied migrations 0021–0023, and prepared initial snapshots with the matching worker before switching the API. Empty/invalidated snapshots correctly return unavailable rather than fabricated data; warming before the API switch matters. The source-only image proof retains its original predeployment state; the deployment receipt records the subsequent rollout.

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

A OnePlus Pad 2/OPD2403 tablet (`f0ba474a`) was attached during client verification; **no phone was attached and no physical-device test was performed**. An initial sandbox ADB check failed, then normal certificate/device access confirmed that list. No Android export/install, full Validate, physics regression/merge, production deployment or purchase was performed. Client changes still require rebuilding/restarting the app; the development backend has been updated under the owner's explicit authorization.

Remaining checks: physical-device measurements, owner review under a cold account/track selection and changed championship week, and large-population cold process/RSS validation. The sub-five-millisecond measurement covers the tested server calculation, not every possible population size or remote network. Live whole-HTTP delay remains variable as recorded below.

## Approved development rollout — 2026-10-10

The owner explicitly instructed: **“yes, proceed with backend deployment.”** Requirements MLOAD04/HOPT03–HOPT05/B05/B07/R01/Q01/TD06/TD08. The exact previously tested local image was published and deployed, with no rebuild or unrelated source overlay. Successful fresh Cloud SQL backup **1791631372709** preceded migration. Development API, worker, migration, smoke and catalog jobs use the immutable `d16a4a17…` digest. Their environment, command/arguments, resource limits and volume-mount configuration hashes are unchanged. All 114 canonical files remain exact. [Rollout receipt](evidence/menu-loading-speed-2026-10-10/deployment.json), [final service/smoke proof](evidence/menu-loading-speed-2026-10-10/final-deployment-proof.json).

Migrations 0021–0023 completed successfully. The first warmup assertion correctly refused the API switch with **980 fields pending**: the migration job deliberately disables artificial processing. The matching development worker, retaining its existing configured gates, then prepared the remaining fields. The retry only waited for that normal worker and checked the full field set; no authentication bypass or artificial-data setting was enabled on the migration job. Progress fell from 338 to 43 to **zero**, after which the API switched. [Count-only warmup logs](evidence/menu-loading-speed-2026-10-10/warmup-log.json). No histogram-unavailable assertion was weakened.

Actual authorized helper commands: `.tools/backend-venv/Scripts/python.exe build/menu-speed/deploy_backend.py backup`, `publish`, `migrate`, `warm` (first assertion failure), `diagnose`, `worker`, `warm` (pass), `audit`, `deploy`, `smoke`, `timings`, `proof`. Registry authentication was passed through stdin using the existing operator credential and removed from the temporary Docker configuration afterward. Configuration/secrets were preserved; no player PB reset, reseed, track rewrite, resource-size change, release/production action or purchase occurred. Ordinary existing worker activity continued.

Post-deployment checks:

- `build/menu-speed/verify_catalog_after.py`: **all 27 eligible compact tracks pass** real stored race/lap packets, complete population/bin sums, sixteen-bin bounds, unchanged retained frames and unified population scope. The private artificial board remains **404** on the public histogram route. [Catalog receipt](evidence/menu-loading-speed-2026-10-10/live-catalog-deployed.json).
- Existing deployed smoke job: **12,757 diagnostic canonical ticks**, **12,757 trajectory ticks**, trajectory calculation **1.988 ms / zero engine calls**, schema **0023**, results API present, **two temporary storage objects** and **zero player writes**. Final API and worker are Ready on the tested image. This is the retained diagnostic fixture, not a new scored player race.
- Pinned `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_results_histograms.gd -CommandTimeoutSeconds 90`, isolated APPDATA and `BMT_LIVE_RESULTS_PACKET=.../live-underpass-deployed.json`: **44 checks, zero failures**, using the actual newly deployed packet. [Native receipt](evidence/menu-loading-speed-2026-10-10/deployed-native-histograms.log).
- `build/menu-speed/live_latency_after.py`: two whole-HTTP probes retained. Initial concurrent catalog/smoke probe: comparison medians **223.74–380.12 ms**. Standalone repeat: **292.15–357.96 ms**, health **335.43 ms** median. [Concurrent](evidence/menu-loading-speed-2026-10-10/live-latency-after-concurrent.json), [standalone](evidence/menu-loading-speed-2026-10-10/live-latency-after.json).
- New-revision server request logs: comparison handler **30.32 ms median** over 75 successful reads, leaderboard **36.10 ms**, health **1.26 ms**. These include authentication, endpoint work and serialization, unlike the local 4.698 ms calculation probe. [Bounded server timing receipt](evidence/menu-loading-speed-2026-10-10/server-request-timings.json).

The deployment removes per-request histogram reconstruction, but **a whole-HTTP latency improvement was not established** by these measurements. Health also became much slower externally while remaining about one millisecond inside the application. Most observed delay lies outside the measured handler; these data cannot separate network latency from platform queuing. No claim of instantaneous real HTTP responses or a universal five-millisecond request is made. Client metadata previews, parallel reads and restart caches are still local app changes and were not installed on the tablet in this backend-only rollout.

No device test, new phone attachment check, Android export/install or full Validate was performed in the deployment turn. [Deployment-only documentation checkpoint](evidence/menu-loading-speed-2026-10-10/deployment-scoped-change.patch) preserves concurrent local work and the earlier client checkpoint.
