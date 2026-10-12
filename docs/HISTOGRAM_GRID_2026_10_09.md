# Stable, finer histograms — 2026-10-09

Requirements: RR06/R01/R03, TD06/TD08, B05/B07, V03/V05 and Q01. The owner reports changing bins shortly after the histogram appears and insufficient resolution. The correction applies to normal race-complete results and the Race track preview.

Results and discovery now request **16 bins**, up from eight. The development backend is updated and the Android client is installed/launched on the connected OnePlus Pad 2. Live Underpass returns 16 race bins and 16 best-lap bins over 101 distinct drivers, including the retained 100 artificial PBs. All 27 eligible tracks pass live counts/metrics and repeated fixed-domain checks.

## Cause and correction

The server previously recalculated its bin start/width from current verified extrema on every request. A pending result becoming a new PB could change the minimum and retire the previous maximum, immediately rearranging both charts. Discovery also displayed previously cached coarse bins before fetching new data.

The server reserves the completed display-only candidate's time range on the initial request, without counting it as a verified sample. Both metrics accept paired `race_from_ticks`/`race_to_ticks` and `lap_from_ticks`/`lap_to_ticks` parameters. Results sends the first displayed boundaries on subsequent requests; discovery preserves its cached compatible boundaries and sends known local PB candidates. This holds the bin edges while verification updates actual counts, PBs and exact placement. Actual verified minimum/maximum fields remain unchanged by display candidates. The response remains one atomic, deduplicated real/artificial field, with public competition/rating/eligibility isolation intact.

Discovery caches identify the requested resolution. Old eight-bin/untagged distributions are not drawn before the finer response arrives. Normal result times/PB markers remain available during loading. No source selectors, diagnostic counts, test classifications or new UI captions were added.

New genuine extrema **outside** the reserved range can expand the domain so every driver remains represented. This is a deliberate completeness limit, not a promise to freeze all future population changes. The domain is remembered for the current results view or compatible track/vehicle preview cache; it is not a permanent league/track timing bound. The 16-bin choice is a reviewable local presentation default, not an owner-approved balance constant. Normal results first, actual five laps and best-only verified scoring remain intact.

## Changed files

- `game/ui/race_complete.gd`: 16-bin requests and preserved race/lap frame parameters.
- `game/ui/track_browser.gd`: compatible cache tagging, no old coarse first frame, local PB candidates and preserved frame queries.
- `backend/bmt_backend/runs.py`: display-only candidate domain, bounded paired frame parameters, default 16 bins; all actual counts/ranking queries unchanged.
- `backend/tests/test_domains.py`: real fixture PB verification that changes both extrema, with identical before/after edges, updated counts and invalid-frame rejection.
- `game/tests/test_race_results.gd`, `test_unified_histograms.gd`: finer request/pinned-domain assertions and old-cache first-frame regression.
- Response-schema description, this report and development/phase status. No canonical simulation, track, car, audio, dust or art asset change.

## Actual verification

