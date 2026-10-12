2026-10-09 follow-up: separate track arrows and podium car pictures are removed; explicit Rivalry entry always opens the overview and a compact podium gives the standings more height. See [current compact hub and verification](RIVALRY_HUB_COMPACT.md).

# Rivalry track entry — 2026-10-09

Requirements: WR01–WR02, WR07–WR10, TD09, R01, V03–V05, Q01. The owner's two supplied screenshots authorize using the overview as the championship hub and the existing track detail as the race entry point. This supersedes the separate Tracks/Standings sections and direct race starts from the overview.

Selecting any of the five overview rows, or its arrow, opens that track's scenic route, nearby positions, next rival, ghost choice and yellow Race action. Selection itself creates no race ticket. Back to Rivalry returns to the overview with the selected track remembered. Keyboard focus remembers a track without navigating until activation. The overview keeps its podium and scrollable standings, removes the section tab block and redundant Race action, and uses the available height for the five track rows. There is no remaining single Overview tab.

Completed-week rows also open track details, with racing disabled. An unavailable track remains inspectable; the detail Race action retains unavailable, busy and inactive-week gates, and now explicitly checks completed weeks. The completed-week Continue action remains on the overview. Loading placeholders match the hub without a Race footer. Removed obsolete Tracks/Standings builders and unused direct-race helpers. No backend, canonical simulation, rules, vehicle, camera, asset or schema change is required.

Changed files:

- `game/ui/weekly_rivalry_page.gd`: navigation, hub layout, back action and completed-week race gate.
- `game/tests/test_weekly_rivalry.gd`: all five row/arrow paths, keyboard focus, selected track/ghost race signal, remembered return, completed/unavailable/busy states and native layout evidence.
- `game/tests/test_weekly_rivalry_http.gd`: actual overview-to-detail-to-Race button flow, ticket separation, historical replay start setup and HTTP screenshots.
- `game/tests/test_test_driver_menu.gd` and `test_test_driver_live.gd`: capture the remaining overview/detail states. The former is run with the retained canonically verified 14-driver fixture; the live staging test is updated but not run.
- This report, `docs/WEEKLY_RIVALRY.md`, `AGENTS.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

All existing five-lap, best-only scoring, normal-results-first and public-population isolation contracts remain. Fictional scenery and car art are reused; the supplied references do not become shipping assets. Tests use isolated storage under `build/rivalry-navigation-2026-10-09/`, with no access to saved player sessions.

Actual verification uses pinned Godot `4.7.2.stable.official.ed1daf0bf`. The PowerShell commands below use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with `APPDATA` set to the isolated test folder. Execution-policy bypass is confined to the child process. Graphical/app/script-suite runs needed approved execution outside the sandbox for the Windows certificate-store read; no system certificate or trust configuration was changed.

| Command | Actual result |
| --- | --- |
| `CheckScript -ScriptPath res://ui/weekly_rivalry_page.gd` | Passed. |
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical` | Initial final navigation pass **1,226 checks, zero failures**; repeated after concurrent detail updates, **1,256 checks, zero failures**, at 1280×720, 960×540 and 1600×720. All five rows/arrows, focus, ghost choice, return, complete/busy/unavailable gates, touch bounds and standings clearance checked. 21 native screenshots. |
| `TestScript -ScriptPath res://tests/test_test_driver_menu.gd -Graphical` | **221 checks, zero failures**; six native screenshots of the retained verified field. Server development markers are preserved internally, without visible classifications. |
| `TestApp` | **99 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_rivalry_result.gd` | **10 checks, zero failures**; headless. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **388 scripts, zero failures**. Final subsequently edited test entrypoints compile and pass in their own runs. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_http.py::test_weekly_rivalry_through_native_app -q -s --basetemp=build/rivalry-navigation-2026-10-09/pytest-final` | **One passed**, native graphical **39 checks, zero failures**. Disposable SQLite/API/worker, actual button-issued ticket, **12,757 canonical ticks and five legal laps**, verified upload/PB/points, normal summary first, rivalry feedback, derived ghost bounds and sign-out fencing. Eight HTTP screenshots. One existing Starlette/httpx deprecation warning. `PYTHONPATH=backend`, isolated `APPDATA`, and `BMT_CAPTURE_CLOUD=docs/evidence/rivalry-navigation-2026-10-09/http`. |

Initial direct PowerShell invocation was blocked by the machine's script execution policy. Initial sandboxed Godot runs could not write the normal user log directory; isolated storage resolved that. Suite runs then encountered a denied Windows certificate-store read and were rerun with approved execution. A diff-display helper initially hit console encoding and was corrected to UTF-8.

The first graphical HTTP run reached the new button-issued ticket but failed the old replay's finish assertions and timed out. Unlike the former directly awaited helper, a real button-driven start allows countdown ticks before the test freezes the game. The game now observes countdown for launch timing, while this historical replay has no launch marker. The corrected test explicitly bypasses both countdown ticks and their launch-observer flags when injecting that historical replay, and checks that no canonical input has run before injection. The successful run logs `countdown_seen=true` before that reset and independently verifies all 12,757 recorded ticks through the server. No gameplay launch behavior or finish/scoring assertion was relaxed.

Reviewed evidence: [overview](evidence/rivalry-navigation-2026-10-09/ui/overview-1280x720.png), [compact overview](evidence/rivalry-navigation-2026-10-09/ui/overview-960x540.png), [track detail](evidence/rivalry-navigation-2026-10-09/ui/track-detail-1280x720.png), [compact detail](evidence/rivalry-navigation-2026-10-09/ui/track-detail-960x540.png), and [actual HTTP detail](evidence/rivalry-navigation-2026-10-09/http/track-detail-1280x720.png). Menu fixtures are isolated layout evidence, not live championship scores. The HTTP field is disposable and has one actual authenticated entrant, so its rank denominator is correctly one.

The task-only [review patch](evidence/rivalry-navigation-2026-10-09/scoped-source.patch), before-source copies and [verification record](evidence/rivalry-navigation-2026-10-09/verification.json) retain this checkpoint while preserving unrelated working-tree changes. Concurrent route-marker, full track standings, ghost-target, detail spacing and other menu changes remain intact and are excluded from this task's patch. The adjusted [checkpoint base](evidence/rivalry-navigation-2026-10-09/checkpoint-base/README.md) retains those changes while reversing only navigation edits in memory; it does not replace runtime files. Reverse applicability and patch whitespace are checked.

Remaining acceptance: owner interaction/visual review and physical-phone touch, legibility and performance. No phone attachment check or physical-device test, Android export/install, full Validate, retained staging race or deployment was performed. The app must be restarted to load the updated scripts.
