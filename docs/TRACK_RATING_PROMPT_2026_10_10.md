# Track rating action and restored cloud prompt ? 2026-10-10

## Requirements and behavior

- RATE01: Replace ?Your rating? / ?Your track rating? with the requested **Rate the track** in the shared rating row; use the same title in the existing local finish prompt.
- RATE02 / B04: A completed online race on an unrated immutable cloud version offers a skippable rating prompt once the server reports eligibility. Already rated, self-owned, ineligible and signed-out versions do not open it. Offline races and editor practice do not add cloud prompts. The existing local finish prompt remains.
- RATE03 / R01: Normal PB/lap results become available immediately and upload/verification continue independently. The optional prompt belongs to the completed results view, survives Continue into Race Complete, and retires with navigation. Skip leaves the vote unset and permits an offer on a later race.
- Q01 / V06: Preserve rating idempotency and server qualification, account/server fences, five ordinary laps and normal results first. No backend, physics, scoring, artificial/public population contract or deployment changes.

The root cause was `App` deliberately setting `Game.rating_records` to null for cloud tracks, thereby excluding every cloud race from the local-only finish prompt. Keep that local/cloud separation and attach a separate server-aware prompt to completed online results. Use the existing rating GET/PUT API rather than locally persisting a cloud vote or bypassing verified-race/self-rating qualification.

`TrackRating` now notifies its prompt when eligibility loads, rechecks when another verified upload emits the same status as the previous one, and remembers verification arriving during an unfinished eligibility request. Reads cannot unlock stars during a vote save. Repeated save attempts retain the existing idempotency key; stale account/server responses cannot update the row. Departed rows/prompts disconnect their sync/identity listeners.

## Changed files

