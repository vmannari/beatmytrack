# Publication confirmation and bounded wait — 2026-10-19

PCF01 adds the owner's irreversible-publication warning before any publication handoff. PCF02 keeps one owned window active with the existing loading animation for at most five seconds of waiting. PCF03 presents success, failure or an honest timeout and follows late acceptance. G01 reuses the existing modal and loading-menu presentation. R01 preserves exact saved revisions, account/navigation guards, consent, fresh server slot checks, durable request identities and receipts. Q01 requires original-source reproduction, real pointer input, native views and regression checks.

## Behavior

Authenticated Publish, from both Load track and the editor, first opens **Publish track?** with **After publishing, you cannot change this track. Make sure you’re happy with it before continuing.** Cancel closes it without a publication/consent request or draft modification. Guest sign-in guidance remains.

Confirm changes that same window to **Publishing track…**. It uses the same native indeterminate ProgressBar as the existing race-loading menu, without an invented percentage. Publish and X are disabled while waiting; repeated activation and Escape cannot dismiss it or submit twice. No additional status polling is introduced.

A public receipt immediately changes the existing window to **Track published**, including while local downloading/cleanup is still finishing. A definite admission/verification failure shows its actionable cause. Otherwise the monotonic **5,000 ms** deadline stops the animation and enables dismissal with **Publication not confirmed** and an explanation that checking can continue while the game stays open and online. This is a timeout of the foreground wait, not cancellation or replacement of a potentially accepted request.

If a late receipt arrives while the window is still open, its content becomes the success state. If it has been dismissed, the existing durable publication banner remains responsible for later acceptance. Success dismissal acknowledges the original receipt. When publishing the active editor snapshot, acknowledgement retains the original cleanup of that exact editor document/history and opens the public track; newer edits are preserved. Account, library, navigation and saved-document freshness are checked before consent/submission. Existing public-sharing consent remains required and uses its existing sheet if needed.

The consent helper now rejects a parent that has left the tree, been freed or is already queued for deletion after its asynchronous read. A delayed response cannot attach a sharing-rules sheet to a timed-out/dismissed publication window or initiate a publication through that stale window.

## Changed files

- `game/ui/publication_dialog.gd` and UID: publication-specific confirmation/wait/outcome behavior extending the original FaultDialog, its input scrim, palette, imagery, typography and layout.
- `game/core/app.gd`: both Publish entry points use the shared confirmation; only its explicit confirm signal starts the original publication adapter. Original ownership, fresh revision checks, result acknowledgement and editor handoff remain.
- `game/ui/community_safety_ui.gd`: one parent-lifetime guard after the asynchronous consent read.
- `game/tests/test_publication_confirmation.gd` and UID: real app callback, mouse/touch controls, real five-second deadlines, same-window state changes, failures, revision/identity/navigation fences, queued-deletion callback handling and editor handoff.
- Existing publication notice, notification and slot fixtures explicitly confirm the new warning and exercise the bounded wait before dismissal. Their authoritative receipt, original request, slot and notification checks remain.

## Actual validation

| Check | Actual result |
| --- | --- |
| New checks with archived original app script | Four checks; three expected failures: no warning, submission before consent, dismissible pending window |
| Final focused headless, including real deadlines and same-frame late consent reply | **61 checks, zero failures** |
| Native Compatibility, mouse/touch, layout and captures | **72 checks, zero failures** |
| Native desktop Mobile, mouse/touch, layout and captures | **72 checks, zero failures** |
| Existing publication notices | **75 checks, zero failures** |
| Existing durable publication notifications | **55 checks, zero failures** |
| Fresh slots/grants/retry path | **56 checks, zero failures** |
| Original local publication and physically driven creator lap | **31 checks, zero failures**; 2,605 ticks / 436 samples |
| Generic owned fault dialogs | **95 checks, zero failures** |
| Shared community safety | **23 checks, zero failures** |
| Full App composition | **141 checks, zero failures** |
| Complete parser and native editor import | **903 scripts, zero failures**; import passed |

The focused tests verify that a pending window is still locked at 4.6 seconds and becomes dismissible after the actual five-second deadline, without changing its original intent. Captures cover 1280×720, 960×540 and 480×720 windows. [Warning](evidence/publication-confirmation-2026-10-19/gl_compatibility/warning-1280x720.png), [animated waiting state](evidence/publication-confirmation-2026-10-19/gl_compatibility/waiting-1280x720.png), [success](evidence/publication-confirmation-2026-10-19/mobile/success-1280x720.png), [timeout](evidence/publication-confirmation-2026-10-19/gl_compatibility/timeout.png) and failure views use disposable fixture data and the existing menu artwork. Warning, waiting and timeout states were visually inspected.

Initial attempts are retained. The first combined scaffold patch failed its expected source-line check and applied nothing; it was corrected against the actual app base. Directly injecting mouse input into the embedded child viewport missed its controls and produced four fixture failures; adding mouse motion alone did not resolve routing. Using the root viewport and its embedded-window coordinate transform exercises real mouse/touch input and passes. The original failures and final runs are retained; no production input handling or invariant was weakened to accommodate the fixture. The final consent-lifetime run additionally verifies a response in the same frame its parent is queued for deletion.

Actual commands used pinned Godot 4.7.2, process-only PowerShell execution-policy Bypass and disposable workspace APPDATA:

```powershell
# BMT_PUBLICATION_APP_BASELINE selects the saved original app script for reproduction.
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_confirmation.gd -CommandTimeoutSeconds 150
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_confirmation.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence=res://../docs/evidence/publication-confirmation-2026-10-19/gl_compatibility' -CommandTimeoutSeconds 150
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_confirmation.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence=res://../docs/evidence/publication-confirmation-2026-10-19/mobile' -CommandTimeoutSeconds 150
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_notice.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_notifications.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_fault_dialog.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_community_safety.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 240
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path game --import
```

Actual logs, archived originals, synthetic native captures and the task-only source checkpoint are under `docs/evidence/publication-confirmation-2026-10-19/`. Current physics, compiler, publication evidence, request identities, server validation and cache budgets remain. Root Git metadata and unrelated concurrent work are preserved.

This is a local client change. Owner experience and physical-device appearance/workflow acceptance remain. No live publication, account/queue mutation, backend deployment, phone attachment check/device test or APK action was performed. The separate backend publication-speed rollout remains outside this client change.
