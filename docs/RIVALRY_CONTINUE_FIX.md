# Rivalry results Continue blocker — 2026-10-09

Requirements: **WR08, R01, V03–V05, Q01**. The owner reports that Continue does nothing after a five-lap Rivalry race reaches the normal race summary.

Reproduced with the pinned engine and existing graphical result regression. `_results()` removes and frees the previous menu children, including `content`, but retains their references. `_show_screen("rivalry")` then passes the freed `content` to the typed `_remember_rivalry_standings(Control)` helper. Godot rejects the argument before the helper's internal validity guard can run, aborting navigation. The recorded error is `Invalid type in function '_remember_rivalry_standings' ... argument 1 (previously freed)` at `app.gd:291`.

`game/core/app.gd` now checks validity before passing that control and retires replaced menu references when constructing the race summary. It remembers standings scroll first, stops menu motion, clears prepared neighboring pages and releases `content`, `menu_body`, `menu_body_slot` and menu background references before deleting their controls. Background verification cannot revisit those removed pages. Continue retains the finished race for Race Again and opens the competition feedback immediately; Back to Rivalry releases the race and restores the overview and remembered scroll. Normal PB/lap results still appear first. No scoring, canonical simulation, rules, backend or presentation layout changes.

`game/tests/test_rivalry_results_continue.gd` reuses the existing result fixture/helpers with an isolated asynchronous authenticated-service fixture. It checks actual viewport mouse input at 1280×720 and touch input at 960×540, each with verified, queued and failed verification. It covers the warmed menu's replacement, real five-lap summary data, usable Continue, immediate result entry, completed-race retention, Back to Rivalry cleanup, all five overview tracks and remembered scrolling. These synthetic completion fixtures do not claim a newly driven or server-verified race. Eighteen native screenshots are retained under `docs/evidence/rivalry-continue-2026-10-09/ui/`.

All commands used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, **4.7.2.stable.official.ed1daf0bf**, and disposable workspace `APPDATA` directories under `build/rivalry-continue-2026-10-09/`. Native runs needed approved local certificate-store access; neither owner saves nor certificate settings were changed.

| Actual command suffix | Actual outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_rivalry_results_continue.gd -Graphical -CommandTimeoutSeconds 120` | **78 checks, zero failures**; all six native Continue/Back paths and 18 captures. |
| `TestScript -ScriptPath res://tests/test_rivalry_result.gd -Graphical -CommandTimeoutSeconds 120` | **105 checks, zero failures**; existing results presentation, standings and summary-first app flow. Before the fix, this command aborted on the freed-control error. |
| `TestApp` | **99 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_rivalry_feedback.gd` | **18 checks, zero failures**; provisional/verified scoring separation. |
| `TestScript -ScriptPath res://tests/test_rivalry_entry.gd` | **66 checks, zero failures**; populated first entry and account fences. |
| `TestScript -ScriptPath res://tests/test_race_mode_carousel.gd` | **42 checks, zero failures**, headless. |
| `TestScript -ScriptPath res://tests/test_challenges.gd -CommandTimeoutSeconds 90` | **84 checks, zero failures**, including adjacent result/navigation flows. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **396 scripts, zero failures**. |
| `TestScript -ScriptPath res://tests/test_race_results.gd` | Headless broad normal-results test reports **11 failed checks** (rating fade, viewport/touch and retired local recommendations), then aborts at the missing third recommendation. An isolated copy using the saved pre-fix app reports the **same 11 failures and same out-of-bounds abort**. These failures were not changed or hidden. Temporary comparison scripts were removed. |

Initial restricted execution could not read Windows root certificates. Early versions of the new fixture lost their board when unauthenticated refresh reset its scope, and one capture was obscured by the owned native window's focus-loss pause overlay. The fixture now models authenticated refresh and dismisses that unrelated pause overlay before emulating race completion; runtime behavior and assertions were not weakened. Failure logs and successful logs are retained.

Reviewed native [compact pending feedback](evidence/rivalry-continue-2026-10-09/ui/feedback-pending-960x540.png), [compact summary with failed verification](evidence/rivalry-continue-2026-10-09/ui/normal-failed-960x540.png) and [returned overview](evidence/rivalry-continue-2026-10-09/ui/overview-failed-1280x720.png). Layout fixtures never substitute live scores. Before-source copies and a task-only review patch preserve the source checkpoint and unrelated workspace changes.

Changed files: `game/core/app.gd`, the new regression, this report, `DEVELOPMENT_STATUS.md`, and `docs/PHASE_0_PLAN.md`, plus evidence. Remaining acceptance: restart the owner game and complete a live Rivalry race; confirm Continue, pending-to-verified feedback, Race Again and Back on the owner's desktop/device. No phone attachment check or physical-device test, Android export/install, live backend race, full Validate or deployment was performed.
