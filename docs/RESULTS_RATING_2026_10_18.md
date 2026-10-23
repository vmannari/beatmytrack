# Post-race rating stars and label — 2026-10-18

RRT01 fixes empty stars on Race Complete after choosing a rating beneath the finish banner. RRT02 keeps the label at `Rate the track` throughout verification, loading, saving and unavailable/sign-out states. RRT03 preserves immediate progression to the normal race summary, independent race verification, account/server/version isolation and best-effort vote saving. G01/R01/Q01 cover unchanged racing, local ratings and native verification.

The results row previously performed a separate GET while the finish vote waited for verification or its PUT. That GET returned the old zero, and the row never observed the later save. Its status branches also replaced the caption with verification, unavailable and sign-in messages.

`game/core/app.gd` and `game/ui/race_complete.gd` now pass the existing finish vote to the results row. `game/backend/finish_rating.gd` emits state changes. `game/ui/track_rating.gd` subscribes to that vote, displays the pending selection, and retains the confirmed score when the temporary vote node exits. Failed or expired saves discard pending stars and retain the confirmed value; qualified players can retry from the row. Pending selections do not become confirmed or enter local storage. Matching pending results require no duplicate rating GET. The caption stays fixed; state explanations are confined to its tooltip. Ordinary inline edits also display their pending selection and roll back on failure.

The existing working-tree handoff fix and its regression checks were already present at task start and are preserved. The task-only checkpoint starts from the saved task-start files, including that work, rather than the repository HEAD. No backend, deployment, canonical physics/rules, rewards, comparisons or recommendation behavior changes.

`game/tests/test_track_rating_prompt.gd` exercises real five-lap driving, the actual Continue action into Race Complete, pending and saved stars, failed saves, independent verification, first-race eligibility, slow PUTs, stale GETs, retry handoff, version/account/server boundaries, local save failure and stable captions. New checks against the saved original runtime reproduce nine failures in 53 checks. Final focused checks pass: 54 headless, 63 Compatibility and 63 desktop Mobile. App 101 and parser 854 pass. Native screenshots show four pending stars and three saved stars at 1280×720 and 960×540.

The broader `TestResults` suite stops at `test_race_results.gd:302`, where its reward-preview fixture calls `pause()` on a null reward tween. The saved original runtime reproduces the same failure. That suite is not claimed as passing. Initial restricted runs failed during Windows log/certificate-store initialization; native execution used workspace-only APPDATA/LOCALAPPDATA. An initial added assertion accessed Race Complete before pressing Continue; capture fixtures were then corrected to advance the actual full finish coast, wait for the existing reveal and normalize output paths. All attempts are retained.

Actual commands, source hashes, outcomes and initial diagnostics: [report.json](evidence/results-rating-2026-10-18/report.json). Reviewable change: [task-only.patch](evidence/results-rating-2026-10-18/task-only.patch).

- [Pending four-star choice, compact](evidence/results-rating-2026-10-18/gl_compatibility/results-pending-four-stars-960x540.png)
- [Confirmed three-star rating](evidence/results-rating-2026-10-18/gl_compatibility/results-saved-three-stars-1280x720.png)
- [Confirmed rating, compact Mobile renderer](evidence/results-rating-2026-10-18/mobile/results-saved-three-stars-960x540.png)
- [Failed save returns to unrated](evidence/results-rating-2026-10-18/gl_compatibility/results-failed-save.png)

Owner appearance acceptance remains. No phone attachment check or physical-device test, APK/export/install, live rating/backend mutation or deployment was performed. Desktop Mobile is a renderer check, not device performance evidence.
