# Editor space, naming and material controls — 2026-11-17

The owner rejected the preceding composition as cramped. This revision supersedes its sizing and material presentation, while retaining the tested object placement/reselection transactions. These are design hypotheses assessed in the actual App, not verified player behaviour.

## Plan before implementation

| ID | Finding | Change and acceptance | Priority / risk | Components |
|---|---|---|---|---|
| ES01 | The dock starts at x124 while the header starts at x16. Its separate heading wastes a row, especially with the object picker. | Both bars use identical side insets. Ordinary tools occupy one compact row, with brief feedback only when useful. Picker uses categories plus one asset row, with Close in its category row. Header target 56 logical units; picker <=144; surfaces <=88. All interactive targets remain >=48. | P0 / medium layout | editor_layout, object_browser, object_properties |
| ES02 | Name, permanent pencil and autosave subtitle compete with history and track space. “My circuit” looks like an authored title even for an unnamed draft. | One document-name button opens naming; no separate pencil. Display “New track” for the existing unnamed sentinel, without rewriting saved names or track format. First Save asks for a name; cancellation leaves the draft intact. Save status moves inline beside Save. Rename remains undoable. | P1 / medium save feedback | editor_layout, features/editor |
| ES03 | Tiny framed terrain drawings look inconsistent, and winter/desert materials reuse misleading imagery. | Replace terrain miniatures with consistent flat material swatches, actual biome pigment, restrained material pattern and readable labels. No shadows or stacked-block framing. Selected state belongs to the whole button. | P1 / low | editor_button, surface_labels |
| ES04 | Compact layout must retain object intent, model previews and advanced controls. | Preserve temporary picker, family reveal, fixed paging slots, drag-to-aim, occupied reselection, exact Place settings, Undo/Redo and four orientation presets. Check native 1280x720, 960x540 and wide landscape, then workflow/surface/parser regressions. | P0 / medium | native presentation fixture, existing regression suites |

The bottom dock is a single workspace shelf. Categories remain on the left rail; its selected state provides the category heading. Ordinary tool actions and object properties share one horizontal row. Guidance uses a small supplementary line only when a real instruction or error needs it. Object browsing temporarily replaces that row and collapses on asset choice. Material swatches and painting controls share the same shelf. Track construction, serialization, geometry and input ownership are unchanged.

Cancellation and undo follow the existing interaction model: a press shows an uncommitted placement; drag aims; release commits once; release over UI, a second pointer, focus loss or cancellation discards the pending placement. An occupied tap selects rather than duplicates. Property edits create the existing history transactions. Naming changes only on confirmation and enters history; dismissing either name dialog leaves the document unchanged. Save errors remain visible with Retry.

## Implemented interaction model

ES01: the shelves now share x16 / right16 insets. The header is 56 units high, including 48-unit actions. Object browsing has a 48-unit category row and a 72-unit asset row. Close sits beside Snap and Populate; the redundant Objects heading is gone. The ordinary surface and object placement shelves are 64 units high. The selected object's name remains at the start of the row. Orientation adjustment retains its numeric field and all four presets. The rail centres between the shelves and clears the expanded picker.

Guidance and errors use a supplementary row when needed: road construction, Move view, an active hint, loading or save failure. Save Retry remains visible even while browsing objects. Routine autosave state sits beside Save in the header. Existing selection, cancellation, aiming, snapping, object parameter continuation, history and test-drive commands are reused.

ES02: the whole document title is a 200x48 naming control, with a small decorative edit mark; the separate pencil target and subtitle are removed. The existing unnamed sentinel displays as **New track**. Opening naming presents an empty field for that draft; empty confirmation is disabled. Cancellation does not change the document or history. Naming is undoable. First Save uses **Name your track**; subsequent Save updates the named track. A previously saved track actually called **My circuit** retains its title and does not get forced through naming again. The naming dialog no longer repeats its heading inside the form. Long names ellipsize and retain their full tooltip. No stored name or schema is silently migrated.

ES03: surface controls use flat rounded material swatches, subtle grain/blades/ripples, actual biome pigments and adjacent labels. The whole control carries selection feedback. The Surfaces rail illustration is replaced with the existing clean layer glyph. Materials anchor left and painting controls anchor right, with Options at a stable right inset. Brush size, modes and options fit on the same row. Material IDs, brush operations and track appearance are unchanged. Object previews retain the actual mesh builder, preserve image aspect ratio, and distribute evenly across the available shelf; cache bounds and render resolution are unchanged.

## Before and after

Measured logical units in the native 960x540 views; desktop scaling does not establish Android dp:

| Element / task | Before | After |
|---|---|---|
| Header | 68 high; title + status + separate pencil | 56 high; one document control, inline save state |
| Object picker | 216 high; x124 left inset; three rows | 132 high; x16 left inset; two rows |
| Surface shelf | 130 high; x124 inset; heading plus tools | 64 high; x16 inset; one tool row |
| Object placement shelf | Separate heading above controls | 64 high with object name and controls |
| Picker categories at 960 | Buildings clipped by oversized snap selector | All seven category tabs visible in the English fixture |
| First naming | Placeholder looked like an authored title; repeated modal heading | New track; empty initial field; single modal heading |
| Already saved “My circuit” | Save unnecessarily asked for a name again | Save retains its real name |
| Object choosing / reselection | Existing two-tap category -> asset flow | Same tap count; picker collapses and occupied taps select |

