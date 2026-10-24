# Immediate creator biome selection — 2026-10-23

Selecting a biome now updates the existing cards and summary synchronously. Previously every tap called `_show_screen("biome")`, destroying the menu shell and scheduling reconstruction of the neighboring pages. The selection handler now updates only the previous and new card, the summary icon/title/description, and the cached page's selected biome. Create reads that current selection instead of a value captured when the button was constructed.

| Requirement | Result |
| --- | --- |
| BSL01 | Selection retains the shell, body, cards, summary, keyboard focus and prepared swipe pages. |
| BSL02 | Rapid selections and the retained Create button use the latest biome; entering the editor still fixes the biome. |
| BSL03 | Cached-page return and New track update the existing picker, including resetting a fresh draft to Grass. Same/invalid choices do no navigation. |
| R01 | Existing original artwork, layout, colours and copy are preserved. The initial, Winter and Storm Compatibility captures match the original PNGs exactly. |
| Q01 | Actual App regression, viewport touch, all-biome workflow, script parsing and original-code failure controls are recorded below. |

Production changes are confined to `game/core/app.gd`. `game/tests/test_biome_selection_latency.gd` and its UID add the regression. This document, the three project status notes and [the evidence report](evidence/biome-selection-2026-10-23/report.json) record the delivery. Concurrent challenge, editor, gameplay and audio changes are preserved.

The five measured selections use the real card's pressed signal. These are local desktop CPU callback timings, with startup complete and neighboring pages prepared; they exclude hardware input and presentation latency. The original and final runs are separate processes on the same desktop, not a phone benchmark.

| Mode | Original median / maximum | Final median / maximum |
| --- | --- | --- |
| Headless | 4.525 / 13.476 ms | 0.146 / 0.248 ms |
| Desktop Compatibility | 15.375 / 18.417 ms | 0.149 / 0.183 ms |
| Desktop Mobile renderer | Not measured | 0.121 / 0.191 ms |

The final focused regression passes **82 checks in each of headless, Compatibility and desktop Mobile**, with clean final exits. It checks all five biomes, retained control identity/focus/swipe pages, exact label states, untouched track geometry/history, same/invalid choices, rapid changes, real viewport touches, Garage return, new-draft reset, latest-choice creation and completed editor preparation. Existing `test_biomes.gd` passes **108 checks** headlessly; project parsing passes **987 scripts**. Original focused runs fail 34 of their 79 checks, demonstrating the page reconstruction.

Two broader tests remain limited by failures reproduced against the captured task-original App: `test_menu_quality.gd` accesses a missing hero title at line 33; `test_menu_page_swipe.gd` fails three live-slide checks and then calls `pause` on null at line 324. Both stop before biome selection. Their assertions were retained. The original-code probe sources and logs are saved in the evidence directory; temporary executable probes were removed.

After the successful focused runs and 108-check biome run, two additional biome-workflow receipt runs stopped before `APP_READY` with `Can't get_pixel() on compressed image`, in both headless and Compatibility. The existing static Desert artwork sampler reads pixels without decompressing its image (`native_track_visual.gd:38`). Shared texture import/export work was active at that time; this task made no texture/import or sampler changes. These later interruptions are retained separately from the earlier passing runs.

Initial test launches needed the process execution-policy option and access to Windows runtime resources outside the sandbox; all successful runs used isolated workspace AppData. The evidence output path was corrected to an absolute path. Earlier graphical runs passed their 79 assertions but reported an 87,380-byte GL texture at immediate editor teardown, including on the original App. The final harness waits for the selected editor to finish preparing and lets the menu decoder retire before quitting. Final graphical runs exit cleanly; production audio and rendering were not changed for this task.

Actual commands use the pinned `4.7.2.stable.official.ed1daf0bf` engine through `scripts/dev.ps1`. Before each run, `APPDATA` points inside `build/biome-selection-2026-10-23/<run>/appdata`; the focused test disables its backend and uses a fresh local library/profile. Representative final commands, with the exact run variants and results in `report.json`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biome_selection_latency.gd -TestArgument '--out=res://../docs/evidence/biome-selection-2026-10-23/final-headless'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biome_selection_latency.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--out=res://../docs/evidence/biome-selection-2026-10-23/final-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biome_selection_latency.gd -Graphical -RenderingMethod mobile -TestArgument '--out=res://../docs/evidence/biome-selection-2026-10-23/final-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biomes.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_quality.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
git apply --reverse --check docs/evidence/biome-selection-2026-10-23/task-only.patch
```

Restart/reload the local client to use the change. Owner feel and physical-device input acceptance remain. No phone attachment check or device test, APK, live backend/account mutation, social send or deployment was performed.
