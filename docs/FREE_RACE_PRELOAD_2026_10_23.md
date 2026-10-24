# Free Race preloading and loaded-end scrolling, 2026-10-23

The track list now preloads according to its visible rows and columns. While more tracks are pending, scrolling ends at the last loaded card. The selected-track carousel follows the same rule. Loaded cards remain usable if a later page fails.

| Requirement | Result |
| --- | --- |
| RFP01 | Pass the actual visible card range to discovery. Reserve two viewports ahead, bounded to 20?60 cards. Continue toward the latest viewport after each response, with one read in flight. |
| RFP02 | Build list/carousel extents from actual loaded cards. Compact omitted/unloaded cursor slots; render no per-track loading, retry or unavailable placeholders. |
| R01 | Preserve exact selected revisions, immutable document downloads, global search/Random, account/query fences, retry/backoff, bounded caches and telemetry positions. Keep retained card columns and screen rows stable through eviction. |
| G01 | Save native pending-end, loaded and carousel screenshots at 1720?900, 960?540, 390?844 and 844?390 for both discovery protocols and desktop renderers. |
| Q01 | Run focused and existing regressions, parse all project scripts, preserve concurrent work and provide a scoped Git-checkable patch. |

`game/ui/track_browser.gd` uses a compact list of actual catalogue entries for both views. Fetch coordinates remain attached to entries, so telemetry and subsequent cursor reads retain their meaning. A small leading alignment spacer can preserve a retained row's columns after eviction; it represents no track. The global catalogue is still fully browsable through sequential paging, Search and Random.

`game/backend/discovery_windows.gd` and `game/backend/discovery_pages.gd` accept viewport demand. Each successful response revisits that demand, including scroll movement during a pending read. The existing 13/15-page cache bounds remain; legacy pages in the current demand range are touched before prefetch eviction. Query generations, source scopes and the existing v3 failure/backoff controls remain in force. The optional one-index API remains available to other callers.

| Check | Actual result |
| --- | --- |
| `test_free_race_preload.gd`, headless | 228 checks, 0 failures |
| Same, Compatibility | 253 checks, 0 failures |
| Same, desktop Mobile/Vulkan | 253 checks, 0 failures |
| `test_discovery_windows.gd` | 106 checks, 0 failures |
| `test_discovery_pages.gd` | 269 checks, 0 failures |
| `test_free_race_list.gd` | 233 checks, 0 failures |
| `test_challenges.gd` | 216 checks, 0 failures |
| `test_app.gd` | 141 checks, 0 failures |
| `test_script_parse.gd` | 1015 scripts, 0 failures |

The focused fixture holds actual browser page requests while scrolling to the loaded end, then releases them and verifies that preloading fills the latest viewport's reserve without another scroll. It also checks stationary request bounds, sparse authority-filtered pages, failure/retry behavior and terminal search results in both protocols. Existing cursor regressions retain exact card/revision and row/column checks during eviction, backward cursor reads and late account/query replies. Existing paging tests still traverse all 5,000 fixture records.

Actual commands used the pinned Godot 4.7.2 build through `scripts/dev.ps1`. Tests isolated `APPDATA` under `build/free-race-preload-user`:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/free-race-preload-user'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/track_browser.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_preload.gd
# Repeat the focused script with each native renderer:
# -Graphical -RenderingMethod gl_compatibility
# -Graphical -RenderingMethod mobile
# Existing regressions used the same TestScript action with the script names above.
# Batch invocations and exact outcomes are recorded in report.json and logs/.
```

Initial direct PowerShell invocation was blocked by its execution policy; the process-only `-ExecutionPolicy Bypass` invocation worked. Godot's sandboxed fixture startup could not read the Windows certificate store, so native local tests ran with approved Windows access. User data remained isolated. An initial bare-window capture fixture used mismatched logical/display sizes; its content scale now matches each tested viewport.

The first existing Free Race run reported two failures: the former assertion expected scrolling through thousands of unloaded positions, and its manually cleared pages had not emitted the production cloud catalogue-change event. The updated test asserts loaded-only coordinates/control bounds and uses that actual event for failure/empty fixtures. The original 233-check failure log is retained. Historical evidence output was restored after copying this run's report into the task evidence folder.

Native examples: [pending tablet-sized end](evidence/free-race-preload-2026-10-23/captures/gl_compatibility-v3-1720x900-pending-end.png), [loaded buffer](evidence/free-race-preload-2026-10-23/captures/gl_compatibility-v3-960x540-loaded.png), [failed page](evidence/free-race-preload-2026-10-23/captures/mobile-v3-failed-page.png). All 50 screenshots and test logs are under [the evidence folder](evidence/free-race-preload-2026-10-23/).

These are desktop fixture/render checks, not tablet frame-rate or mobile network measurements. Owner acceptance on the tablet, including sustained flings, slow-network scrolling and returning from track details, remains. No phone/tablet attachment check, physical-device test, APK export/install, live backend/account mutation or deployment was performed.

`task.patch` contains only this task's runtime/test/documentation changes relative to the captured workspace sources. It is checked with `git apply --reverse --check`; the shared index and existing commits are unchanged. Concurrent work is preserved.
