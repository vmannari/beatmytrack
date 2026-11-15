# Track of the Day frame hitches — 15 November 2026

Daily browsing was synchronously initializing optional race construction code and, later, Garage picture code. Both now remain lazy on a cold Daily page. Subsequent visits can still prepare the selected track when the required code is already resident. An explicit race or Garage entry retains its existing loading and validation paths.

## Requirements and implementation

- **DST01 — keep cold race construction out of Daily presentation.** `game/core/features/daily.gd` checks that the selected-track controller, CPU worker and native construction scripts are already cached before dispatching speculative preparation. Checking the full set matters: the worker and construction script each caused a later main-thread import after the first controller import. The existing settle interval, single worker, event/source identity, account, car, expiry, cancellation and coalescing rules remain in use when warm.
- **DST02 — keep the first race handoff lightweight.** `game/race/selected_event.gd::track_for` retains the exact prepared selection or creates the existing metadata-only track. `game/core/app.gd::_selected_event_track` uses this small boundary directly, without loading the background controller before opening the race loading cover. The old controller helper delegates to the same function. The race still rechecks today's metadata and obtains fresh Daily limits before installation.
- **DST03 — avoid unused Garage imports during Daily idle.** `game/ui/garage_preloader.gd::_picture_script_ready` leaves a cold picture script unloaded on Daily without explicit demand. Already initialized pictures remain usable, and an explicit Garage request can initialize through the existing picture service. Other menu screens keep their prior preload behavior.

This is five small runtime edits. The existing Daily presentation cache, page/card artwork and layout, handling, race rules, server contracts and vehicle/environment models were not authored by this task. The source-only checkpoint also includes the offline runner, frame profiler, regression and two UIDs. Its ten files apply and reverse exactly after LF normalization, without using the shared Git index. Task-start snapshots preserve earlier changes already in these files; concurrent car, Garage and documentation work remains in the workspace.

## What the measurements show

The actual App/page was profiled with pinned Godot `4.7.2.stable.official.ed1daf0bf`, Dummy audio, private APPDATA/LOCALAPPDATA and disabled backend configuration. Synthetic metadata and standings replies each wait 200 ms; track hydration uses a local fixture document. No service was contacted. Instrumented copies are disposable files under `build/daily-page-stutter-20261115`; production has no timing instrumentation.

The first baseline recorded **1,577.820 ms** inside `_prepare_selected_event`, called synchronously from `_show_track`; the corresponding frame was **1,702.932 ms**. Later polling stalled for **120.232 ms** and **799.645 ms**. More detailed captures attribute these stalls to first-use selected-track/controller, worker and native construction imports. Completed worker publication also initialized the Free Race catalogue, adding a later 40–57 ms frame in the repeated-activation window.

Deferring cold race speculation alone left a **369–455 ms** first-visit hitch. An isolation run disabling the optional Garage preloader removed that large idle hitch. Deferring its cold picture import on Daily removed it in the final normal-App captures too. Shorter first-visit work still remains, including preparation of the offscreen Create menu and initial content presentation; it has not been fully attributed or eliminated.

| Desktop Compatibility capture | Maximum frame during five seconds after opening | Frames over 30 ms |
| --- | ---: | ---: |
| Original callback, comparison 1 | 1,942.682 ms | 5 |
| Original callback, comparison 2 | 2,071.950 ms | 5 |
| Race deferral only, comparison 1 | 454.735 ms | 3 |
| Race deferral only, comparison 2 | 454.821 ms | 3 |
| Both fixes, final 1 | 113.968 ms | 2 |
| Both fixes, final 2 | 127.506 ms | 2 |

The final two Compatibility runs have no frames over 30 ms in their three subsequent activation windows or explicit standings-refresh window. Their maximum frames in those windows are approximately 8.5–10.9 ms. The synchronous activation call itself is timed separately in each log. The five-second window starts after synchronous `_show_screen`; that entry call is also logged separately. These are local frame samples with instrumentation and existing shader/import caches, not a whole-app/device FPS or general network-latency benchmark. Concurrent model/environment activity was not frozen across all captures, so no whole-project controlled percentage is claimed.

The before/final ready-page PNGs are **byte-exact**: SHA-256 `361ee9dfc6a63a0ca3a41e58f7705f2ded2ef224aac6378f129ff05514196f95`. [Original view](evidence/daily-page-stutter-2026-11-15/paired-before-1/ready.png) and [final view](evidence/daily-page-stutter-2026-11-15/final-profile-2/ready.png) retain the route, timer, labels, medals and actions. Raw spans, frame summaries, commands, diagnostics and comparison receipts are under [the evidence directory](evidence/daily-page-stutter-2026-11-15/summary.json).

## Actual checks

