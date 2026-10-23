# Track editor returns to its Create page — 2026-10-18

ERT01: Closing the track editor returns to the Create page that opened it: Select biome for a new track, or Load track for an existing draft. Clean close, Save and Discard share this destination. Cancel stays in the editor; save errors still prevent an acknowledged departure.

ERT02: Load track retains its search and selected draft after the asynchronous rescan. It retains the page when ordering is unchanged; if saving moves the selected draft in the existing modification-time order, its new page is shown. The optional narrow-layout scroll position is also retained. Closing an editor entered through another editor's Load action makes the browser's Back action return to Select biome, avoiding an editor/browser loop. State is bounded to one return view and scoped to the current library directory. Editor rebuilds and existing practice returns keep the original parent.

The cause was two unconditional Race destinations in `_request_editor_exit`. Changed runtime files are `game/core/app.gd` and `game/ui/draft_browser.gd`. `game/tests/test_app.gd` now exercises both parents, clean/Save/Discard/Cancel, non-default search/page/selection, save-time reordering and nested Load/Back. The historical Race destination assertions in `game/tests/test_editor_review_fixes.gd` and `game/tests/profile_editor_review_pass.gd` now assert Create. Original persistence/failure assertions remain.

Godot 4.7.2 checks completed:

| Check | Result | Log |
| --- | --- | --- |
| Final app, headless | 140 checks, 0 failures | `evidence/editor-return-2026-10-18/logs/headless-final.log` |
| Final app, native Compatibility, 1280×720 | 158 checks, 0 failures | `evidence/editor-return-2026-10-18/logs/native-final.log` |
| Existing editor save/gallery regressions, including failed final writes and retry | 69 checks, 0 failures | `evidence/editor-return-2026-10-18/logs/save-regression.log` |
| Final whole-project parser | 860 scripts, 0 failures | `evidence/editor-return-2026-10-18/logs/parser-final.log` |

The initial headless app run passed 136 checks. The first native run failed one of 154 checks: saving in a later timestamp second moved the selected draft off the restored page, and the browser selected a different draft. Restoration now follows the selected ID to its actual filtered page. The final test deliberately waits 1.1 seconds before saving so both runs exercise that reorder. This corrects runtime behavior rather than dropping the selected-track assertion. Initial native log and captures remain under the evidence directory.

Actual test invocations used the repository entry point from the repository root. Each process set `APPDATA` and `LOCALAPPDATA` to dedicated subdirectories of `build/editor-return-2026-10-18`; app fixtures also inject their own records/library/cloud paths. Relevant command arguments were:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--capture-app-flow=C:\Codes\Godot\Beat my track\docs\evidence\editor-return-2026-10-18\compatibility-final" -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_review_fixes.gd -TestArgument '--review-evidence=build/editor-return-2026-10-18/save-regression' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/core/app.gd game/ui/draft_browser.gd game/tests/test_app.gd game/tests/test_editor_review_fixes.gd game/tests/profile_editor_review_pass.gd
```

The save-regression script ignores the supplied evidence argument and writes to `build/editor-review-fixes-2026-10-14/gl_compatibility-track_46139348ff2bcdc9b10e898bce408796`; the complete output is archived in its task log. Direct `scripts/dev.ps1` execution first hit the host execution policy. The explicit PowerShell invocation then hit sandboxed user-log access; redirecting test data resolved that, after which the engine could not read the Windows certificate store. The isolated tests completed with approved execution outside the sandbox. No project trust/certificate settings were changed.

Native captures were reviewed:

- [Returned Select biome](evidence/editor-return-2026-10-18/compatibility-final/editor-close-biome.png)
- [Filtered Load track before editing](evidence/editor-return-2026-10-18/compatibility-final/editor-close-drafts-before.png)
- [Selected draft in the editor](evidence/editor-return-2026-10-18/compatibility-final/editor-close-drafts-editor.png)
- [Returned Load track with the saved draft selected](evidence/editor-return-2026-10-18/compatibility-final/editor-close-drafts-after.png)

G01/R01/Q01: Desktop navigation and persistence regressions pass. Owner workflow acceptance and physical-device behavior remain. No phone attachment check or device test, APK, backend change or deployment was performed. Narrow-layout scroll restoration was not independently asserted. Concurrent workspace changes were preserved. Task preimages, final hashes and a task-only review patch are stored in `evidence/editor-return-2026-10-18`; this patch is relative to the task's starting workspace, including its existing uncommitted work.
