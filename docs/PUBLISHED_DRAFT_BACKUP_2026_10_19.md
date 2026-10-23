# Published Ancient retained in Drafts — 2026-10-19

PDB01 removes a transferred track's obsolete recovery copy from the draft list. R01 preserves all recovery bytes, newer edits, ordinary crash recovery, owner storage and publication identities. Q01 requires reproduction on original code, actual read-only Ancient inspection and rendered/regression checks.

## Finding and change

Ancient's existing local journal is already `published`, with a durable public receipt and cached published document. Its current saved original and autosave have been retired. An older saved `.json.bak` remains, differs in its objects, matches an earlier local-ready journal and predates the `.backend` publication binding. The draft scanner treats `.bak` as a recoverable document when the primary is absent, so this older revision reappeared as a draft. Publication itself had succeeded; no second publication or slot is needed.

`game/persistence/track_library.gd` now excludes an older orphan `.json.bak` from `editable_entries`, including its summary/threaded scan, when a complete existing backend binding confirms the transfer. A primary or temporary file prevents suppression, as does recovery written after the binding. Missing, incomplete, corrupt or oversized binding data keeps normal recovery visible. The check runs within the already selected library/account directory and makes no network requests or file writes.

The backup remains physically intact and explicit recovery reads still work. Current originals, newer autosaves, unreadable-primary recovery and interrupted saves remain editable. This also handles already completed publications such as Ancient without changing its saved journal, re-verifying, republishing, manually deleting files or consuming another slot.

The owner's actual library was scanned read-only through both the archived original and the final implementation: the original returns **one Ancient draft**, the final returns **zero**. The remaining backup's SHA-256 is unchanged in each run. Private source paths, receipt identifiers and diagnosis remain in ignored `build/ancient-draft-diagnosis/`; no player track content is included in this report's screenshots.

## Actual validation

| Check | Result |
| --- | --- |
| Original library against new retirement checks and actual read-only Ancient scan | 11 checks, three expected failures reproduced; original lists Ancient once |
| Final focused headless, including actual Ancient read-only scan | 37 checks, zero failures |
| Final Compatibility native UI and captures | 39 checks, zero failures |
| Final desktop Mobile native UI and captures | 39 checks, zero failures |
| Existing local publication / physically driven creator lap | 31 checks, zero failures; 2,605 ticks, 436 samples |
| Existing publication badges / retained controls | 25 checks, zero failures |
| Existing editor workflow | 252 checks, zero failures |
| Existing App composition | 141 checks, zero failures |
| Existing failed-save/editor recovery regression | 69 checks, zero failures |
| Complete parser | 900 scripts, zero failures |

The focused fixture creates genuinely different original/autosave backups through the normal atomic writer and runs the existing publication cleanup before scanning. It verifies both full and summary enumeration, real DraftBrowser removal, preservation of a newer unpublished edit, unbound backups, a corrupt primary, a pending temporary save, incomplete binding and post-publication recovery. [Empty published-draft list](evidence/published-draft-backup-2026-10-19/gl_compatibility/published-removed.png) and [newer edit retained](evidence/published-draft-backup-2026-10-19/mobile/newer-edit-preserved.png) use a disposable oval named Ancient, rather than the owner's actual circuit. The empty and newer-edit states were inspected.

Initial attempts are retained in the evidence: the first original-source test reached the intended two scanner failures, then its untyped archived library could not be assigned to the browser's typed current-library property. The corrected baseline stops before that incompatible UI harness and separately exercises the actual read-only owner scan, producing the three intended failures. Initial restricted runs also reported the Windows certificate-store access error; approved host-access final runs are clean. The first capture helper read the project default renderer rather than the command-line override, so renderer folders overlapped; explicit per-run capture labels and both final graphical reruns retain separate evidence. No runtime check or failing invariant was weakened.

Actual commands used pinned Godot 4.7.2 via `scripts/dev.ps1`, process-only execution-policy Bypass and disposable workspace APPDATA:

```powershell
.tools/backend-venv/Scripts/python.exe build/inspect_ancient_draft.py
# BMT_PUBLICATION_BACKUP_BASELINE selects the archived library with its duplicate class_name removed.
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_published_draft_backup.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_published_draft_backup.gd -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_published_draft_backup.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--capture' -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_published_draft_backup.gd -Graphical -RenderingMethod mobile -TestArgument '--capture' -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_badges.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_workflow.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_review_fixes.gd -CommandTimeoutSeconds 300
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 240
```

`BMT_ANCIENT_DIAGNOSIS` points only to the ignored private diagnosis for optional read-only owner checks. `BMT_BACKUP_CAPTURE_RENDERER` selects each capture folder. The save-regression script writes its own existing evidence directory under `build/editor-review-fixes-2026-10-14/`, as recorded in its log. Actual logs, archived original library, synthetic views and the task-only source checkpoint are in `docs/evidence/published-draft-backup-2026-10-19/`. Changed runtime scope is one local library function/call site plus the focused test and UID; root Git metadata and concurrent work remain intact.

The fix is local client source. A currently running client must load the updated source; owner/device workflow acceptance remains. No live publication, account/queue mutation, backend deployment, phone attachment check/device test or APK action was performed. The owner's recovery file was read, never modified or removed.
