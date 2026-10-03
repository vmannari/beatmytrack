# Rejected Over and under race replay — 2026-10-03

Requirements: R01/G01/T01–T04/B01–B07/Q01. Investigate the owner's `Race verification rejected: invalid_replay`, reproduce the actual recorded failure, retain strict ordered gates and immutable leaderboard rules, and verify the correction.

## Cause and reproduction

The retained compact recording contains 7,786 three-channel inputs and no rewinds. Its immutable track document exactly matches `game/tests/fixtures/over_and_under.json`. It belongs to a v16 board. The initial read-only invocation in the running PC API reproduced `VerificationError: Replay does not complete the required laps and ordered road gates`.

The old ramp-tangent checkpoint plane rejects gate 12 at input tick 3,632, position `(16.1785, 5.359517)`, during lap three. Only laps one and two are recognized, at 1,627 and 1,412 ticks. The gate crosses both ground and the bridge deck near the first exit, causing a false layer rejection on an ordinary road lane. This is the same physical defect as the [bridge-exit repair](BRIDGE_EXIT_CHECKPOINTS.md), not the maximum-envelope bug or a rewind failure.

The existing v17 bridge-axis correction was already present in this shared workspace, and the running backend reached that corrected build during the investigation. This task does not claim to have authored that canonical correction or rebuilt those services. With v17, the exact original recording completes at 7,786 ticks / 64.880 seconds, with lap ticks `[1627, 1412, 1426, 1553, 1768]`, on Windows and both running Linux API/worker containers. Their canonical TrackSession, rules, simulation, runner and native-track hashes match the workspace.

## Changes

- `game/tests/fixtures/over_and_under_rejected_inputs.json`: the owner's actual input recording, with no player, account, ticket, run, credential or backend identity. Existing owner-track geometry is reused. These fixtures are excluded from Android exports by the existing `tests/*` exclusion.
- `game/tests/test_rejected_race_replay.gd` and UID: reproduce the old gate directions through a diagnostic subclass; verify corrected five-lap exact timing; exercise rejected-upload polling, retained replay integrity and the displayed recovery message using an isolated fictional identity. Graphical execution captures the actual upload dialog/status text.
- `backend/tests/test_verifier.py`: verify this recording through the real canonical process and assert truncated/trailing inputs still reject.
- `game/backend/cloud_tracks.gd`: use the existing human-readable failure mapper for the polled rejection status; explain that the server could not verify the finish and suggest updating/restarting and racing again. Persist the original internal failure code and replay unchanged.
- This report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and the scoped evidence checkpoint.

No new physics/rules/schema version is introduced here. The actual physical correction remains rules v17 / physics 0.49 / compiler 20. No rejected score is promoted or moved onto another rules board; the original v16 rejection is retained. A fresh race after restarting the current desktop game uses v17.

## Actual verification

Commands run from the repository root:

| Command | Outcome |
| --- | --- |
| Read-only Python through `wsl -d Ubuntu -- docker exec -i bmt-pc-dev-api-1 python -` | Initial actual replay rejects; later current v17 accepts exactly 7,786 ticks. No database write or leaderboard submission. |
| Same probe through `bmt-pc-dev-worker-1` | Current v17 accepts identical lap/race ticks; original database status still rejected. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rejected_race_replay.gd` | Final 9 checks pass. Old gates reproduce the tick-3,632 miss; corrected gates accept the full recording. |
| Same command with `-Graphical` | Final 10 checks pass; screenshot inspected, with readable wrapped dialog text. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py backend/tests/test_domains.py -q -k 'not postgres'` | 74 pass, 30 deselected; existing Starlette/httpx deprecation warning. Includes actual recording, malformed/truncated/trailing replay and canonical golden checks. |
| `-Action TestScript -ScriptPath res://tests/test_review_followups.gd` | 86 checks pass. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q` | Two real HTTP/Godot cloud lifecycle tests pass against a disposable backend. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 260 scripts, zero failures. |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached. Attachment is not a phone test. |
| `.tools/backend-venv/Scripts/ruff.exe check backend/tests/test_verifier.py` and scoped `git diff --check` | Pass; Git reports existing CRLF normalization notices. |

The first diagnostic harness incorrectly assumed four-channel inputs and failed on this retained older three-channel recording. It was corrected to decode both supported formats. Two harness attempts used an incorrect replay-access helper/relative path; final tests check the persisted replay's actual path and hash. Those failures were test-harness issues, not successful product verification.

Evidence: [API verification](evidence/rejected-replay-2026-10-03/bmt-pc-dev-api-1.json), [worker verification](evidence/rejected-replay-2026-10-03/bmt-pc-dev-worker-1.json), [actual rejected-upload message](evidence/rejected-replay-2026-10-03/rejection-message.png). The screenshot uses an isolated fixture UI, not the owner's session. A task-only patch is the reviewable Git checkpoint; no mixed-workspace commit.

## Remaining acceptance

Restart the desktop game, race Over and under and confirm a new v17 attempt is verified through normal authenticated submission. The retained replay was directly verified; its old immutable board was deliberately preserved. No Android export/install/driving test, NAS or production deployment, phone performance measurement or full Validate gate was performed. DN2103 is attached. Backend application code has not been rebuilt/restarted by this task.