The surface view gains 78 vertical units between the bars (318 -> 396); the picker view gains 96 (232 -> 328). These are workspace measurements, not measured player speed.

Before: [objects](evidence/editor-space-2026-11-17/before/03-object-picker-960.png), [surfaces](evidence/editor-space-2026-11-17/before/02-surfaces-960.png).

After: [objects](evidence/editor-space-2026-11-17/gl_compatibility/03-object-picker-960.png), [surfaces](evidence/editor-space-2026-11-17/gl_compatibility/02-surfaces-960.png), [winter](evidence/editor-space-2026-11-17/gl_compatibility/08-materials-winter-960.png), [selected object](evidence/editor-space-2026-11-17/gl_compatibility/05-object-selected-960.png), [naming](evidence/editor-space-2026-11-17/gl_compatibility/11-rename-960.png).

## Validation

| Check | Actual result |
|---|---|
| ES01–ES04 native layout, naming and retained object transactions, Compatibility | **528 / 0** |
| Same sequences, desktop Mobile renderer | **528 / 0** |
| Construction, save, Test Drive and return workflow | **253 / 0** |
| Surface modes, history and cancellation | **53 / 0** |
| Retained input interactions, headless | **152 / 0** |
| Production parser | **583 scripts / 0 failures** |
| New copy / preceding catalogue preservation | **48 / 0**, twelve languages |
| Full localization unit suite | **15 tests / 2 failures**, also reproduced in preceding-source controls |
| Native evidence | **54 views**: fourteen before, twenty per desktop renderer |

Structured per-view heights and dimensions are in each renderer's `report.json`. All ES01–ES04 acceptance checks pass in the inspected desktop scope. Final native review covers idle tools, picker, placement preview, selection, orientation, four biome material palettes and both naming paths. The final 21-input editor/fixture/catalogue source fence is stable. The private checkpoint proves exact forward and reverse restoration and no shared-index change during checkpoint creation; see `source-checkpoint.json` and `source.patch`.

Actual commands use the pinned 4.7.2 build through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_space_2026_11_17.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_space_2026_11_17.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
# Each headless regression uses the same entry point and timeout:
# res://tests/test_editor_workflow.gd
# res://tests/test_surface_modes.gd
# res://tests/test_editor_interactions_2026_11_14.gd
# res://tests/test_editor_shipping_parse.gd
python scripts/test_localization.py
python scripts/checkpoint_editor_space.py
```

The native fixture runs in disposable offline storage. It checks shelves, 48-unit targets, all material controls fitting, complete English picker categories, 1280x720 / 960x540 / 1560x720 layouts, winter/desert/city pigments, naming cancel/confirm/Undo/Redo/first Save, save failure feedback, picker continuity and the retained exact object transactions. The broader workflow suite checks road construction, practice and returning to editing. No owner saves or live publications are used.

Retained development findings: the first biome review caught two clipped Puddle controls; the readout and tool widths were corrected without loosening their enclosure assertions. An initial rail anchoring attempt triggered the old resize-centering callback recursively; the rail now uses a position-only layout operation and forwards resizing to the shared layout. Both rejected runs remain under `validation/`.

The full localization unit suite ran 15 tests / 2 failures: stale global catalogue inventory and extraction of the engine literal Node3D. Both exact failing tests also fail with this task's preceding source/POT substituted in a read-only control. Scoped new-copy checks pass 48 / 0 across all 12 supported languages, preserving all preceding catalogue bytes. The earlier translation-authoring tab/pipe issue and six broader kerb-vertex findings remain; they were not fixed or reclassified by this presentation task.

## Source scope and remaining acceptance

Runtime files: `game/editor/editor_layout.gd`, `editor_style.gd`, `editor_button.gd`, `object_browser.gd`, `object_thumbnail.gd`, and `game/core/features/editor.gd`. Supporting changes: the new native fixture, twelve catalogue additions and POT entry, authored translation row, this report, the plan/status notes and private checkpoint helper. Road geometry, input transactions, physics, track serialization and publishing services are unchanged.

P1: owner visual acceptance and physical Android checks remain. In particular verify physical touch targets, display cutouts, keyboard behaviour and pinch/edit input on a real landscape phone. P1: real first-player creation time, naming discovery, swatch recognition and accurate object aiming still require player testing; the two-minute target is not established. P2: long translated picker tabs may still need horizontal scrolling; all twelve new strings are checked, but this revision does not claim a complete twelve-language visual sweep. Global localization inventory and the previously recorded kerb rendering findings remain separate work.

Appearance is ready for owner review, not declared AAA-approved. No Android device, phone FPS, export, deployment, live service write, owner-save migration or owner-process operation was performed. Standard retention remains in use; no task pin or shared-index staging.