| Command | Outcome |
| --- | --- |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py backend/tests/test_test_drivers.py -q -k '(histogram or results_comparison) and not postgres' --tb=short --show-capture=no` | **7 passed, 66 deselected**, SQLite. Same tests against the exact packaged `runs.py` in an isolated package copy: **7 passed**. Other supporting modules in that copy use current workspace sources; actual image import/smoke is separately verified. |
| Ruff on `runs.py` and `test_domains.py`; scoped whitespace/patch checks | Pass. |
| Pinned `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_results_histograms.gd -Graphical` | **50 checks, zero failures**; three landscape sizes and marker fixtures. |
| Pinned `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` | **50 checks, zero failures**; includes hidden coarse cache and fixed-domain refresh. |
| `TestScript ...test_results_histograms.gd`, optional `BMT_LIVE_RESULTS_PACKET=.../live-underpass-after.json` | **44 checks, zero failures** against the actual deployed 16-bin packet. |
| `scripts/dev.ps1 ExportAndroid -QuickValidation` | Import/APP_READY, driving **72**, catalog **21**, menus **48** pass; debug export completes. Full `Validate` not run. |
| `scripts/dev.ps1 Doctor`, `InstallAndroid`, `LaunchAndroid` | OnePlus Pad 2 **f0ba474a** attached/authorized; install **Success**, launch **COLD/Status ok**. Tablet was confirmed idle in Race before install. |

Graphical checks used isolated `APPDATA` directories and pinned Godot **4.7.2 ed1daf0bf** through `scripts/dev.ps1`; Windows certificate access was permitted. The first sandbox-only Doctor failed to create the default ADB directory; the permitted device check passed. A combined packaged-test shell returned exit 1 only from a subsequent unmatched function-name search; its actual pytest result was seven passes. No failing assertion was weakened.

Inspected [compact results](evidence/histogram-grid-2026-10-09/comparison-960x540.png) and [compact discovery](evidence/histogram-grid-2026-10-09/discovery-960x540.png) show the finer charts and original markers. Desktop/wide variants are in the same evidence directory. Captures use retained canonical Silmukka driver records and explicit player presentation fixtures, never new submitted races. [Fixture provenance](evidence/histogram-grid-2026-10-09/verified-silmukka-histograms.json).

## Authorized development rollout

The preceding explicit backend-update authorization remains in force. A one-module exact-function overlay derives from deployed image `a00d8aede0a2e73e8f3d9ca2377e134b1dcdd0bc756e820173e4a13750c4ad18`. All **112 packaged canonical-game files** are byte-identical. Fresh successful Cloud SQL backup **1791571338120** preceded upload. Development API, worker and associated migrate/smoke/catalog job images now use immutable digest **da0ab3da07ceb28bd6a2ae63294ef6faeff99dad3e09d0219e34347c4c114c63**. No migration/reseed was required or run. [Proof](evidence/histogram-grid-2026-10-09/packaged-game-proof.json), [deployment receipt](evidence/histogram-grid-2026-10-09/deployment.json), [exact image patch](evidence/histogram-grid-2026-10-09/backend-image.patch).

Actual private helper commands: `prepare.py`; local cached-parent Docker build with `--pull=false --network=none`; `deploy.py backup`, `publish`, `deploy`, `smoke`; `verify_live.py`; `audit.py`, all under `.tools/histogram-grid-20261009`. API/worker **Ready**. The actual smoke log confirms schema **0020_challenges**, **12,757 canonical ticks**, results API present, two temporary diagnostic storage objects and **zero player writes**. [Readiness/smoke](evidence/histogram-grid-2026-10-09/final-readiness.json).

Live reads check all 27 tracks with 16-bin requests and repeated pinned-frame requests, preserving exact edges, all counts and metric/board scope. Underpass has **101 race and 101 lap contributors**, 16 bins each; its private board remains rejected by the public histogram route (404). [Live Underpass](evidence/histogram-grid-2026-10-09/live-underpass-after.json), [catalog checks](evidence/histogram-grid-2026-10-09/live-catalog-checks.json). Existing artificial diagnostic sessions only; no new profiles, races, player-record changes or production action.

## Tablet and remaining acceptance

Installed APK **244,646,086 bytes**, SHA-256 **259161eb5bbbd7f763a992e39a9f9f1aa50e06512412f9230b14690f09fb9734**, retained at `build/histogram-grid-2026-10-09/circuit01-debug.apk`. Records/sign-in data are preserved. [Install/build receipt](evidence/histogram-grid-2026-10-09/android-update.json).

The post-install chart captures were black. Read-only power/window checks confirmed **Asleep** and **secure keyguard showing**; waking the display did not bypass the lock. These captures are not claimed as successful device chart evidence. No race was started and no device result/verification flow was tested. Remaining acceptance: owner unlock and visual review of results/preview refresh on the tablet; other devices, PostgreSQL and full regression were not tested. [Task-only source/documentation checkpoint](evidence/histogram-grid-2026-10-09/scoped-change.patch) preserves unrelated concurrent work.
