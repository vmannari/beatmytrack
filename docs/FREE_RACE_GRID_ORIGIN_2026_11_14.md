# Free Race tracks start at the beginning (2026-11-14)

The owner's screenshot shows empty cells before the first track. The browser carried a partial-row column offset across same-generation catalogue updates and back to scroll zero. That offset is useful while keeping a scrolled card stationary, but creates unwanted leading space at the beginning.

## Requirements and changes

- FRO01: At scroll zero, actual tracks begin in the top-left cell. Reset accumulated presentation offsets when returning to the beginning; ordinary catalogue updates there retain scroll zero.
- FRO02: Preserve deep-scroll row/column anchoring and bounded previous-page loading. Track the discovery window's coordinate rebase separately so restoring an earlier cursor page still anchors the current cards and fills only the needed reserve.
- FRO03: Check native layout, updates, eviction, resizing and existing interaction coverage. Extend the current discovery-window suite without removing existing assertions.

Runtime changes are confined to [track_browser.gd](../game/ui/track_browser.gd). Regression changes are in [test_discovery_windows.gd](../game/tests/test_discovery_windows.gd). This report and the AGENTS/status/plan entries record the work. The dev wrapper also refreshes generated build identity metadata; its generated output is outside the source checkpoint.

## Verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All commands run from the repository root through `scripts/dev.ps1`.

```powershell
$env:BMT_DISCOVERY_EVIDENCE_DIR = (Resolve-Path docs/evidence/free-race-origin-2026-11-14).Path
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_list.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../build/free-race-origin-2026-11-14/app-gl'
```

| Run | Actual outcome |
| --- | --- |
| Original runtime with new origin regression | Rejected at the first empty-slot assertion after the first track was removed. The dev wrapper stops on the first engine error; no completed baseline-suite count is claimed. |
| Initial correction, additional backward-reserve control | Origin checks passed, but the additional check rejected excessive backward fetching. Retained as a rejected intermediate control. |
| Final discovery suite, headless | 347 checks, 0 failures; backward reserve used one read and stopped. |
| Final discovery suite, Compatibility | 355 checks, 0 failures; backward reserve used one read and stopped. |
| Final discovery suite, desktop Mobile/Vulkan | 355 checks, 0 failures; backward reserve used one read and stopped. |
| Existing actual-App Free Race interaction suite, Compatibility | Incomplete and failed: two score-panel padding assertions, a missing-score-actions assertion, then a null lookup at `test_free_race_list.gd:112`. Its initial list, input and detail captures were produced; no full interaction-suite pass or baseline attribution is claimed. |

The discovery suite includes all existing bounded 5,000-track cursor traversal and exact deep card row/column checks. New checks cover removal/restoration of the first card in the same generation, returning to the beginning after eviction, 2408×1137 / 1280×720 / 960×540 logical layouts, and a stationary backward reserve. Fixtures supply all track metadata and documents; these are desktop checks with no live service requests.

Native evidence: [first-card update](evidence/free-race-origin-2026-11-14/gl_compatibility-origin-first-removed.png), [return after eviction](evidence/free-race-origin-2026-11-14/gl_compatibility-origin-after-eviction.png), and [actual-App list](evidence/free-race-origin-2026-11-14/app-list-1280x720.png). Both desktop renderers retain captures in the [evidence folder](evidence/free-race-origin-2026-11-14/). The actual-App image uses the existing 27-track fixture.

## Checkpoint and limits

The [two-source patch](evidence/free-race-origin-2026-11-14/source.patch) applies to the task-start files and reverses exactly. Both forward and reverse SHA-256 comparisons are [recorded](evidence/free-race-origin-2026-11-14/checkpoint.json). No main-index staging or commit was performed; concurrent work was preserved.

The broader score-panel test findings remain open. No whole-project pass, physical-device test, export, backend operation or deployment is claimed. Owner reload and appearance acceptance remain. Desktop Mobile captures use Vulkan on the desktop GPU.

Closeout ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply`: one eligible entry was removed; reported build usage remained 25.12 GiB, with recent/protected/locked entries above the target. The [cleanup output](evidence/free-race-origin-2026-11-14/retention.log) is retained. Disposable test data and the two-file checkpoint remain under `build/`; permanent evidence contains concise logs, the source patch and relevant screenshots.
