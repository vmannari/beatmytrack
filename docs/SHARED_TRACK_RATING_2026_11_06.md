# Shared track ratings and post-race completion — 2026-11-06

The owner reports being asked to rate a track again after changing vehicle. The owner clarified that the observation is the rating prompt after a race.

SR01: Share one account's track-version rating across every vehicle. SR02: Preserve a selected first-completion vote when race uploads overlap. SR03: Keep account/server/version boundaries, qualification, one-vote aggregates, immediate results, failed-save behavior and transient-service cleanup. Q01: Reproduce before changing the runtime and run focused client/backend checks.

## Finding and change

Storage already shares ratings: `Rating` is keyed by `(version_id, player_id)`, the GET/PUT rating endpoints have no vehicle parameter, and local `track_ratings` use track identity. Leaderboards remain specific to each vehicle. No data migration or backend runtime change is needed.

The post-race service previously waited for `cloud_tracks.changed` and checked the final general upload status. `_flush_jobs()` can finish one race, emit `race_verified`, and then set the status to another job's pending upload before emitting `changed`. A chosen first-completion rating can consequently miss its qualification refresh, remain unsent, and eventually expire. A later race, including one using another vehicle, then receives the rating prompt again. This reproduces a possible cause of the report; no owner's live session was inspected.

`game/backend/finish_rating.gd` now also subscribes to the existing explicit `race_verified` event. It refreshes the selected vote's actual server eligibility independently of the final batch status. A completion during an older eligibility read requests another read. The handler retains identity/sending/deletion guards, and its event connection is removed on exit. The existing generic-status and Rivalry paths remain.

Changed files:

- `game/backend/finish_rating.gd`: completion subscription and shared guarded callback.
- `game/tests/test_shared_track_rating.gd`: cross-car first-completion, pending-choice handoff, stale-read and listener cleanup regression.
- `backend/tests/test_domains.py`: real local HTTP/domain test across five distinct vehicle boards, one changeable vote and one shared aggregate; uses the existing fake canonical verifier.
- This report and its scoped evidence/checkpoint.

## Actual verification

Exact engine: `4.7.2.stable.official.ed1daf0bf`. Godot runs use process-local `APPDATA` beneath `build/`, Dummy audio, fictional transports and isolated records. No owner profile is loaded.

| Check | Actual result |
| --- | --- |
| Original runtime / initial new regression | 12 checks, 10 failures, exit 1. The failure cascade includes an unsaved first-car choice, absent cross-car confirmation and missed completion during a stale read. |
| Updated runtime / final regression | 14 checks, 0 failures, exit 0; all five selectable cars restore the same rating, listeners disconnect, duplicate feedback does not resubmit. |
| Existing actual-App post-race suite, headless | 54 checks, 0 failures, exit 0. |
| Existing actual-App post-race suite, native Compatibility | 63 checks, 0 failures, exit 0; nine PNGs. Includes saved/failed/in-flight stars, normal results, retry suppression, real pointer clicks and five-lap driving. |
| Backend SQLite rating tests | 2 passed, 58 deselected. Five vehicle boards remain distinct, vote count stays one as its score changes, and another player remains unrated/unqualified. |
| Ruff on modified Python test | All checks passed. |

Native screenshots were inspected, including the compact saved three-star results view: [960×540](evidence/shared-track-rating-2026-11-06/native/results-saved-three-stars-960x540.png). These are desktop fixture views, not owner/device acceptance. There is no UI layout or artwork change.

Commands run from the repository unless a working directory is specified:

```powershell
# Initial wrapper attempt: failed at user:// log access. Isolating APPDATA
# resolved that; the wrapper then stopped on the Windows certificate diagnostic.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shared_track_rating.gd -CommandTimeoutSeconds 90

# Direct exact-engine fallback, with APPDATA set beneath build/ for each run.
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --log-file 'C:/Codes/Godot/Beat my track/build/shared-track-rating-before.log' --script res://tests/test_shared_track_rating.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --log-file 'C:/Codes/Godot/Beat my track/build/shared-track-rating-after.log' --script res://tests/test_shared_track_rating.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --log-file 'C:/Codes/Godot/Beat my track/build/shared-track-rating-prompt.log' --script res://tests/test_track_rating_prompt.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --audio-driver Dummy --log-file 'C:/Codes/Godot/Beat my track/build/shared-track-rating-native.log' --script res://tests/test_track_rating_prompt.gd -- '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/shared-track-rating-2026-11-06/native'

# Working directory: backend/
& ../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_domains.py -k 'rating and sqlite' -q
# Working directory: repository root
& ./.tools/backend-secure-venv/Scripts/ruff.exe check backend/tests/test_domains.py
git diff --check -- game/backend/finish_rating.gd backend/tests/test_domains.py
git apply --reverse --check docs/evidence/shared-track-rating-2026-11-06/scoped-change.patch
```

An initial pytest launch from the repository root could not import `bmt_backend`; rerunning from `backend/` passes. Godot runs retain the sandbox's `Failed to read the root certificate store` diagnostic. The direct runs complete with the assertion outcomes above and no other engine errors in their logs. Backend tests retain the existing Starlette deprecation and SQLite expression-index reflection warnings. PostgreSQL was not exercised.

## Checkpoint and limits

[Task-only patch](evidence/shared-track-rating-2026-11-06/scoped-change.patch), copied logs, source hashes and the original runtime snapshot accompany this report. Reverse application is checked without changing the working tree or index. Existing concurrent work is preserved; wrapper-generated build identity remains outside the task patch.

Client reload/rebuild and owner acceptance on the installed client remain. No physical-device attachment query or test, APK/export/install, owner-save change, live rating/request, backend deployment or main-index write was performed. A deliberately skipped rating or failed/unacknowledged save can still be offered on a future race under the existing best-effort policy. Different immutable track versions retain separate ratings.
