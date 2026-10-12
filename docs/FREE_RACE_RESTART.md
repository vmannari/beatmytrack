# Free Race restart, 2026-10-10

Requirements: R01/R03/B07/Q01 and the unlimited ordinary racing, five-lap, pinned verification, durable result and normal-results-first contracts in AGENTS.md.

The actual desktop pause-menu button resets guest and verified races successfully. The reproduced defect is signed-in offline Free Race: `_start_race(..., offline_only=true)` did not retain the offline choice, so `_retry_race()` requested a server ticket and left the race paused when the service was unavailable. The owner has not yet confirmed whether this is the exact reported case or identified the platform.

`game/core/app.gd` now remembers explicit offline entry on the Game node and keeps subsequent Free Race restarts local. A failed verified Free Race retry offers the same explicit **Race offline** choice as initial race entry. Cancel preserves the current paused attempt; accepting starts a fresh countdown and clears competitive/resume tickets. Confirmation is fenced to the same game, account and server. Rivalry and Challenges continue to require verified tickets. Fresh verified tickets, pinned car/handling, five laps, result lifecycle reset and durable completed-result handling remain intact. No physics, rules, backend or score eligibility contract changed.

`game/tests/test_free_race_restart.gd` and its UID exercise the actual offline entry, Game/HUD composition, graphical mouse dispatch to Restart, successful guest/verified resets, unavailable-service offline resets, post-countdown tick advancement, failed verified retry, cancel, stale navigation confirmation, explicit offline acceptance and subsequent offline restarts. Responses are fictional and records/tracks/cloud cache use unique directories under `build/free-race-restart-*`; no live race/score writes are performed.

Actual commands, all using pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_restart.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_restart.gd -Graphical -TestArgument '--capture-restart=C:/Codes/Godot/Beat my track/docs/evidence/free-race-restart-2026-10-10/after'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_review_followups.gd
git diff --check -- game/core/app.gd
```

Before the fix, the focused regression reported **8 checks, 2 failures**: an explicitly offline restart contacted the server and did not reset. The initial graphical button-path probe passed 8 checks and showed the old blocking error; this only established that the ordinary button was connected. Final graphical regression: **20 checks, zero failures**. App: **99 checks, zero failures**. Existing review followups: **86 checks, zero failures**. Diff check: exit 0 (existing CRLF-to-LF advisory).

The first direct PowerShell invocation was blocked by execution policy; explicit `-ExecutionPolicy Bypass` corrected the launcher invocation. A restricted Godot run failed opening its Windows user log; normal Windows access corrected that. An initial test used the Control-only `is_visible_in_tree()` on an AcceptDialog Window; changed to its `visible` property and inspected the actual rendered dialog. These were test/launcher corrections, not weakened race assertions.

Evidence: [before/after and logs](evidence/free-race-restart-2026-10-10/results.json), [failed retry recovery](evidence/free-race-restart-2026-10-10/after/restart-error.png), [accepted offline restart](evidence/free-race-restart-2026-10-10/after/offline-restarted.png), [verified restart](evidence/free-race-restart-2026-10-10/after/restarted.png), [task-only Git-format checkpoint](evidence/free-race-restart-2026-10-10/scoped-change.patch). The final desktop captures were inspected. No changes to the normal pause-menu layout or generated art.

No Android export/install or physical-device test was performed; phone attachment was not checked. No full Validate, production/backend deployment, real service outage or live authenticated race was exercised. Remaining acceptance: owner retry in the reported platform/build and confirmation of the exact symptom. Android needs a rebuilt client to receive the fix.
