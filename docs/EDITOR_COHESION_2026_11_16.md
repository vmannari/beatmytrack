# Editor layout and object-flow revision

Owner feedback rejects the previous pass's visual composition as fragmented and asks specifically for object-menu, placement and reselection refinement. The earlier input fixes remain useful; passing regression counts did not establish a designed interface.

The revised composition has one continuous header for document identity, inline save state, history, view commands, Save/Test and document menu; the existing category rail; and one anchored contextual dock. Publish moves into the document menu. Guidance becomes a single line in the dock. Surface choices, modes and brush controls share that dock rather than floating at opposite screen edges.

Object browsing is temporary: opening Objects exposes the library, choosing an asset collapses it to placement controls, and the library can be reopened explicitly. Category and paging controls keep stable slots. The current asset must be revealed when opening the library, including after a responsive page-size change.

Object interaction contract:

- Press empty ground to preview the chosen object; drag to aim; release on exposed canvas to place. Repeat without reopening the library. Cancel, a second finger, or release over UI must create no edit.
- Tap an existing object to select it on release without placing a duplicate or creating history. A drag starting on that occupied tap pans rather than moving an unselected object.
- Selected objects expose their properties and copy/delete controls in the same dock. Press Place to continue with the selected object's actual kind, orientation, scale, width/profile/colour. Editing a selected object's orientation does not silently change an unrelated placement brush.
- Retain explicit Select, overlap cycling, group selection, keyboard input, undo/redo and all existing authoring admission checks.

Acceptance: native road/surface/object browsing/placement/selection views at 960×540 and 1280×720; consistent header and dock bounds; no separate save/guidance/camera/brush cards on the canvas; small jitter/cancel, repeated placement, occupied reselection, drag-to-place, Place-after-edit, overlap cycling and undo/redo sequences. Desktop rendering is not Android hardware qualification. The first source checkpoint and all known broader rendering/toolchain findings remain retained.

## EC01 — Workspace composition

`editor_layout.gd` owns the presentation. Existing controls and commands are reused in a single top bar and bottom dock; old floating-position formulas were removed from the forwarding layout functions. Save status is a subtitle beside the actual track name. View controls join history, Save and Test in the header. Publish remains available in the document menu. Guidance is a single line, and the scale ruler stays above the dock.

Surface materials, Free/Area/Line, brush size and advanced options now share the dock. Object placement and selected-object controls occupy the same bottom position; the picker expands temporarily and closes on choosing an asset. Property adjustment hides unrelated copy/delete/library controls and exposes all four orientation presets without clipping at both tested widths.

## EC02 — Object intent, selection and continuity

An occupied tap in Place mode selects on release. It does not create history or a duplicate. Moving that uncommitted occupied tap navigates instead of moving an unselected object. Explicit Select retains direct object dragging and overlap cycling. A drag from empty ground previews and aims the next object; release over the dock cancels rather than placing behind UI.

Place from a selection seeds the next stamp with the selected object's actual settings. The native fixture compares all encoded non-position fields for a coloured/scaled container, fractional-width speed bump, current and legacy jump, and custom-length barrier. `stamp_length` is transient editor state using the existing object `length` field; the saved-track format is unchanged. Selected-object rotation no longer changes an unrelated dormant brush. Group selection retains Copy and disables single-object Place until there is one selected item.

Picker paging keeps both arrow slots fixed, disables unavailable directions, retains a visible active family when page size changes, and reveals the current family on reopening. Category tabs and utility buttons use quieter styling; no new image assets or dependencies were introduced.

## EC03 — Native review and validation

| Check | Result |
|---|---|
| New composition/object-flow sequences, Compatibility | **223 / 0** |
| Same sequences, desktop Mobile | **223 / 0** |
| Existing construction/workflow | **253 / 0** |
| Existing surface modes | **53 / 0** |
| Retained interaction regressions | **155 / 0** |
| Previous UX/recovery/practice sequences, headless | **124 / 0** |
| Production parser | **583 scripts / 0 failures** |
| Native evidence | **35 PNGs**, seven before and fourteen per desktop renderer |

All App tests use isolated fixture storage and offline transport. Native input sequences cover selection-only taps, deliberate object dragging and cancellation, drag-to-aim/release, release over UI, selected-property continuation, full-row adjustment controls and Undo/Redo. The preceding source checkpoint, six broader kerb-vertex findings and existing translation-authoring tab/pipe mismatch remain retained; they are not silently replaced with a global green claim.

The original occupied-tap and large-drag expectations were updated to the owner's refined interaction model. The surface suite's oil check now verifies the collapsed object controls, actual Place mode and oil kind, rather than expecting the browser to stay open. No geometry, equality, history, capacity or safe-bound assertion was relaxed.

Development attempts retained: the first capture fixture compared an Array to a Dictionary; its exact-document comparison was corrected. An interaction run caught selected dragging being cancelled by picker closure and clipped rotation actions. Selection refresh now preserves the owned pointer, and property adjustment receives the full dock width. The complete interaction and native sequences pass after those corrections.

Before: [surface controls](evidence/editor-cohesion-2026-11-16/before/04-surface-preview-1280.png), [compact objects](evidence/editor-cohesion-2026-11-16/before/06-objects-960.png).

After: [surfaces](evidence/editor-cohesion-2026-11-16/gl_compatibility/02-surfaces-1280.png), [compact surfaces](evidence/editor-cohesion-2026-11-16/gl_compatibility/02-surfaces-960.png), [object picker](evidence/editor-cohesion-2026-11-16/gl_compatibility/03-object-picker-1280.png), [placement](evidence/editor-cohesion-2026-11-16/gl_compatibility/04-object-place-960.png), [selection](evidence/editor-cohesion-2026-11-16/gl_compatibility/05-object-selected-960.png), [orientation](evidence/editor-cohesion-2026-11-16/gl_compatibility/07-object-orientation-960.png).

Actual engine entry points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_cohesion_2026_11_16.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_cohesion_2026_11_16.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_interactions_2026_11_14.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_ux_2026_11_16.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_workflow.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_surface_modes.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_shipping_parse.gd -CommandTimeoutSeconds 240
```

## EC04 — Reviewable source and limits

Changed runtime files: `editor_layout.gd`, `editor_style.gd`, `editor_canvas.gd`, `object_browser.gd`, `object_properties.gd`, `view_state.gd` and `core/features/editor.gd`. Regression fixture changes are scoped to the interaction contracts above. Prior App/header, vehicle and generated-version work is preserved. The [delivery receipt](evidence/editor-cohesion-2026-11-16/delivery.json), [raw validation logs](evidence/editor-cohesion-2026-11-16/validation/), [source fence](evidence/editor-cohesion-2026-11-16/validation/source-fence.json) and [image hashes](evidence/editor-cohesion-2026-11-16/native-images.json) retain the actual results.

`python scripts/checkpoint_editor_cohesion.py` creates the [private source checkpoint](evidence/editor-cohesion-2026-11-16/source-checkpoint.json) and [reversible patch](evidence/editor-cohesion-2026-11-16/source.patch), with byte-exact forward/reverse application and no shared-index staging. Standard build retention ran through the dev entry point; recent/protected work remains, and no task pin was added.

Owner appearance acceptance remains pending: this follow-up records the rejection of the earlier composition instead of treating functional test counts as visual approval. Android hardware, effective dp sizing, finger occlusion and sustained performance remain untested. No owner save/process, export, real publication/service request or deployment was performed. Reload the client to inspect the current code.
