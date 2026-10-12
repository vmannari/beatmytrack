# Compact Rivalry hub — 2026-10-09

Requirements: WR01–WR02, WR08–WR10, R01, V03–V05, Q01. The owner requests removing separate track arrows, always entering Rivalry on the overview, and increasing standings height by compacting the podium and removing its car pictures. This supersedes those parts of the preceding track-entry and podium references.

Every track is one full-width clickable row. Its former arrow button is removed; clicking the row still opens track detail and racing starts there. Explicit Rivalry entry, repeated trophy activation, primary menu navigation and committed horizontal page returns reset the section to the overview. Background refresh keeps an open detail or result in place. Entry from rivalry results releases the suspended race through the existing cleanup pattern. The populated-first-load wait, vertical Race transitions and account/request fences remain.

The gold winner remains slightly taller than the silver/bronze cards. Podium minimum heights change from 170/148 to 116/104 logical pixels; trophies and rank text are smaller. Car pictures and their empty spacer are removed, including the now-unused compact-art preload. Scenery and source assets remain. Loading placeholders and the unranked introduction use the same compact area. Standings retain their original rows, columns, scrollbar gutter, remembered scroll position and highlighted player. Native measurements show the winning card at **116 logical pixels** and the standings scroll viewport at **284 logical pixels** across the three tested resolutions, with seven complete standings rows visible. The five track rows remain immediately visible and both main panels still align at the bottom.

Runtime changes: `game/ui/weekly_rivalry_page.gd` and `game/core/app.gd`. Updated checks: `game/tests/test_weekly_rivalry.gd`. Documentation: this report, the current-guide note in `docs/RIVALRY_NAVIGATION.md`, `AGENTS.md`, status and phase plan. No canonical simulation, backend, scoring, ghost contract, rules, track data, asset file or gameplay camera change.

Actual commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`, and isolated `APPDATA=build/rivalry-hub-compact-2026-10-09/userdata`. Approved execution allows Godot's Windows certificate-store reads; existing player files and certificate configuration are untouched.

| Command | Actual result |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical` | Final **1,151 checks, zero failures**, at 1280×720, 960×540 and 1600×720. Covers all five full-width rows, absent arrows/art, compact podium and expanded standings measurements, detail/ghost/Race/back flow, repeated entry, primary-menu return, suspended-result cleanup, background refresh, completed/busy/unavailable gates and touch/clipping bounds. 21 native screenshots. |
| `TestScript -ScriptPath res://tests/test_race_mode_carousel.gd -Graphical` | **42 checks, zero failures**; vertical directions, fixed header/rail, refresh and interrupted transitions. No capture directory set for this run. |
| `TestScript -ScriptPath res://tests/test_rivalry_entry.gd` | **66 checks, zero failures**, headless; populated first load, refresh, automatic membership, account fencing, errors and canceled entry. |
| `TestApp` | **99 checks, zero failures**. |

Reviewed [desktop overview](evidence/rivalry-hub-compact-2026-10-09/ui/overview-1280x720.png) and [compact overview](evidence/rivalry-hub-compact-2026-10-09/ui/overview-960x540.png). These use isolated layout fixtures, never substituted live scores. Existing full detail/results/verification-pending/completed-week/forming-group captures are also retained by the same regression. No new player-facing explanation or diagnostic text is added.

The final native run paused its first capture while its window was minimized. Restoring only the verified test process's window resumed capture and completed all checks; existing owner/editor windows were untouched.

The task-only review patch, original source copies and verification record under `docs/evidence/rivalry-hub-compact-2026-10-09/` retain the checkpoint and preserve unrelated work. Remaining acceptance: owner visual/interaction approval and physical-phone touch/legibility/performance. No phone attachment check or device test, Android export/install, full Validate/replay regression, new backend HTTP test, staging or production action was performed.
