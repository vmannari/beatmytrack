# Track of the Day loading — 14 November 2026

The page now restores a short-lived saved track and matching standings before waiting for the network. Repeated activation no longer restarts the same standings request, and a recently completed request can be reused. A race still revalidates the featured track and obtains fresh Daily limits.

## Requirements and changes

- **DPL01 — Fast reopening, including process restart.** `game/persistence/daily_menu_cache.gd` keeps at most eight snapshots in a 128 KiB atomic sidecar next to the selected records file. Snapshots expire after five minutes and at the server's event boundary. Clock reversal, corrupt or oversized files and incompatible envelopes are ignored. The existing origin/account/event/car/local-best keys isolate presentation. Saved track geometry is checked before constructing the card. Metadata invalidation removes its saved copy; cache IO failure does not change records, race authorization or page error handling.
- **DPL02 — Avoid duplicate work.** `game/ui/daily_result_card.gd` separates explicit refresh from activation/configuration. Matching active requests retain their serial and original retry timer. Successful RAM standings can be reused for 30 seconds. Disk standings render immediately and refresh in the background. Explicit Retry, identity and verification signals still request fresh data. Car/result/account changes select a different request key. `game/ui/track_of_day_page.gd::activate` uses this path. Preview pages restore presentation without dispatching requests.
- **DPL03 — Retain authoritative starts.** `game/core/features/daily.gd` loads/saves only scoped presentation. The existing `_request_race` metadata recheck and race-limit loading remain authoritative. The focused App fixture and actual Daily Game installation verify those boundaries.

The changed sources, two new script UIDs, regression and offline runner are archived in [the source checkpoint](evidence/daily-page-loading-2026-11-14/source-only.patch). The eight-file checkpoint applies and reverses exactly after LF normalization, using a private build directory and no shared index staging. Other existing workspace edits were preserved.

## Measurements and verification

All runtime checks use pinned Godot **4.7.2.stable.official.ed1daf0bf**, Dummy audio, private APPDATA/LOCALAPPDATA, disabled API configuration and explicit synthetic responses. The runner uses the existing documented direct pinned-engine fallback to avoid the development wrapper regenerating shared build identity. No live service was contacted.

The fixture delays metadata and standings requests by 200 ms each. In the desktop Compatibility comparison, clearing both Daily RAM caches made the original page wait **410.447 ms** for its content; the final saved page displayed in **27.986 ms**. Final desktop Mobile displayed the same saved page in **42.731 ms**. These are individual local samples, not phone measurements or a general cold-load speedup. Full first-use script/resource loading and uncached network/server preparation remain. The separate fresh-process restore displayed cached content with all network replies held in **577.594 ms**, including first-use feature loading.

| Actual check | Result |
| --- | --- |
| New Daily page regression, headless | 31 checks, 0 failures |
| New regression, desktop Compatibility | 33 checks, 0 failures; clean exit |
| New regression, desktop Mobile/Vulkan | 33 checks, 0 failures; clean exit |
| Original controller/card/page control, desktop Compatibility | 25 checks, 5 expected failures: duplicate activation, unnecessary fresh read, missing restart presentation, serialized metadata read, restarted stale refresh |
| Separate-process seed and restore | 3/0 and 4/0 assertions; restore retains teardown diagnostic below |
| Existing standings entry/cache/identity/verification | 14/0 |
| Existing preparation retries/cancellation | 5/0 |
| Existing standings refinement | 20/0 |
| Actual Daily event installation | 7/0; original ten laps, fresh limits, exact prepared track, untouched start clock |
| Production script parser | 571 scripts, 0 failures |
| Scoped Python Ruff | Passed after correcting two initial style findings |
| Scoped source whitespace / Git checkpoint | Passed; exact normalized forward/reverse |

The full existing medal-page test has **115 checks / 2 failures**, in View all population and country flags. The same two assertions fail with all three task-start Daily sources restored through a private controller; no assertion was changed. This task does not qualify that broader suite. Fresh-process restore checks pass but both retained native runs report **two ObjectDB instances / one resource at shutdown**, and the runner correctly treats that diagnostic as a failure despite native exit 0. The longer final native regression runs exit cleanly; no production teardown fix is claimed. Initial probe measurements and superseded runs are retained in the evidence directory.

Native views: [ready page](evidence/daily-page-loading-2026-11-14/final-compatibility/cold-ready.png), [restored page](evidence/daily-page-loading-2026-11-14/final-compatibility/disk-ready.png), [fresh-process page before network completion](evidence/daily-page-loading-2026-11-14/restart2-restored/process-restart-before-network.png), [Mobile restoration](evidence/daily-page-loading-2026-11-14/final-mobile/disk-ready.png). These retain the existing layout, route, medals, timer and race action.

## Actual commands

```powershell
python scripts/run_daily_page_loading.py final-headless res://tests/test_daily_page_loading.gd
python scripts/run_daily_page_loading.py final-compatibility res://tests/test_daily_page_loading.gd --renderer gl_compatibility
python scripts/run_daily_page_loading.py final-mobile res://tests/test_daily_page_loading.gd --renderer mobile
python scripts/run_daily_page_loading.py loading-control-final res://tests/test_daily_page_loading.gd --control --renderer gl_compatibility
python scripts/run_daily_page_loading.py restart2-seed res://tests/test_daily_page_loading.gd --renderer gl_compatibility --profile process-restart2 --phase seed
python scripts/run_daily_page_loading.py restart2-restored res://tests/test_daily_page_loading.gd --renderer gl_compatibility --profile process-restart2 --phase restore
python scripts/run_daily_page_loading.py card-entry-final res://tests/test_daily_standings_entry.gd
python scripts/run_daily_page_loading.py preparing res://tests/test_daily_standings_preparing.gd
python scripts/run_daily_page_loading.py standings-refinement res://tests/test_daily_standings_refinement.gd
python scripts/run_daily_page_loading.py event-install res://tests/test_daily_event_install.gd
python scripts/run_daily_page_loading.py medal-app res://tests/test_daily_medal_page.gd
python scripts/run_daily_page_loading.py medal-original res://../build/daily-page-loading-20261114/control_medal.gd
python scripts/run_daily_page_loading.py final-production-parse res://tests/check_model_refinement_parse.gd
.tools/backend-secure-venv/Scripts/python.exe -m ruff check scripts/run_daily_page_loading.py
python docs/evidence/daily-page-loading-2026-11-14/checkpoint.py
git diff --check -- game/core/features/daily.gd game/ui/track_of_day_page.gd game/ui/daily_result_card.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The runner retains exact commands, exit codes and diagnostics in per-label receipts/logs under `docs/evidence/daily-page-loading-2026-11-14/`. Source hashes and normalization details are in [checkpoint.json](evidence/daily-page-loading-2026-11-14/checkpoint.json).

Reload the client for the new scripts. Physical-device/network behavior and owner acceptance remain unverified. A first visit without a matching saved snapshot still waits for metadata and standings; service-side `PREPARING` responses retain their supplied Retry-After and bounded retry policy. No device query/test, export/APK, backend request/deployment, owner-save/process change, main-index staging or commit was performed. Standard build retention completed: 28.33 → 28.33 GiB, zero eligible entries; recent/protected/locked output keeps the existing tree above its 20 GiB target. No new task pin was created.
