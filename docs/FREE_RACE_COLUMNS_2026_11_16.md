# Free Race uses the selected-track column count (2026-11-16)

FRC01: Keep the same number of tracks per row with and without a selected track, using the existing selected-track carousel as the baseline. FRC02: Preserve scrolling, selection, discovery window anchoring and responsive resizing.

Only `game/ui/track_browser.gd` changes at runtime. Both layouts use the existing 202px carousel stride through a shared constant. The list calculates its column count from the full viewport width before reserving the scrollbar, then fits those columns into the remaining content width. This avoids losing a column at scrollbar-dependent width thresholds. The selected-track carousel retains its previous sizing.

At 1280x720, both views show five complete tracks per row: [list](evidence/free-race-columns-2026-11-16/list-1280x720.png), [selected track](evidence/free-race-columns-2026-11-16/detail-1280x720.png).

Commands run from the repository root with pinned Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_list.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../build/free-race-columns-2026-11-16/gl_compatibility'
$env:BMT_DISCOVERY_EVIDENCE_DIR = 'C:\Codes\Godot\Beat my track\build\free-race-columns-2026-11-16\discovery'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd -Graphical -RenderingMethod gl_compatibility
git apply --check --reverse docs/evidence/free-race-columns-2026-11-16/source.patch
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The focused discovery suite passes **358 checks, zero failures**, including native captures, bounded catalogue traversal, row/column anchoring, updates at the top-left and resizing through 2408x1137, 1280x720 and 960x540. Backward reserve records two reads. Its [log](evidence/free-race-columns-2026-11-16/discovery.log) is retained.

The broader actual-App list suite captures the list and selected views at 960x540 and 1280x720, then fails on score-panel padding, missing score actions and a null lookup at `test_free_race_list.gd:112`. These are the same findings previously recorded in [the grid-origin task](FREE_RACE_GRID_ORIGIN_2026_11_14.md); this run does not qualify the full interaction suite. Its [log](evidence/free-race-columns-2026-11-16/app-list.log) is retained. No assertions were changed.

The [source checkpoint patch](evidence/free-race-columns-2026-11-16/source.patch) passes the reverse applicability check. The shared Git index and concurrent work are preserved. The development wrapper refreshes generated build identity metadata, excluded from this patch.

Owner appearance acceptance and reload remain. No physical-device test, export, backend operation or deployment was performed. Disposable captures and profiles stay under `build/` under the standard retention policy; only the relevant screenshot pair, logs and source patch are retained here.

Completion cleanup removed zero eligible entries and reported 22.98 GiB remaining; recent, protected or locked output keeps it above the 20 GiB target.
