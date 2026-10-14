# Rating prompt on repeated races (2026-10-12)

Requirements RATE-RETRY-01 / RATE-RIVALRY-02 / B05 / R01 / Q01: suppress duplicate finish prompts while the same origin/account/version has a selected vote awaiting verification or its PUT. Wake the waiting vote from Rivalry's verified result as well as the ordinary cloud upload notification. Server-confirmed stars still suppress subsequent attempts; failed/expired votes remain unrated. No eligibility, scoring, backend or public/development isolation changes.

Changed files: `game/backend/finish_rating.gd`, `game/core/app.gd`, `game/tests/test_track_rating_prompt.gd`. The selected vote retains its existing bounded lifetime and account fencing. Suppression scans the existing cloud vote children; no optimistic persisted rating is introduced.

Actual commands (pinned engine through `scripts/dev.ps1`):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd`: 30 checks, zero failures, including actual five-lap finishes, Rivalry verification notification and retry during held PUT.
- Same command with `-Graphical -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/rating-retry-2026-10-12'`: Compatibility renderer, 33 checks, zero failures; three screenshots in that directory.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor`: pinned engine/templates found, empty ADB device list. No phone test performed.

Initial shell execution policy prevented entry-point execution; process-scoped Bypass resolved it. Sandbox Godot user-log access failed; the successful runs used approved escalation. An initial new test incorrectly prepared a vote after the results had cleared the ticket; corrected to use the actual retry flow. The first graphical capture used a resource path unsupported by the directory call; reran successfully with the absolute path.

Remaining acceptance: owner repeats the first-drive rating and retry on live Rivalry, including actual network verification delay; physical Android testing. Tests use fictional backend responses and isolated local records. No deployment, APK export or live writes. Existing failed-vote behavior deliberately allows a future prompt. This fix cannot make an ineligible or failed backend vote count as saved.
