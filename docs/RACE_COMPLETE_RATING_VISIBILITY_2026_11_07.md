# Hide unavailable ratings on Race Complete — 2026-11-07

RCV01 hides the entire `Rate the track` row when a published track cannot be rated. This includes the player's own publications, unknown or failed eligibility reads and signed-out accounts. RCV02 retains selected stars during background saves, confirmed editable ratings and the existing eligibility refresh after verification. RCVQ01 covers the actual finish-to-results flow and desktop captures.

`game/ui/race_complete.gd` opts its rating row into `hide_when_unavailable`. `game/ui/track_rating.gd` updates that row's visibility with its existing eligibility state and hides it immediately when its account changes. The row remains present internally so verification can reveal it when rating becomes available. An existing selection stays visible while saving. Other consumers keep their existing presentation. The server's existing owner, verified-finish and account rules remain authoritative; no backend change is needed.

`game/tests/test_track_rating_prompt.gd` now completes a real five-lap own-track attempt, opens Race Complete through Continue and checks that its label and stars are hidden. It also checks unknown eligibility, denial, failed reads, sign-out, later eligibility, inline saves and listener cleanup, alongside its existing race, pending-vote, saved-vote and identity-boundary checks. All backend responses are fictional and local records are isolated inside `build/`.

The new own-track check reproduces the bug against the original runtime: **57 checks, 1 failure**. Final native Compatibility execution passes **75 checks, 0 failures**, including eleven screenshot saves. Own-track pages at 1280×720 and 960×540 were visually inspected, together with the pending four-star page. The own-track row is absent and selected stars remain visible. The pinned engine is `4.7.2.stable.official.ed1daf0bf`.

Actual test commands, after setting `APPDATA` and `LOCALAPPDATA` to `build/race-complete-rating-test/appdata` and `build/race-complete-rating-test/localappdata`:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -RenderingMethod gl_compatibility
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --capture-rating=res://../docs/evidence/race-complete-rating-2026-11-07/gl_compatibility
git diff --check -- game/ui/race_complete.gd game/ui/track_rating.gd game/tests/test_track_rating_prompt.gd
git apply --reverse --check docs/evidence/race-complete-rating-2026-11-07/task-only.patch
```

The initial sandbox run stopped at Windows certificate-store/access errors and was interrupted. The original-runtime reproduction and final checks ran with native Windows access. An initial native run passed the UI assertions but failed a cleanup assertion that incorrectly required every identity listener to be gone while another results page remained open. The assertion now checks only the closed row's listener; the final rerun passes. The original reproduction also printed a shell-profile execution-policy warning before running successfully; subsequent launches disabled profile loading. Initial logs are retained.

- [Own track, 1280×720](evidence/race-complete-rating-2026-11-07/gl_compatibility/results-own-track-1280x720.png)
- [Own track, 960×540](evidence/race-complete-rating-2026-11-07/gl_compatibility/results-own-track-960x540.png)
- [Pending rating retained](evidence/race-complete-rating-2026-11-07/gl_compatibility/results-pending-four-stars-1280x720.png)
- [Commands, source hashes and outcomes](evidence/race-complete-rating-2026-11-07/report.json)
- [Task-only source checkpoint](evidence/race-complete-rating-2026-11-07/task-only.patch)

`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record the completed change. The standard test entry point refreshed generated client identity/version metadata in `game/core/build_identity.gd` and `game/project.godot`; those generated changes are outside the task-only source patch. Existing concurrent changes and the main Git index are preserved.

Owner appearance acceptance and a future rebuilt-device check remain. No device attachment query or physical-device test, APK export/install, live backend/rating request or deployment was performed. This is a desktop UI check, not a device performance claim.
