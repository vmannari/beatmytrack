# Subtle Rivalry podium heights, 2026-10-25

RPH01: First place has the highest top edge, second starts one logical unit lower, and third starts two units lower. Common card bottoms, car previews and name/score baselines remain aligned. This owner request supersedes the previous equal-height requirement.

The minimum card heights are 194/193/192. Rank-dependent minimum space above the cars also preserves the one-unit steps when the app's bundled font fallbacks require more height. In the actual app these cards measure 203/202/201; the podium grows two units versus the original 201-unit row, and standings retain 203 units. Card artwork, fonts, footer styling, native cars and interactions are retained. The backdrop script and shader match the task-start hashes exactly.

R01: Updated existing height assertions in `test_rivalry_view_polish.gd`, `test_rivalry_custom_cars.gd` and `test_weekly_rivalry.gd`. Final focused tests pass 381 checks in Compatibility and 381 in desktop Mobile across 960x540, 1280x720 and 1600x720. Car layout passes 141 headless checks. The parser passes 1176 scripts, including the temporary baseline diagnostic.

The actual-App suite has 1085 checks and three failures: its unchanged 194-unit compact-height limit already fails with the exact original page, which produces 201-unit cards. An isolated original-source run has 1086 checks and the same three failures. The new height-order assertion and standings-space assertion pass. No failing limit was weakened. The initial three-unit trial, superseded renders and sandbox certificate-store failure are retained in evidence; final one-unit steps limit added height to two units.

Q01: Native previews, actual-App before/after views, command records, task-start sources, hashes and a task-only Git-checked patch are in [the evidence folder](evidence/rivalry-podium-height-2026-10-25/). The runtime changes are confined to `weekly_rivalry_page.gd`; existing translations and concurrent track-thumbnail profiles in that file are preserved. Concurrent Garage and Forklift documentation is excluded from the task checkpoint.

Reload and owner appearance acceptance remain. No device attachment check or physical-device test, APK, live mutation, deployment or owner-process restart was performed.