| Check | Outcome |
| --- | --- |
| New cold-page/first-tap/warm-worker/Garage-demand regression | 27 checks, 0 failures each: headless, Compatibility, desktop Mobile/Vulkan |
| Earlier regression before adding Garage checks | 24/0 each renderer |
| Original Daily callback control | 24 checks, 8 expected failures; final lightweight handoff is retained in this control, so this is not an all-source baseline |
| Existing Daily saved-page/cache/request/identity regression | 31/0 headless |
| Existing standings entry and preparing/cancellation checks | 14/0 and 5/0 headless |
| Actual native Daily installation | 7/0 Compatibility, original ten laps and untouched start clock |
| Native metadata-only Daily start and catalogue publication | 6/0 Compatibility; retained two-ObjectDB-instance shutdown warning |
| Existing native Garage preload/entry/interruption regression | 442/0 Compatibility, clean exit |
| Final production parser | 574 scripts, 0 failures |
| Scoped Ruff and source whitespace | Passed after correcting three initial Python style findings |
| Ten-source checkpoint | Exact normalized forward/reverse |

The first focused regression incorrectly treated a missing `metadata_only` key on a hydrated track as `true`. Inspection confirmed successful hydration; the fixture now uses the production default `false`. The failed runs are retained, and no existing assertion was weakened. A screenshot-analysis attempt used a Python environment without Pillow; comparison instead uses exact PNG bytes and SHA-256, requiring no dependency installation.

Some short profiling runs, including the final desktop Mobile profile, report **two ObjectDB instances/one resource at shutdown**. The runner flags resource errors even when Godot exits 0. Thus the final Mobile frame sample is retained with a failed shutdown receipt, not counted as a clean profiling pass. The longer functional Mobile regression passes 27/0 and exits cleanly; no teardown fix is claimed. No full-project regression or phone qualification is claimed.

## Commands and remaining acceptance

The runner accepts a label, optional script, `--renderer headless|gl_compatibility|mobile`, `--control` and the diagnostic-only `--no-garage`. Every invocation retains its exact engine command, exit status and diagnostics. Actual commands included:

```powershell
python scripts/run_daily_page_stutter.py baseline-compatibility
python scripts/run_daily_page_stutter.py original-callback-control res://tests/test_daily_page_stutter.gd --renderer headless --control
python scripts/run_daily_page_stutter.py paired-before-1 --control
python scripts/run_daily_page_stutter.py paired-after-1
python scripts/run_daily_page_stutter.py paired-before-2 --control
python scripts/run_daily_page_stutter.py paired-after-2
python scripts/run_daily_page_stutter.py isolate-garage --no-garage
python scripts/run_daily_page_stutter.py final-garage-profile
python scripts/run_daily_page_stutter.py final-profile-2
python scripts/run_daily_page_stutter.py final-profile-mobile --renderer mobile
python scripts/run_daily_page_stutter.py final-headless res://tests/test_daily_page_stutter.gd --renderer headless
python scripts/run_daily_page_stutter.py final-compatibility res://tests/test_daily_page_stutter.gd
python scripts/run_daily_page_stutter.py final-mobile res://tests/test_daily_page_stutter.gd --renderer mobile
python scripts/run_daily_page_stutter.py retained-page res://tests/test_daily_page_loading.gd --renderer headless
python scripts/run_daily_page_stutter.py retained-entry res://tests/test_daily_standings_entry.gd --renderer headless
python scripts/run_daily_page_stutter.py retained-preparing res://tests/test_daily_standings_preparing.gd --renderer headless
python scripts/run_daily_page_stutter.py actual-event-install res://tests/test_daily_event_install.gd
python scripts/run_daily_page_stutter.py actual-metadata-start res://tests/test_daily_metadata_catalog.gd
python scripts/run_daily_page_stutter.py retained-garage-preload res://tests/test_garage_preload.gd
python scripts/run_daily_page_stutter.py final-production-parse res://tests/check_model_refinement_parse.gd --renderer headless
python docs/evidence/daily-page-stutter-2026-11-15/analyze.py
python docs/evidence/daily-page-stutter-2026-11-15/checkpoint.py
.tools/backend-secure-venv/Scripts/python.exe -m ruff check scripts/run_daily_page_stutter.py docs/evidence/daily-page-stutter-2026-11-15/checkpoint.py docs/evidence/daily-page-stutter-2026-11-15/analyze.py
git diff --check -- game/core/app.gd game/core/features/daily.gd game/core/features/selected_track.gd game/race/selected_event.gd game/ui/garage_preloader.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Reload the client to use the updated scripts. Cold race initialization now occurs when starting the race rather than being paid during Daily browsing; its time has not been removed. Smaller first-visit frame spikes, real server/network behavior and owner/device acceptance remain. No phone/device test or attachment query, export, live backend operation, deployment, owner-save/process action, shared-index staging or commit was performed. All ten owned source hashes match the final checkpoint. The shared index changed concurrently between read-only observations and was preserved. Standard build retention removed one eligible entry, reducing build output from 31.57 to 31.35 GiB; recent/protected/locked output remains above target. No task pin was created.
