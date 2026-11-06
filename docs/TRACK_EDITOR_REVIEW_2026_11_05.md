# Track editor review — 5 November 2026

Historical review. These findings are corrected in the
[implementation report](TRACK_EDITOR_FIXES_2026_11_05.md). The original review
observations below are retained; this review itself changed no runtime code.
Requirements TER5-01 through TER5-03 cover discard/recovery, title history, and
draft copying. TER5-Q01 covers reproduction, existing regressions, and scope.

## Findings

### TER5-01 / P2 — Discard can retain and resurrect the rejected edits

In `game/core/features/editor.gd:1568`, the Discard callback deletes the WIP,
clears previews, and navigates. It neither retires pending analysis/writes before
deletion nor restores the document/history to the saved original. Unlike Close,
Load opens this dialog without first flushing the queues (`:1590`). Navigation
then flushes them in `game/core/app.gd:557`.

Reproduction: save a track, move an object, choose Load, then Discard while
autosave is pending. The real App probe retained the original object at x=40,
but recreated the WIP with the rejected object at x=45. App polling was paused
only to hold this ordinary pending-work window deterministically; actual save,
dialog, navigation, and storage implementations ran unchanged.

A settled control establishes a second part of the same issue: the WIP was
successfully deleted, yet pressing Back in Load reopened the rejected object
position (x=43) and reported unsaved changes. This part requires no timing race.

Retire or fence queued revisions before deleting recovery data, then restore
the saved original (or clear a never-saved document) and its associated session
state before navigating. Cover both pending and completed autosaves.

### TER5-02 / P2 — Renaming leaves an obsolete redo branch active

`game/core/features/editor.gd:2116` changes `document.name` and saves it without
calling the session's history method. A rename therefore has no undo checkpoint
and does not clear redo history, unlike other committed edits.

Reproduction: move an object, Undo, rename the track, then Redo. After renaming,
the probe observed zero undo entries and one redo entry. Redo changed
“New review name” back to “Saved baseline” while reapplying the object move.
The title edit is silently lost. Route a changed name through the same history
transaction as other document edits.

### TER5-03 / P2 — Save as new track rejects valid long names

`game/core/features/editor.gd:1628` appends ` copy` to the existing name without
respecting the 40-character document limit. The Load screen exposes this action
for publication revision conflicts through `game/ui/draft_browser.gd:238`.

A valid 40-character source became a 45-character document; `save_wip` rejected
it, no new draft was stored, and the UI stayed on Load. A 35-character source
produced a valid 40-character copy and opened successfully. Names of 36–40
characters hit this boundary. The failure also leaves `app.document` pointing
at the invalid, unsaved copy because it is assigned before persistence succeeds.

Bound the generated name before saving and install the copied document only
after a successful write.

## Validation

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All runs used headless Godot,
Dummy audio, and workspace-specific APPDATA. They did not use owner saves.

| Check | Actual result |
| --- | --- |
| Existing editor workflow | 254 checks, 0 failures; exit 0, including final offline rerun |
| Existing T11–T15 transaction, gesture, format and worker checks | 305 checks, 0 failures; exit 0 |
| Existing save/recovery review suite | 69 checks, 0 assertion failures; exit 0, but a Garage dummy-texture initialization error and one leaked texture RID were emitted |
| Focused actual-App probes | Both complete runs exit 0 and reproduce all three defects; final run adds settled-discard and shorter-name controls |

The probe records observations; its exit 0 means it completed, not that the
observed editor behavior is correct. No existing assertion was removed or
weakened. The save/recovery suite is not classified as a clean runtime pass.
All engine runs retained the sandbox's certificate-store diagnostic.

The initial private `backend.cfg` did not establish offline mode: the first
probe stopped at its explicit offline guard. The fixture was corrected to
write the configuration through Godot's ConfigFile before App startup; both
completed probes verify `online.configured == false`. Earlier workflow startup
could attempt the default loopback service; no production/backend isolation
claim is made for that initial attempt. The workflow was rerun after correction.

Commands, logs, observations, the final probe source, and current source hashes
are in [the evidence directory](evidence/track-editor-review-2026-11-05/).
For example, with APPDATA set to the workspace test profile and the offline
configuration installed:

```powershell
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_editor_workflow.gd --log-file "$reviewRoot/workflow-offline.log"
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_editor_t11_t15.gd --log-file "$reviewRoot/transactions.log"
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_editor_review_fixes.gd --log-file "$reviewRoot/save-recovery-offline.log"
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://../build/track-editor-review-2026-11-05/review_probe.gd --log-file "$reviewRoot/probes-controls.log"
```

Direct pinned-engine invocations avoid the development wrapper's generated
build-identity changes during this review. The exact test command records are
also stored in `commands.json`.

## Scope and remaining acceptance

Review artifacts are the only additions. Existing work, including the pending
startup/loading changes and untracked feature controller, is preserved. Source
hashes identify the reviewed files at evidence capture; this is not a frozen
whole-workspace or original-versus-candidate performance comparison.

No phone/device query or test, native graphical capture, APK, purchase,
authentication, publication, deployment, owner-process restart, or main-index
write was performed. This review does not establish current appearance, touch
feel, cold loading, or device performance. The linked implementation report records the fixes and their regression tests.
The headless Garage diagnostic remains outside those fixes.
