# Weekly Rivalry completion, 2026-10-12

The owner reported having to press **Continue to next week** repeatedly. This task implements WC01–WC04 under WR01/WR03/WR08, B05/B07, R01 and Q01.

- **WC01:** one successful finale action enrolls in the current UTC week with five tracks, for either real or development populations.
- **WC02:** acknowledgement and enrollment share a busy interval; repeated presses/background refresh cannot overlap them. Failed requests retain the reviewed finale for retry with a stable acknowledgement idempotency key.
- **WC03:** continuing dismisses older ended finales for this player, car and population without modifying scores, history, tickets or another player's acknowledgement. Current/newer weeks remain unacknowledged. Active/settling finales cannot continue.
- **WC04:** account resets and late old-week result/enrollment replies cannot replace the new board. Changing groups clears prior result, ghost and native-preview state.

## Reproduction and fix

`/rivalry/current` selects the latest **unacknowledged** older membership. The old Continue endpoint acknowledged only its selected membership. With three missed finales, a successful Continue returned another older complete week, repeatedly. The new backend regression reproduced this before modification: **one failed, one passed**, with `complete` returned where `not_joined` was expected.

The client also did not set `busy` or emit a change before its acknowledgement request, allowing repeated presses to queue independent operations. After success it reset its model and fetched `/current`; real populations stopped at the unjoined introduction, while automatic development enrollment could begin only after all older finales had been dismissed. The existing automatic-flow fixture modeled only one old finale and advanced its fake clock on Continue, so it did not expose the historical backlog.

The server now acknowledges this player's ended memberships through the reviewed week's start, restricted to its car and population. The selected group's verification must first be complete. This is a presentation acknowledgement only: older race verification and stored results remain intact and historical group views remain readable.

The client owns acknowledgement/enrollment immediately and directly calls the existing current-week Join endpoint after acknowledgement. This also avoids replaying old finales against an older deployed server. The completed screen stays visible and disabled until enrollment succeeds; failed enrollment retains it for a retry. No extra player-facing text was added. Existing five-lap, best-only scoring, pinned contracts, normal-results-first and real/artificial isolation contracts remain unchanged. No migration or API schema change is required.

Changed files:

- `game/backend/weekly_rivalry_client.gd` — transition ownership, direct enrollment, retry key and stale-reply/result cleanup.
- `backend/bmt_backend/rivalry.py` — scoped dismissal of older ended finales.
- `game/tests/test_rivalry_week_completion.gd` — delayed acknowledgement/enrollment, repeat presses/timer refresh, retry keys, real/development populations, old result replies, account/reset fences, settling/scope guards and actual app signal/button rebuilding at two widths.
- `backend/tests/test_rivalry_week_completion.py` — three missed weeks, private membership, idempotency, retained history, other-car/population/new-week isolation, exact end boundary, pending verification, verified final points, next-week enrollment/ticket and unchanged historic standings.
- `scripts/test_rivalry_week_postgres.py` — repeatable tests using the existing PostgreSQL 17 image in a newly owned loopback-only container, redacted logs and label-checked cleanup; no existing service modified.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and scoped evidence/checkpoint.

## Actual verification

Godot commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned **4.7.2.stable.official.ed1daf0bf**. Python commands used `.tools/backend-venv/Scripts/python.exe`.

| Actual command/arguments | Outcome |
| --- | --- |
| `-m pytest backend/tests/test_rivalry_week_completion.py -k 'not postgres' -q --tb=short` before the fix | **1 failed / 1 passed / 2 deselected**; older finale reproduced. |
| `-m pytest backend/tests/test_rivalry_week_completion.py backend/tests/test_rivalry.py -k 'not postgres' -q --tb=short --show-capture=no` | **12 passed / 11 deselected**. |
| Final focused `-m pytest backend/tests/test_rivalry_week_completion.py -k 'not postgres' -q --tb=short --show-capture=no` | **2 passed / 2 deselected**; [log](evidence/rivalry-week-completion-2026-10-12/sqlite-rollover.log). |
| `scripts/test_rivalry_week_postgres.py` | **11 passed / 12 deselected** on an owned PostgreSQL 17; container removed. [Log](evidence/rivalry-week-completion-2026-10-12/postgres-regression.log). |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_week_completion.gd -CommandTimeoutSeconds 120` | Initial **36 checks / 0 failures** before adding the late-result case. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_week_completion.gd -Graphical -CommandTimeoutSeconds 120` | **44 checks / 0 failures**, including six captured images. |
| Same new test with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` | **44 checks / 0 failures**, including six captured images. Desktop rendering only. |
| `-Action TestScript -ScriptPath res://tests/test_automatic_rivalry_flow.gd -CommandTimeoutSeconds 60` | **7 checks / 0 failures**. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 120` | **1,109 checks / 0 failures**. |
| `-Action TestApp -CommandTimeoutSeconds 120` | **99 checks / 0 failures**. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_entry.gd -CommandTimeoutSeconds 90` | **66 checks / 0 failures**. |
| Ruff for the changed backend, new backend test and PostgreSQL runner | Passed. |
| `-Action Doctor` | Pinned engine/templates found; **empty ADB device list**. |

The first sandboxed Godot invocation could not open its usual user log directory; the permitted native rerun passed. The configured historical PostgreSQL endpoint at localhost:55439 timed out for both new parameterized cases; the owned-container runner then verified both new cases and existing rivalry regressions. Its first restricted invocation could not access the existing image; the permitted local Docker run succeeded. No assertions were removed to resolve these environment failures. FastAPI/httpx deprecation warnings remain.

Captured fixture evidence: [completed week](evidence/rivalry-week-completion-2026-10-12/ui/finale-1280x720.png), [disabled Continue at 960×540](evidence/rivalry-week-completion-2026-10-12/ui/continuing-960x540.png), and [current week at 1280×720](evidence/rivalry-week-completion-2026-10-12/ui/next-week-1280x720.png). These show synthetic fixture standings, not the owner's actual account.

No phone was attached and no physical-device test, Android export/install, live account mutation, backend deployment or full physics regression was performed. Restart/rebuild the client to use the direct enrollment fix; the server's historical-dismissal change remains local until separately authorized deployment. Remaining acceptance: the owner's actual account/latency and the physical-device week transition. Local desktop tests do not claim physical-device or production acceptance.

The reviewable eight-file [task-only checkpoint](evidence/rivalry-week-completion-2026-10-12/scoped-change.patch) is built against saved pre-task versions; it preserves unrelated working-tree edits. Its [manifest](evidence/rivalry-week-completion-2026-10-12/checkpoint.json) records HEAD and before/after SHA-256 values. `git apply --reverse --check --whitespace=error-all` and targeted `git diff --check` passed. Native test logs are retained in the evidence `logs/` directory. No mixed working-tree commit was created.
