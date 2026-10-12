# Rivalry track results reference — 2026-10-08

Requirements: WR06/WR08-WR10, R01, V03-V05, Q01; RRF01-RRF12 refer to the twelve changes in the owner's supplied result-screen reference. This is the competition screen opened by Continue after normal race results. Normal PB feedback, lap analysis and the unified comparison histograms remain first.

| Owner requirement | Implemented behavior |
|---|---|
| RRF01-RRF03 | Full track standings replace the large expected-position panel. Eight complete rows fit the supported landscape layouts; all remaining entrants scroll. Yellow fill/border identifies the player, who is revealed after layout even below eighth place. Country flags and existing avatar/flag icons are reused. |
| RRF04 | Signed millisecond-precision gaps compare every competitor's listed weekly best with the player's listed weekly best. Faster rivals are negative; slower rivals are positive; the player and missing times use an em dash. A slower retry keeps its current race time on the left and its weekly PB in the competitive table. |
| RRF05-RRF06 | Details/standings occupy approximately 37%/63%, without the result screen's former full-height mode rail. The header retains its trophy and floating tabs. Existing original biome artwork is bright, with a white outline of the raced native route. No new bitmap or reference-image asset is shipped. |
| RRF07-RRF08 | Green NEW PB, exact improvement and previous personal best use the pre-save local record captured on completion. A first PB has no invented previous time or improvement. Actual completed laps and native route length determine total distance. Theme-derived daylight/night/rain/snow and dry/wet/icy/packed-sand facts reflect the implemented conditions. Desert is daylight; ordinary races remain five laps. |
| RRF09-RRF10 | Compact track rank/field size, actual weekly points delta and overall position change sit below the table. The direction and signed movement follow the model; slower retries never mint points. Missing or rejected outcomes do not fabricate awards. |
| RRF11-RRF12 | Pending verification uses a small PROVISIONAL status beside YOUR RESULT. Race Again and Back to Rivalry share a horizontal row at the bottom right. Existing actionable verification errors remain available. |

`WeeklyRivalry.result_board()` overlays the provisional or confirmed own PB on a duplicate of the latest track board, sorts by canonical ticks, and assigns tied ranks consistently. This prevents the table showing the old own time while a full board refresh is in flight. Verified track entries, weekly totals, identities, development gates and public-population isolation remain untouched. Canonical simulation, physics/rules/content versions, scoring policy, backend API/schema and deployment are unchanged.

The native scroll container retains desktop wheel/scrollbar behavior and explicitly owns touch gestures begun in the list. List drags follow the finger, including beyond its bounds, without becoming page-navigation swipes. Logical row rounding distributes spare pixels across each eight-row group so the eighth row is fully visible. One-shot layout callbacks reveal the player and disconnect if the page is removed.

Changed files:

- `game/ui/weekly_rivalry_result.gd` and generated UID: result layout, preview, track facts, player list and actions.
- `game/ui/weekly_rivalry_page.gd`: result component wiring and result-specific header/rail arrangement.
- `game/race/weekly_rivalry.gd`: presentation-only result board.
- `game/core/app.gd`: captured pre-save PB, actual race details and component wiring.
- `game/tests/test_rivalry_result.gd` and UID: result-board, native input/layout and completed-session flow checks.
- `game/tests/test_rivalry_feedback.gd`: replacement visual assertion and mock alignment with the adapter's existing recent-run/error-response contract.
- `AGENTS.md`, status/phase entries, reference follow-up link and this report.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned **4.7.2.stable.official.ed1daf0bf** build:

| Command | Actual final outcome |
|---|---|
| `Import` | Exit 0; new runtime UID registered. |
| `CheckScript -ScriptPath res://ui/weekly_rivalry_result.gd` | Exit 0. |
| `TestScript -ScriptPath res://tests/test_rivalry_result.gd -Graphical` | **105 checks, zero failures**. 1280×720, 960×540 and 1600×720; eight visible rows, 37/63 balance, PB/points/gap values, touch and wheel scrolling, last entrant, low-ranked player reveal, aligned scrollbar gutter, actual button touches, pending/confirmed/first/slower/rejected states and normal-results-first flow. |
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd` | **1,046 checks, zero failures**, headless. |
| `TestScript -ScriptPath res://tests/test_rivalry_feedback.gd` | **18 checks, zero failures**, headless; preview/confirmation delay, rejection, stale-ticket/account fencing and connection backoff. Final preview measured 1,013 μs in this fixture. |
| `TestApp` | **99 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **370 scripts, zero failures**. The subsequently extended result test also compiled and passed its graphical run. |
| `git diff --check` on existing changed runtime/test files | Exit 0; existing CRLF-normalization notices retained. |

Initial attempts are retained in the evidence logs. Windows script execution policy required the process-local Bypass flag; sandboxed Godot could not read the root certificate store/cache, so the pinned local engine ran with reviewed elevated access. No automatic approval rejection occurred. The initial test looked up an unnamed generated container incorrectly; it now reads the component's actual rows. The first layout exposed whole-pixel rounding that clipped the eighth row; the fix distributes the remainder rather than relaxing the check. Raw injected touch did not scroll the native list; explicit list-owned touch handling now passes actual viewport input. The existing verification mock lacked `recent_run()` and the real client's always-present error `data` dictionary; those fixtures were brought into agreement with the existing client contract. No runtime verification invariant was weakened.

Twenty native screenshots are retained; the linked desktop, compact, player-reveal, scrolling and app-flow captures were inspected. The twenty-entrant, five-track fixture has internally summed weekly points and a computed overall #3 → #1 change; its times and identities are controlled presentation examples, never inserted into live accounts. The separate app-flow capture uses a disposable real game scene with a programmatically completed five-lap session and a 110.000 s prior local PB, proving the 109.000 s result retains its pre-save improvement. It is not a driven or backend-verified race. No account credentials or owner save files are used.

Evidence: [desktop result](evidence/rivalry-track-results-2026-10-08/ui/provisional-1280x720.png), [compact confirmed](evidence/rivalry-track-results-2026-10-08/ui/confirmed-960x540.png), [low-ranked highlighted player](evidence/rivalry-track-results-2026-10-08/ui/first-finish-960x540.png), [scrolled last entrants](evidence/rivalry-track-results-2026-10-08/ui/scrolled-1280x720.png), [normal summary first](evidence/rivalry-track-results-2026-10-08/ui/normal-results-first-1280x720.png). Task-only before sources, logs, hashes and the [review patch](evidence/rivalry-track-results-2026-10-08/scoped-source.patch) preserve the checkpoint without including unrelated working-tree changes.

Remaining acceptance: owner visual review and physical-phone legibility, gestures and performance. Phone attachment was not checked and no physical-device test, Android export/install, live-backend race, full Validate/physics regression or deployment was performed. Desktop captures use the project's canvas stretch; they are not phone evidence. Backend endpoint behavior and live scoring need no deployment change for this presentation slice. Track conditions are derived from the currently implemented theme, not a new weather system.
