# Rivalry card refinement, 2026-10-24

The owner accepted the podium backgrounds and requested equal card heights, a better name section and slightly smaller points. This replaces the earlier raised/taller winner requirement. Gold coloring and its existing border still emphasize first place.

| Requirement | Change |
| --- | --- |
| RCF01: equal cards | All three cards are 194 logical units high, with matching top/bottom, car and footer baselines. |
| RCF02: name section | A 56-unit full-width footer has square top corners, a quiet divider, 10-unit side padding and 7-unit vertical padding. Flags increase from 24 to 28 units and share the name's vertical center. Names retain the condensed 20-unit type, independent profile binding and safe ellipsis for long names. |
| RCF03: smaller points | Points decrease from 26 to 22 while explicitly retaining the condensed display font; PTS decreases from 12 to 11. A 30-unit reserved score column replaces 36, and the stack has a two-unit overlap instead of four. The reference names fit beside their scores. |

The only runtime change is `game/ui/weekly_rivalry_page.gd`. The accepted `rivalry_podium_backdrop.gd` and shader are byte-for-byte unchanged, checked against task-start copies. Actual native cars, paint/cosmetics/contact shadows, frame fitting, live-score updates, standings space, track selection-only highlighting and six-unit right padding remain.

`test_rivalry_view_polish.gd`, `test_rivalry_custom_cars.gd` and `test_weekly_rivalry.gd` now assert equal heights in place of the superseded raised-winner requirement. Existing car, footer alignment, score wrapping, stage lighting, input, score refresh, track selection and clipping checks remain. New checks cover footer spacing, full-width divider, flag/name alignment, full reference-name fit and smaller condensed points. No failing assertion was removed to obtain a pass.

The exact commands, durations, test outcomes, source/background hashes, task-only checkpoint and native before/after at 960x540, 1280x720 and 1600x720 are in `docs/evidence/rivalry-card-refinement-2026-10-24/`. Runs use the pinned Godot through `scripts/dev.ps1` with isolated workspace user data. Mobile captures use desktop Vulkan.

Client page reload and owner appearance acceptance remain. No phone/tablet attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart was performed. Concurrent work is preserved. The older unrelated track-detail count failure remains documented in the preceding task and was not changed here.

Final checks: 250 headless, 264 Compatibility and 264 desktop Mobile focused checks pass; full Weekly Rivalry interaction1145, native cars199 and parser1108 pass. Both approved background source hashes are unchanged.
