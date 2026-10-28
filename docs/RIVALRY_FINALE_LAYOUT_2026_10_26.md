# Rivalry final standings layout, 2026-10-26

RFL01: The completed-week page fits its actual menu clipping boundary. A fixed body replaces the scroll container around both result columns. All five track results, highlights and bottom actions remain visible. Hero sizing uses the clipping ancestors so resizing from a tall window back to landscape releases the previous minimum height.

RFL02: Only Final standings can scroll. It includes every actual competitor instead of a selected five-row sample, highlights the player and initially reveals their row. Native scrolling retains access to the full field. The five track-detail actions and authoritative standings, scoring and Continue/Share guards remain.

RFL03: The car, crown, title and summary cards occupy separate bounds below the section navigation. The car preview fits the actual mesh bounds in its orthographic viewport, including the taller Forklift. The existing perspective preview fit retains its calculation. The Perfect Week badge includes the actual two-line font height in its minimum.

RFL04: Remove the redundant points-ahead/completion hero context. Actual errors remain visible, including in-place status refreshes; clearing an error hides the label again. Circuit finales use compact ranking copy and card spacing, with the decorative subtitle omitted to fit their additional progress header.

Runtime files:

- `game/ui/weekly_rivalry_finale.gd`
- `game/ui/weekly_rivalry_page.gd` (status refresh only; prior unrelated edits retained)
- `game/ui/rivalry_victory_car.gd` (optional orthographic fitting)
- `game/ui/world_ranking_week_summary.gd` (optional compact formatting; existing translations retained)

R01: Updated `game/tests/test_rivalry_awards.gd` for the requested fixed body and complete scrolling standings. Added `game/tests/test_rivalry_finale_layout.gd` for the production menu hierarchy, five window sizes including a matched screenshot aspect, tall-to-short resizing, all track rows, list reachability, header bounds, ranking summaries, four locales and in-place errors. Existing card bounds, actions, decoration, car fitting, snapshot immutability and sharing checks remain. The old five-row sample requirement is superseded by the owner's request for list-local scrolling.

Final layout checks pass 1477/1477 in Compatibility and 1477/1477 in desktop Mobile. Awards pass 5384/5384 in desktop Mobile; the preceding Compatibility awards run also passes 5384/5384. App passes 141/141 and the final parser passes all 1219 scripts.

The retained broader ranking/newspaper suite reports 45 checks / one failure: its separate World Ranking page does not expose two rows at 960x540. `probe_rivalry_finale_retained_baseline.gd` reloads all four task-start UI scripts only into an isolated process, reproducing the identical failure (49 checks including four source reload assertions). No original runtime file is restored on disk, and no failing assertion is relaxed. This unrelated compact World Ranking page remains outside this final-standings task.

The exact task-start finale/page/awards sources and native before views are retained in `docs/evidence/rivalry-finale-layout-2026-10-26/before/`. The expanded native regression against the original runtime reports 5312 checks / 277 failures. Initial layout and renderer attempts, resize/badge/preview failures and ranking-layout iterations are retained rather than overwritten. Sandbox attempts failed on user-log access and then Windows certificate-store access; approved native execution used disposable workspace save data.

Actual commands and final outcomes are in [report.json](evidence/rivalry-finale-layout-2026-10-26/report.json). All commands use the pinned Godot 4.7.2 build through `scripts/dev.ps1`, with process-only execution-policy bypass and `APPDATA=build/rivalry-finale-layout/userdata`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_ranking_newspaper.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_rivalry_finale_retained_baseline.gd
```

Q01: Matched native previews are under `layout/` and `after/ui/`, with desktop Mobile in their `mobile/` subdirectories. The report records final counts, source hashes and the task-only review patch. Existing concurrent model, handling, translation and Garage work is preserved. Native evidence was visually inspected for the champion, unranked/player-at-bottom and Circuit-ranking cases.

Reload the client to use these source changes. Owner appearance and physical touch/device acceptance remain. No device attachment check or physical-device test, Android export/install, live mutation, deployment or owner-process restart was performed.
