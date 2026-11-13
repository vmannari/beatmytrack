# Completed Rivalry uses the normal weekly view, 2026-10-26

The owner rejects the separate finale composition and requires continuity with the normal weekly screen. RWC01-RWC04 supersede the preceding finale layouts.

RWC01: Completed weeks now call the same `_championship` builder as active weeks. The existing podium remains above standings on the left; the existing numbered track rows remain on the right. Header size, column proportions, podium cards, player/profile links, surfaces and menu anchors are shared. There is no mounted `WeeklyRivalryFinale`, floating hero car, separate score strip or relocated highlights panel.

RWC02: The existing position badge shows the earned championship/Perfect Week/completion state. The existing track-status area shows final points, and the heading counts actual contested wins. Missing player results remain an em dash rather than borrowing the leader's time. Completed-week hints use existing highlights and hide playable next-target prompts; no redundant points-ahead header label returns.

RWC03: Share and Continue sit beneath the five tracks inside the normal track card. Their existing signals, busy/error gates, exact payload and scoped rollover logic remain. Circuit ranking facts occupy the existing contextual area above the rows, with a small typography adjustment for completed Circuit rows. Failed Continue uses the normal status slot without replacing the view or losing the list.

RWC04: The main page remains fixed. Only the existing standings list scrolls, retaining all entrants and initial player reveal. Native tests compare active and completed component bounds within one logical unit, check every visible row value and both actions against the actual clipping boundary, and exercise multiple achievement states, sizes and languages. Finished-card spacing reserves space for its footer while retaining the normal row components.

Runtime changes are confined to `game/ui/weekly_rivalry_page.gd`. The historical standalone finale source remains unmounted and unchanged. Existing input/vehicle/simulation/configuration and share-dialog sources are untouched; concurrent work is preserved.

Tests retain scoring/share/cosmetic/busy/rollover invariants. The prior standalone-hero, rearranged columns and large-badge layout assertions are superseded by the owner's correction and replaced with direct active/completed continuity checks. `test_weekly_rivalry.gd` and `test_ranking_newspaper.gd` now assert the shared weekly view and contextual ranking location. Initial visible-row overflows and a spacing edit caught in the loading builder are retained in the diagnostic logs; no visible-row bound is loosened. Hidden next-target controls are excluded from visible-label bounds checks.

Actual commands, final counts, source/image hashes and the task-only patch are recorded in [report.json](evidence/rivalry-weekly-continuity-2026-10-26/report.json). Task-start sources, matched active/completed views and diagnostic logs are retained beside it. Pinned Godot 4.7.2 uses disposable workspace saves under `build/rivalry-weekly-continuity/userdata` and no online service.

Final actual-App continuity checks pass 3052 in Compatibility and 3052 in desktop Mobile. Awards pass 2312 native checks, including all six achievement states, actual detail/return, exact scoped clipboard payload, unchanged cosmetics and seven podium car previews. Rollover/Continue passes 38, and the parser passes all 1236 scripts. The original page reloaded against the new shared-view requirements reports 147 checks / 72 failures; the required weekly podium is absent in its completed state.

The retained headless Share suite reports 338 checks / 13 geometry failures in its separate dialog. Reloading the task-start page only in isolated memory gives 339 checks (one reload assertion) with exactly the same 13 failure descriptions and multiplicities. No dialog source or failing assertion is changed. Actual Share-action binding, exact payload and account/car scoping checks remain; no Share-dialog layout pass is claimed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_week_completion.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_share.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_share.gd -TestArgument '--weekly-before'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_finale_layout.gd -Graphical -TestArgument '--weekly-before'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

The before mode reloads the task-start page only in an isolated process. It never restores runtime source on disk. The missing Forklift news image and separate compact World Ranking-page failure recorded in the preceding tasks are outside this runtime change.

Reload and owner appearance/touch acceptance remain. No device attachment check or physical-device test, APK/build/install, real authentication/purchase, live mutation, deployment or owner-process restart was performed.
