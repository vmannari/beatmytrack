# Track editor interaction fixes

The seven issues in the [usability assessment](TRACK_EDITOR_USABILITY_ASSESSMENT_2026_11_14.md) are fixed locally. Tool state is explicit, routine toolbar actions preserve unfinished work, and selecting or adjusting a component acts on the intended target. Ordinary tool guidance is also visible.

## Changed behavior

| Requirement | Result |
| --- | --- |
| EUI01 Preserve unfinished work | Reselecting Area and opening Map retain the preview. Passive focus changes cancel the pointer transaction without discarding a completed preview. Changing paint modes or choosing a hazard with pending paint offers Confirm, Discard and Cancel. Explicit Cancel still removes the preview. |
| EUI02 Separate placement settings from existing objects | Placement clears the editable-object selection. Rotation and container-color handlers also require object-selection mode before changing existing objects. Selected-object rotation remains an undoable edit. |
| EUI03 Pick the intended road | Picking ranks actual road containment and projected centerline distance, using complete segments and the joined section outline. A neighboring road can beat the enlarged hit region around an existing handle; clicking the handle itself still selects it. Coincident ties remain deterministic, and Layer reaches overlapping candidates. Picking geometry uses the existing bounded canvas cache. |
| EUI04 Keep placement predictable | Select and Place are explicit buttons in the object control strip. Clicking an occupied object while placing keeps Place active and points to Select. The next empty-ground click still places the chosen asset. Reselecting the active mode preserves its state and indicator. |
| EUI05 Distinguish selection from dragging | Object movement requires six screen pixels of deliberate travel. Snapping applies to the movement delta, preserving an off-grid object's unmoved axis and group spacing. A movement blocked by the map boundary creates no edit transaction. |
| EUI06 Make Escape consistent | During a gesture, Escape rolls back that gesture and releases pointer capture. Otherwise it clears selections and disarms placement, start placement or surface authoring. Surface authoring returns to navigation until a paint mode is chosen again. Repeated key echoes do not perform a second cancellation. |
| EUI07 Constrain shortcuts | Tab cycles objects in object-selection mode and roads in road mode; it cannot change Surfaces to Track. Cycling cannot discard a road preview. The start-line shortcut retains an unfinished surface preview in its own tool state. |
| EUI08 Show guidance | Normal instructions remain visible. Temporary hints restore the current guidance when they expire. Guidance stays clear of the tool rail at both tested viewport sizes. |

The new guidance messages have authored translations in all 12 approved languages. Existing unrelated translations are preserved; only three messages are appended to each catalogue and the source inventory.

## Verification

| Check | Actual result |
| --- | --- |
| New regression through `scripts/dev.ps1`, headless | 154 checks, zero failures |
| New regression, desktop Compatibility | 158 checks, zero failures; four native captures |
| New regression, desktop Vulkan Mobile | 158 checks, zero failures; four native captures |
| Existing full editor workflow | 254 checks, zero failures |
| Existing editor session and gesture suite | 305 checks, zero failures |
| Exportable production parsing | 570 scripts, zero failures |
| Three-message source/catalogue validation | 75 checks, zero failures |
| Runtime translation resources | All three messages present in 12 languages, with authored non-English copy; included in the regression counts |
| Pinned editor import | Exit 0 |

The regression uses the actual App, viewport mouse/keyboard input, native-touch canvas events, disposable validated documents, draft recovery and Undo. It exercises the next click after a transition, not just the immediate mode value. The reviewed runtime sources match across all three accepted runs and remain stable within each run.

Native views: [Place active](evidence/editor-interaction-fixes-2026-11-14/compatibility/01-place-mode.png), [Select active](evidence/editor-interaction-fixes-2026-11-14/compatibility/02-select-mode.png), [area retained after toolbar actions](evidence/editor-interaction-fixes-2026-11-14/compatibility/03-area-preserved.png), [road guidance](evidence/editor-interaction-fixes-2026-11-14/mobile/04-road-guidance.png). [Verification and source-checkpoint receipt](evidence/editor-interaction-fixes-2026-11-14/verification.json).

The initial regression rejected the original editor with six direct-input failures and 21 App-sequence failures. Intermediate attempts exposed handle priority still overriding the neighboring road and an untyped empty-array branch during road-preview interaction; both were corrected. A later boundary probe compared float coordinates with an integer array and falsely failed despite zero movement and zero transactions; the expected numeric types were corrected. The original logs remain in the evidence folder.

The historical workflow fixture did not await lazy editor entry and initially accessed a null canvas/world. Its setup now awaits that entry. All 254 existing workflow assertions are retained. No production invariant was removed or relaxed.

The broad translation-authoring unittest remains blocked by the unchanged `scripts/translations/track_editor_review_fixes.tsv`, line 1, which its parser reads as one field instead of 12. The task's three-row sheet is checked independently and its imported resources pass the native checks above. This is not a whole-catalogue or whole-repository clean-suite claim.

## Files and commands

Production changes are in [EditorCanvas](../game/editor/editor_canvas.gd), [editor composition](../game/core/features/editor.gd), [object properties](../game/editor/object_properties.gd), and the App's one-line focus-cancellation call. Tests are [the new regression](../game/tests/test_editor_interactions_2026_11_14.gd) and the workflow fixture's awaited entry. The three-message translation sheet, 12 catalogues, source inventory and this report complete the authored scope. Generated build identity refreshes are separate from the source checkpoint. Concurrent model, preparation and repository work is preserved.

The pinned engine is `4.7.2.stable.official.ed1daf0bf`. The preferred accepted command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 `
  -Action TestScript `
  -ScriptPath res://tests/test_editor_interactions_2026_11_14.gd `
  -CommandTimeoutSeconds 240 `
  -TestArgument '--review-out=C:/Codes/Godot/Beat my track/build/editor-interaction-fixes-2026-11-14/accepted-headless'
```

Each test process assigns `APPDATA` and `LOCALAPPDATA` to a task-owned profile under `build/`, clears `BMT_API_URL` and `BMT_DEV_AUTH_KEY`, and redirects App draft/record/cloud storage into the workspace. Direct runs use the same exact pinned console executable with `--path game --script`, adding `--headless`, `--rendering-method gl_compatibility`, or `--rendering-method mobile --rendering-driver vulkan`. The retained workflow, session and parser scripts are `test_editor_workflow.gd`, `test_editor_t11_t15.gd`, and `test_editor_shipping_parse.gd`. [Accepted logs and receipts](evidence/editor-interaction-fixes-2026-11-14/verification.json) retain their outcomes.

The [task-only source patch](evidence/editor-interaction-fixes-2026-11-14/task.patch) is checked forward and backward against the captured task-start files with normalized line endings. The new regression reuses the preserved assessment's fixture helper. No main-index staging, commit, merge, owner-process restart or owner-save action was performed.

## Remaining acceptance

Restart or reload the game to use the edited scripts. Owner interaction acceptance, physical-phone gestures, translated layout on devices and large/dense-map latency remain separate checks. Desktop Vulkan Mobile is a desktop renderer result. This task makes no phone-performance or whole-project readiness claim.

No physical-device test or attachment query, APK/export, live backend operation, external share or deployment was performed. The prescribed build-retention cleaner runs at closeout; task profiles and intermediate output stay disposable under that policy. Permanent evidence contains the accepted native views, concise logs, receipts and source patch rather than profiles or project copies.
