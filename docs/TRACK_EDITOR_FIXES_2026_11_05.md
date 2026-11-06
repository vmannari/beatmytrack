# Track editor review fixes — 5 November 2026

TER5-01, TER5-02, TER5-03 and TER5-Q01 from the
[review](TRACK_EDITOR_REVIEW_2026_11_05.md) are complete locally.

Discard now drains outstanding analysis and writes before deleting recovery
files. It reloads the saved original and starts a clean editor session, so Back,
Undo and Redo cannot restore rejected changes. A never-saved draft is cleared.
An unreadable original or failed deletion keeps the current editor and recovery
data available, with the existing error notice. The confirmation dialog hides
before an error notice opens, avoiding competing exclusive dialogs.

Renaming records one history step and clears the previous redo branch. Undo
and Redo restore the corresponding title and geometry. Applying the same
trimmed name preserves history. Editing a title in the Save dialog follows the
same rule.

Save as new track reserves five characters for the existing ` copy` suffix,
keeping the result within the 40-character limit. Unicode names are bounded by
characters. The copy is installed in App only after persistence succeeds, so a
failed write preserves the current document, history and navigation.

## Files and validation

Runtime changes are confined to `game/core/features/editor.gd`. The new
`game/tests/test_editor_review_2026_11_05.gd` exercises real App dialogs,
navigation, session history and isolated local files. The review status and
the AGENTS/development summaries link to this report.

| Check | Actual result |
| --- | --- |
| New focused suite, headless | 96 checks, 0 failures, exit 0 |
| New focused suite, native desktop Compatibility | 99 checks, 0 failures, exit 0; three native captures |
| Same focused suite using the archived original controller | 96 checks, 34 failures, exit 1 |
| Retained editor workflow, headless | 254 checks, 0 failures, exit 0 |
| Retained T11–T15 session/gesture/import/worker suite, headless | 305 checks, 0 failures, exit 0 |
| Retained save/recovery review suite, native desktop Compatibility | 70 checks, 0 failures, exit 0 |

The five accepted runs total **824 assertions / 0 failures**. The archived
controller remains a failing control, not an accepted run. The focused suite
holds actual analysis/writer queues and a real unfinished writer at the discard
boundary. It also covers completed saves, hidden road/surface previews,
never-saved documents, deletion failure, corrupt original files, rename after
Undo, no-op rename, Save-dialog naming, 35/36/40-character Unicode source names,
and copy-write failure. No existing invariant or assertion was weakened.

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Direct invocations use private
workspace APPDATA, disabled backend configuration and Dummy audio. The focused
suite verifies that the actual App is offline before editing. The existing
development wrapper generates build identity; direct pinned-engine calls avoid
changing concurrent build metadata during these tests. Actual command arguments,
exit codes, logs and source hashes are retained in
[the evidence directory](evidence/track-editor-fixes-2026-11-05/).

Representative command, with the private APPDATA already selected:

```powershell
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_editor_review_2026_11_05.gd --log-file "$fixRoot/headless-corrected-fixture.log"
```

The native variant omits `--headless` and adds
`--rendering-method gl_compatibility --rendering-driver opengl3`.
`BMT_EDITOR_FIX_OUTPUT` selects the evidence/capture directory. `-- --before`
selects the archived task-start controller; the assertions are unchanged.

The three actual engine views were inspected:
[restored original](evidence/track-editor-fixes-2026-11-05/native/discard-restored-original.png),
[redone rename](evidence/track-editor-fixes-2026-11-05/native/rename-redone.png), and
[copied long name](evidence/track-editor-fixes-2026-11-05/native/copied-long-name.png).
They show the existing editor presentation; this task adds no layout or art.

## Initial findings and limitations

The first fixture assigned an absent `creator` key using dictionary dot syntax,
which produced an unsupported key type. Its rejected saves caused cascading
fixture failures. The test now uses the same string-key assignment as the
production creator stamp. The original failing log and the diagnostic rerun
remain recorded. These runs are not counted in the accepted total. The failure
path also exposed the competing-dialog error corrected above; the archived
controller reproduces it.

Every engine log retains the sandbox certificate-store startup diagnostic.
Accepted runs have no other runtime or shutdown diagnostics. The headless
Garage texture issue from the review was not modified by these editor fixes;
the retained save suite passes cleanly apart from the certificate diagnostic
when run through native Compatibility.

These are local desktop results, with no latency/FPS or phone-performance claim.
Reload/rebuild and owner/device acceptance remain. No device query/test, APK,
owner-save/process change, real authentication, live/backend request,
publication, deployment or main-index write was performed. Concurrent work is
preserved. A task-only source/documentation patch against the recorded task-start
copies is retained and reverse-checked against the completed workspace.
