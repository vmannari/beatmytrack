# PC rivalry session repair — 2026-10-04

The owner reported becoming Guest after finishing a Weekly Rivalry track with Test Rivals ON, using PC Development sign-in. Requirements: WR08 verified rivalry feedback, TD07 test-mode client integration, B01/B19 authentication, R01 account isolation and Q01 verification.

## Cause and behavior

Read-only local service inspection showed a successful refresh followed by race-upload/result 401s and a rejected refresh. This occurred before the configured 900-second access lifetime. Consumed refresh credentials and revoked session families confirmed that ordinary expiry alone did not explain the incident. The exact other client responsible in the owner's incident remains unidentified.

A disposable real HTTP reproduction restored the same private saved session in another client while a canonical race was finishing. The racing client retained an obsolete refresh credential; attempting to reuse it correctly triggered the server's session-family reuse protection. The old client became Guest and could not finish uploading. A separate engine-process reproduction exercises the same sequence.

Session renewal now acquires a shared lease, reloads the latest saved credential for the same login/player, refreshes, saves and retries the original request while retaining that lease. The request keeps its original idempotency key. Overlapping authenticated reads and uploads also reuse a renewal already completed in the same client. A network failure on the retried ordinary request keeps authentication; an ambiguous refresh failure retains the existing security behavior.

The saved ConfigFile adds `login_id` and `player_id` metadata. Existing files gain it after successful renewal. Access tokens, development keys and Google credentials remain absent from the saved file. Explicit sign-out still takes effect immediately. A different saved login, including a later explicit login for the same player, is fenced and preserved; late startup restoration cannot erase it.

The filesystem adapter uses atomic directory creation beside the private session file, a process ID and a random owner nonce. It waits asynchronously for at most 35 seconds. It recovers a dead process's valid lease by retaining a small nonempty nonce-specific tombstone; this prevents stale observers from moving a newly acquired lease. Empty interrupted markers can be removed after ten seconds. Nonempty malformed markers produce bounded failure without deleting unknown data. Client tree exit releases owned leases. No filesystem, process state, clock or network operation enters the canonical simulation.

Server refresh rotation/reuse detection, authentication gates, token lifetimes and test-population isolation are unchanged. This repair needs no backend migration, restart or NAS deployment.

## Changed files

- `game/backend/backend_client.gd`: shared renewal, latest-credential reload, saved-login metadata, retry and account fences.
- `game/backend/session_rotation_lock.gd` and its UID: process lease adapter.
- `game/tests/test_session_rotation.gd` and its UID: renewal, retry, sign-out, replacement-login and dead-lease regressions.
- `game/tests/session_restore_worker.gd` and its UID: isolated separate-process restore helper; its marker contains only a success boolean.
- `game/tests/test_weekly_rivalry_http.gd`, `backend/tests/test_rivalry_http.py`, `backend/tests/test_cloud_client.py`: normal/expired/restored/separate-process canonical HTTP race scenarios and isolated fixture configuration.
- `game/tests/test_review_reliability.gd`: update an existing cloud-ticket stub to the current five-argument contract; assertions unchanged.
- This document, `ACCOUNT_SIGN_IN.md`, `REMEMBERED_SIGN_IN.md`, `TEST_DRIVERS.md`, `DEVELOPMENT_STATUS.md`, `PHASE_0_PLAN.md` and the linked evidence/checkpoint.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Commands ran from the repository root, using `.tools/backend-venv/Scripts/python.exe` and `scripts/dev.ps1`.

| Command | Actual result |
|---|---|
| `python -m pytest backend/tests/test_rivalry_http.py backend/tests/test_account_client.py backend/tests/test_cloud_client.py -q -s --tb=short --show-capture=no` | 7 passed in 130.23 s; native rivalry checks 26 normal, 26 expired, 27 another client, 28 separate process, all zero failures. Account 58, ordinary cloud race 46 and track lifecycle 38 checks pass. Child exit 0, no script errors. |
| `python -m pytest backend/tests/test_auth.py backend/tests/test_test_drivers.py -q --tb=short --show-capture=no` | 45 passed in 18.60 s. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_session_rotation.gd` | 12 checks, zero failures. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_review_followups.gd` | 86 checks, zero failures. |
| `scripts/dev.ps1 -Action TestReview` | 17 checks, zero failures. |
| `scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/backend_client.gd` | Pass. |
| `scripts/dev.ps1 -Action Import` | Pass; generated the new UID files. |
| `python -m ruff check backend/tests/test_cloud_client.py backend/tests/test_rivalry_http.py` | Pass. |
| `scripts/dev.ps1 -Action Doctor` | DN2103 and emulator-5554 listed. No device driving, APK export or installation performed for this repair. |
| `python -m pytest backend/tests/test_rivalry_http.py -k cross_process -q -s --tb=short --show-capture=no`, with isolated `BMT_CAPTURE_CLOUD` | Graphical separate-process race: 1 passed in 22.43 s; 32 native checks, zero failures; four captures inspected. |

The graphical fixture completes the unchanged canonical five-lap race with Test Rivals ON, uploads it, waits for server verification and shows ordinary Results before verified weekly feedback. It uses a disposable single-human test championship rather than the owner's live 13-bot field. The account remains **Weekly Alice** after the second engine restores the saved session.

- [Desktop normal Results](evidence/rivalry-session-fix-2026-10-04/normal-results-1280x720.png)
- [Compact normal Results](evidence/rivalry-session-fix-2026-10-04/normal-results-960x540.png)
- [Desktop verified rivalry feedback](evidence/rivalry-session-fix-2026-10-04/rivalry-feedback-1280x720.png)
- [Compact verified rivalry feedback and retained account](evidence/rivalry-session-fix-2026-10-04/rivalry-feedback-960x540.png)
- [Curated verification summary](evidence/rivalry-session-fix-2026-10-04/verification-summary.json)
- [Scoped source checkpoint](evidence/rivalry-session-fix-2026-10-04/session-repair.patch), generated against the saved pre-task baseline; reverse-apply checked. Unrelated concurrent work is excluded, and no mixed-tree commit was made.

Initial attempts are not counted as passes: expiry alone passed on the old client; restoring the saved session reproduced the logout and then exposed a cascading empty-score assertion in the harness. The harness now stops on identity loss. The first fix retained identity but a `RefCounted` predelete callback caused script errors; cleanup moved to the owning client's tree exit, and final runs are clean. The reliability suite initially failed because an older ticket stub accepted four arguments; updating its signature restored the unchanged assertions. PowerShell stderr redirection initially obscured a successful pytest exit; final HTTP/capture runs used Python subprocess return codes and returned zero.

## Owner action and remaining acceptance

Restart the PC game, use **Development sign-in** once to replace the already revoked session, then enable **Test Rivals** and race again. Existing account-scoped upload outboxes are retained; this task did not verify recovery of the owner's specific previous race.

Human confirmation of the owner's normal PC flow remains outstanding. Two-client and separate-process race completion passed; prolonged multi-window stress, termination during an actual refresh and other operating systems remain untested. DN2103 and the emulator were attached, but this repair performed no phone/emulator gameplay, export or installation. No physics contract changed, so full physics/replay regression was not run. No production deployment, real Google sign-in or external service integration was performed.
