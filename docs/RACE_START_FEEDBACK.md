# Race start feedback — 2026-10-11

The owner reports that Race does not start and gives no reason. The exact mode,
track and incident were not confirmed during this change. Inspection and isolated
regressions reproduce silent cancellation when account, car or selected track
changes during asynchronous preparation. Disabled track and rivalry race actions
also retained a Race caption without identifying their blocker.

Requirement IDs: **RLOAD07** (explain same-page cancelled preparation), **RLOAD08**
(disabled action communicates its blocker), **RLOAD09** (nonempty failure and
loading-instance fencing), **B01, R01, Q01**. These RLOAD IDs identify this slice.

## Behavior and files

- `game/core/app.gd`: shared preparation fence shows the specific changed account,
  car or track reason. Navigation and superseded requests retain silent intentional
  cancellation. Metadata preparation checks its owning overlay before downloading
  and after each await; a late reply cannot mutate a newer preparation. Missing
  selection and otherwise empty download/ticket failures have actionable messages.
  Free race retains its explicit offline option after failed online preparation.
- `game/ui/track_browser.gd`: disabled Race shows Loading track, Choose a track,
  Track needs repair, or Select track again to retry. Pending superseded workers
  remain fenced even if optional scores redraw the action. After draining, the
  current track's normal Race action returns. Download failure copy avoids repeating
  the recovery instruction beside the button.
- `game/ui/weekly_rivalry_page.gd`: disabled Race identifies updating, failed
  refresh, completed week, inactive rivalry or unavailable track in the action.
- `game/tests/test_metadata_race_preparation.gd`,
  `game/tests/test_menu_loading.gd`: meaningful changed-prerequisite and action
  feedback assertions added to existing isolated regressions. The former ordinary
  preparation-caption assertion now requires feedback on the disabled action while
  keeping the records area free of a redundant loading caption.
- `game/tests/test_race_start_feedback.gd`: actual start coroutine with held
  transport, duplicate starts, account/car/track changes, navigation, empty error,
  missing selection, five-lap offline recovery and rivalry blockers; rendered
  captures use disposable local fixtures.
- This report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and evidence record
  the actual outcomes. Gameplay, scoring, persistence and backend contracts are
  unchanged. No live ticket, account, result or deployment writes were issued.

## Actual commands and outcomes

Pinned **Godot 4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.
Tests set process-local APPDATA to isolated directories under
`.tools/race-start-feedback-*`; no owner credentials or saves are used.

| Arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_metadata_race_preparation.gd` | Baseline 29 checks / 3 failures; final 29 / 0 |
| `-Action TestScript -ScriptPath res://tests/test_menu_loading.gd -Graphical` | Final 45 checks / 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_race_start_feedback.gd -Graphical` | 21 checks / 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_race_loading.gd -Graphical` | 83 checks / 0 failures |
| `-Action TestApp` | 99 checks / 0 failures |
| `-Action Doctor` | Final successful prerequisites check; ADB reports no attached devices |

**277 final checks, zero failures.** Actual normal countdown/loading and five-lap
offline recovery pass. Initial restricted invocations could not open the normal
user log or read the Windows certificate store; isolated saves and normal local
certificate-store access allowed verification. Restricted Doctor failed on ADB's
configuration access; the final normal-access check succeeded. One graphical
invocation exited with only the engine banner and no test summary: it is not
counted as passing; the subsequent run printed the complete 45/0 result.

Eight PNG captures under `docs/evidence/race-start-feedback-2026-10-11/` show
changed-car and connection dialogs, track loading/download failure, and four
rivalry blockers. Changed-car, loading and rivalry updating captures were visually
inspected; captures use fixtures and are not live standings evidence. Logs remain
under `build/logs/`. Task-only review ref:
`refs/codex/race-start-feedback-20261011`, with receipt and isolated patch beside
the captures. Working branch/index and unrelated work are preserved.

## Limits and remaining acceptance

Restart the desktop client to load the changes. No phone is attached; no physical
device test or Android export/install was performed. Full Validate and physics
regressions were not run for this presentation/preparation change. No backend
deployment is needed or performed. The exact owner incident remains unattributed;
retry the affected mode/track to verify its observed blocker and successful start.
Existing preparation deadlines cannot interrupt a frozen engine main thread.