- `game/ui/track_rating.gd`: action caption, eligibility signal, verified-event refresh and pending-read handling, save-state guard, account/server fencing, listener cleanup and cloud-save error notification.
- `game/ui/race_cues.gd`: existing local prompt title.
- `game/ui/track_rating_prompt.gd`: new compact menu-styled optional cloud prompt, delayed reveal, Skip, confirmation and identity/navigation cleanup.
- `game/core/app.gd`: attach the cloud prompt only for a finished result eligible for its actual completed-ticket upload.
- `game/tests/test_track_rating_prompt.gd`: isolated fictional-client lifecycle checks and direct UI captures. No live ratings or owner records are used.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and the scoped evidence patch.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/track-rating-2026-10-10/after'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/track-rating-2026-10-10/results'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureResults
$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/track-rating-2026-10-10/baseline-results'
powershell -NoProfile -ExecutionPolicy Bypass -File build/track-rating-baseline/scripts/dev.ps1 -Action CaptureResults -CommandTimeoutSeconds 60
git diff --check -- game/ui/track_rating.gd game/ui/race_cues.gd game/core/app.gd
```

Final graphical focused check: **24 checks, zero failures**, including newly qualified first completion, repeated verified status, verification during the initial GET, Skip/reoffer, saved cloud score suppression, failed PUT/retry/same key, qualification/self-rating suppression, account switch, departed listeners, saving during background verification, compact landscape containment, local persistence and the real Race Complete inline row. App regression: **99 checks, zero failures**. Scoped whitespace check passed.

Broader `CaptureResults` did **not** pass: eight failures (existing local confirmation timing, three lap-selection/three route-touch assertions, local recommendation count) followed by an out-of-bounds third recommendation card at `test_race_results.gd:328`. An isolated starting-code overlay under `build/track-rating-baseline` restored exactly the three changed existing scripts from the saved task baseline and reproduced the identical failures. The live working source was not swapped. Assertions were retained; this task does not claim a full results-suite pass.

Initial direct PowerShell execution was blocked by execution policy; the explicit process invocation above resolved it. A restricted engine parse attempt failed opening its Windows user log; normal Windows engine access resolved it. The first focused run had one local-save fixture failure because its isolated folder was missing; creating that fixture folder corrected it. The first isolated-baseline junction command failed argument binding; a native PowerShell path-based command corrected it. No product invariant was changed for these corrections.

## Evidence and remaining acceptance

Inspected captures: [inline label](evidence/track-rating-2026-10-10/after/race-complete-label-1280x720.png), [cloud prompt](evidence/track-rating-2026-10-10/after/cloud-rating-prompt-1280x720.png), [compact prompt](evidence/track-rating-2026-10-10/after/cloud-rating-prompt-960x540.png), [saved vote](evidence/track-rating-2026-10-10/after/cloud-rating-saved-1280x720.png). Actual [logs](evidence/track-rating-2026-10-10/logs) and [task-only Git patch](evidence/track-rating-2026-10-10/scoped-change.patch) are retained.

No phone attachment check or device test was performed. No APK export/install, full Validate, live rating writes, backend change or deployment was performed. Restart/rebuild the client to use the changes. Remaining acceptance: complete a previously unrated nonowned cloud track while signed in, observe delayed verification and Skip/retry on the actual connection, verify stars after reopening, and check the prompt on Android. If the player leaves the completed results before qualification arrives, no popup interrupts another screen; the inline row remains available when reopening that track. Server qualification still excludes artificial-only/public-ineligible completions and self-rating.


## Hidden prompt correction after the Ajorata report (RATE04)

The previous implementation still contained a rendering defect. `TrackRatingPrompt.layer = 8` put the modal below the actual `App.menu_layer.layer = 20`. Canvas layers do not inherit their parents' drawing order; the normal results' opaque backdrop completely covered the prompt and its menu also intercepted input. The original focused fixture put results directly on the root canvas and therefore did not exercise this condition. Its 24 passing checks were insufficient to establish visibility in the actual application hierarchy.

Corrected `game/ui/track_rating_prompt.gd` to derive a layer above its ancestor menu canvases (21 for the current app) rather than use an unrelated hardcoded value. `game/tests/test_track_rating_prompt.gd` now places its opaque results under the same layer-20 menu hierarchy. It checks the actual rendered panel pixel and drives Skip and the fourth rating star through native pointer events, as well as retaining the existing qualification, persistence, scope and lifecycle assertions. No eligibility, backend, uploads, race or scoring rules were altered.

Actual commands, pinned Godot 4.7.2 through the project entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/track-rating-layer-2026-10-10/before-capture'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/track-rating-layer-2026-10-10/after'
git diff --check -- game/ui/track_rating_prompt.gd game/tests/test_track_rating_prompt.gd
git apply --check --reverse docs/evidence/track-rating-layer-2026-10-10/scoped-change.patch
```

Before the layer correction, the strengthened fixture produced **26 checks / 3 failures**: wrong modal layer, missing modal panel in the rendered image and the intercepted Skip click. After the correction, the final native run produced **26 checks / zero failures**, including actual fourth-star selection and save confirmation. Inspected [hidden prompt before](evidence/track-rating-layer-2026-10-10/before-capture/cloud-rating-prompt-1280x720.png), [visible prompt after](evidence/track-rating-layer-2026-10-10/after/cloud-rating-prompt-1280x720.png), [compact landscape](evidence/track-rating-layer-2026-10-10/after/cloud-rating-prompt-960x540.png) and [saved vote](evidence/track-rating-layer-2026-10-10/after/cloud-rating-saved-1280x720.png). Actual [logs](evidence/track-rating-layer-2026-10-10/logs) and a [follow-up-only Git patch](evidence/track-rating-layer-2026-10-10/scoped-change.patch) are retained. No failing assertion was removed.

No live Ajorata race/rating or account data was read/written, no phone attachment check or device test was performed, and no APK export/install, backend change, deployment or full Validate was performed. The prior app99 pass and reproduced broader results-fixture failures were not rerun for this two-file presentation correction. Restart the desktop client or rebuild the installed client to load the correction; actual signed-in Ajorata and Android acceptance remain.


## Superseded by restored race-view placement and silent submission

The owner now explicitly keeps rating under the Race complete gantry in the race view and requires immediate continuation without waiting for rating feedback. The separate results popup described above is removed. Current implementation, tests and limits: [Instant finish rating](INSTANT_FINISH_RATING_2026_10_10.md).
