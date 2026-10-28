# Rivalry final standings composition, 2026-10-26

The owner rejects the preceding fixed-page layout as visually unsatisfactory. RFC01-RFC04 revise the composition while retaining the fixed page, list-local scrolling and removed points-ahead label.

- RFC01: One compact championship strip groups the title/laurels, a readable car preview and three score cells in a single shared frame. The redundant congratulatory subtitle is removed. The strip is bounded to 94–104 logical units, versus the preceding 129-unit championship header; the car receives the complete strip height instead of a shallow slot above the scores. Actual errors occupy the space beneath the score group without overlapping it.
- RFC02: Two equal-height result panels replace the track card plus stacked standings/highlights cards. Standings receive the complete right column, with at least eight fully visible rows in the ordinary tested finales. Every entrant remains reachable, and the player highlight and initial reveal remain.
- RFC03: Track results use shared aligned Time/Gap to 2nd/Points headings instead of repeating captions in all five rows. Values align right, borders are quieter, and all five original detail actions remain. A compact two-column highlights footer sits inside the track-results panel.
- RFC04: Perfect Week becomes an earned single-line crown badge in that footer. This supersedes the previous large two-line decorative badge. The actual five-outright-win condition and share text remain unchanged.

Runtime scope is `game/ui/weekly_rivalry_finale.gd`. `game/tests/test_rivalry_awards.gd` retains the award/scoring/sharing/car-fit/bounds checks and replaces the old badge arrangement assertions with strict inline-badge bounds and earned-state checks. `game/tests/test_rivalry_finale_layout.gd` adds panel alignment, eight visible rows, readable car height, compact header, shared headings, fixed thumbnail proportions and strict bottom-action/error clipping checks. Six window sizes include the owner's new 2023x871 aspect ratio, with tall-to-short resizing and four locale/Circuit variants. Tall-window review found stretched thumbnail scenery; fixed thumbnail heights preserve proportions while rows can expand vertically.

Task-start sources, initial drafts/failures, matched native screenshots, actual commands/results, source/image hashes and a task-only review patch are retained in [the evidence folder](evidence/rivalry-finale-composition-2026-10-26/). Final counts and commands are recorded in [report.json](evidence/rivalry-finale-composition-2026-10-26/report.json).

The final production-hierarchy layout passes 2241 checks in Compatibility and 2241 in desktop Mobile; the final parser passes all 1231 scripts. Awards pass 4088 checks in each renderer, including six achievement states, actual track-detail return, guarded sharing/Continue and seven car previews. The Compatibility awards run precedes the final fixed-thumbnail review; the final layout matrix in both renderers and the full Mobile awards run include that correction. The original finale reloaded against the final expanded layout assertions has 2928 checks / 466 failures headless; its matched earlier native regression has 2770 checks / 376 failures. Domain scoring/share assertions remain unchanged; the lower awards count versus the preceding task follows the removal of repeated row labels and subtitle, not a removed score/visibility guard.

The first draft passed its earlier screen-bounds checks but inspection found five logical units extending into the menu's clipping boundary. A stricter assertion catches this; compact footer spacing corrects it. The initial larger Perfect Week badge retained two units of overflow, corrected through its actual single-line font size. Those failures remain in the logs. Existing assertion bounds are retained; the superseded badge geometry is documented above.

Pinned Godot 4.7.2 commands use disposable workspace `APPDATA=build/rivalry-finale-composition/userdata` and no online service:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical -TestArgument '--composition-before'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
```

The before mode reloads only the captured task-start finale script into its isolated process and saves matched views; it never replaces the runtime file on disk. This directly checks the rejected composition against the revised layout requirements. The separate existing compact World Ranking page failure documented in the preceding layout task is outside this change.

The broader App command stops after `APP_READY` because `res://assets/news/vehicles/forklift.png` is absent. That image and all news assets are outside this change; no fixture, resource lookup or assertion is bypassed, and App is not reported as passing. Focused UI runs use the actual app hierarchy with isolated records and car fixtures.

Scoring, pinned tracks/configuration, car geometry, existing preview fitting, account/save authority, Share/Continue guards and section navigation are unchanged. Concurrent Garage, handling, model and localization work is preserved. No new art asset or external dependency is introduced.

Client reload and owner appearance/device acceptance remain. No device attachment check, physical-device test, Android build/install, real authentication/purchase, live mutation, deployment or owner-process restart was performed.
