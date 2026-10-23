# Repeated Rivalry rating prompt - 2026-10-18

RATE-RETRY-03 / RATE-RIVALRY-02 / R01 / Q01 address the owner's report that Rivalry asks for the same track rating after it was already given. A retry can prefetch a zero score while the previous attempt's rating PUT is pending. Previously, a successful PUT freed the saving service without updating the retry's prefetched zero. Once the saving service disappeared, the retry offered the rating again. The original source reproduces both the stale prompt predicate and the actual duplicate finish panel: 33 checks, two failures.

`game/backend/finish_rating.gd` now passes a server-confirmed positive score to existing attempts for the same server, account and immutable track version before the saving service exits. An older GET returning zero cannot erase that confirmation. Positive GET results also share their confirmation with matching attempts. This uses the existing bounded service children and adds no requests, polling, persistent cache or rating outbox. Failed votes retain the previous unrated/reoffer behavior; stars are never treated as saved merely because they were selected. The existing two-minute lifetime, server eligibility, no-self-rating rule, immediate results and separate durable race upload remain.

`game/tests/test_track_rating_prompt.gd` adds the actual five-lap retry that previously failed, a read held across a successful PUT, server/account/version isolation and failure during the following attempt. Existing first-completion Rivalry verification, save failure, slow PUT, Skip, local disk failure, creator and account-change checks remain. All requests use fictional adapters and all race records use isolated storage.

Actual commands through the pinned Godot 4.7.2 entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/rating-handoff-2026-10-18/compatibility' -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 120
git diff --check -- game/backend/finish_rating.gd game/tests/test_track_rating_prompt.gd
```

Final results: **42 headless rating checks, 46 native Compatibility checks and 101 App checks; zero failures**. The native rating run includes four canonical five-lap finishes. Scoped whitespace checks pass. The initial sandbox attempt could not open Godot's user log and did not reach the tests; native runs used approved escalation. An initial outer PowerShell profile warning was avoided in final runs by disabling login-shell loading. No failing gameplay assertion was removed or weakened.

Inspected native evidence: [unrated prompt at 960x540](evidence/rating-handoff-2026-10-18/compatibility/race-finish-rating-960x540.png), [immediate normal results](evidence/rating-handoff-2026-10-18/compatibility/immediate-normal-results.png) and [the following finish without a repeated rating prompt](evidence/rating-handoff-2026-10-18/compatibility/retry-after-saved-rating.png). Original source, reproduction fixture/log, final logs, source hashes and a task-only patch are retained in [the evidence directory](evidence/rating-handoff-2026-10-18).

No phone attachment check or device test, APK export/install, backend change/deployment or live rating/race write was performed. The installed phone client has not received this fix. Remaining acceptance: owner repeats the delayed-save/retry sequence in live Rivalry using an updated client. Ratings remain scoped to immutable versions; unsuccessful saves can still be offered after another completed attempt.
