# Editor cards and centred menus — 2026-11-17

The owner rejected the mixed card colours and split footer alignment. This revision supersedes the previous left/right tool grouping and mixed transparent/filled cards. Existing compact shelf heights, editing transactions, naming and storage remain.

Plan before implementation:

| ID | Change | Acceptance | Risk |
|---|---|---|---|
| EF01 | One opaque slate shell and one neutral card fill across road, surface, object, category and property controls. Shared border, corner, hover, pressed, selected and disabled treatment; selection uses a cyan outline. | Header/rail/footer shell colours match; normal and selected card fills match across families; hover remains neutral. Functional material pigments and the primary Test action retain their meaning. | Low, presentation only |
| EF02 | Centre each footer tool group at its natural width. Centre object pages and category tabs; keep overflow scrollable. | Geometric centre of Road, Surfaces, Place, Select and property rows matches the dock centre at 960, 1280 and wide landscape. No clipped material or orientation controls, all effective logical targets >=48. | Medium, responsive sizing |
| EF03 | Consistent monoline category icons, centred card artwork/captions, common baseline and spacing. Remove mismatched cyan fills, thumbnail backgrounds and floating shadows. | Native inspection of idle, selected, disabled, picker and property states. Preserve the short shelves and existing placement/reselection/cancel/Undo behaviour. | Low |

The material pattern is a content swatch, not a different card background. Card labels share a centred baseline. Utility actions in the header remain quiet, and Test retains its semantic primary colour. The object picker stays temporary. No input, geometry or persistence redesign is required.

Android hardware and actual player acceptance remain untested. Before views are retained from the preceding native review with explicit provenance.

EF04 ? expanded owner review: inspect document commands, free/area brush options, snap and asset dropdowns, colour picker, population, Help, Share, naming and saving at both native sizes. Ensure labels remain readable when disabled and tall menus scroll within the exposed canvas. Native snapshots and explicit viewport/contrast checks are required before calling menu review complete.

The expanded audit reproduced hidden brush/document content behind the footer and one Area panel outside the viewport. EF04 adds bounded scrollable popovers with headings and Close, readable disabled text, and native Label captions instead of manually painted tool text. This is a presentation change with no data migration. Dropdown review uses Godot [OptionButton.show_popup](https://docs.godotengine.org/en/stable/classes/class_optionbutton.html#class-optionbutton-method-show-popup) so the captures include open lists rather than their selected values.

## Implemented result

EF01: header, rail, footer and editor popovers share one opaque slate shell. Road cards, material choices, object thumbnails, categories and property buttons share one neutral tile fill, thin border and corner treatment. Selected cards use a cyan outline; their fill stays consistent. Hover is neutral and floating shadows are removed. Semantic material pigments, the colour preview and Test retain their meaning.

EF02: Road, Surfaces, Place, Select and property groups now centre at their natural width. The object picker centres its page and category group. Natural content sizes are measured before assigning scroll budgets; small widths retain scrolling. Material artwork and captions are centred on the same baseline as the other tool cards. The compact header/footer heights remain, and Area confirmation now fits in a single row too.

EF03/EF04: tool captions use real Godot Labels with readable normal and disabled colours. A missing caption is recreated on redraw, including for an already existing control; the native fixture exercises this recovery path. An older menu structure is tolerated during partial reload; the fixture simulates this without changing the track. The native colour preview previously painted over its own label. Its preview now occupies a small area above a separate Colour caption, with an explicit accessible name. The underlying ColorPickerButton and commit-on-close transaction are retained.

The expanded menu audit reproduced several actual visibility defects. Brush and document panels extended behind the footer; Area options extended outside the short viewport. They now have bounded scroll containers, headings and Close buttons. The import form was cropped at 960x540; its text area now responds to viewport height. The export browser clipped icon labels; file browsers now open with a readable list and a viewport-sized window. Import, export and Share were opened only for inspection: no file, import, clipboard or publication action was confirmed.

## Reviewed menu states

| Route | Review |
|---|---|
| Road, Surfaces and object shelves | Idle/selected controls, previews, properties, orientation and four biome palettes |
| Object picker | Categories, paging, selected/inactive cards and reopening the active family |
| Brush options | Free and Area, including scrolled bottom actions/help |
| Document menu | Top and scrolled bottom, including disabled Publish, Help and scenery |
| Dropdowns | Actually open snap and object-variant lists |
| Colour | Visible Colour caption, unobscured preview and open picker |
| Population | Ready/cancel controls and 48-unit sliders/actions |
| Help / Share | Open owned dialogs, readable text and actions |
| Import / Export | Open forms and filename browser at both sizes; cancel only |
| Naming / Save / Exit | Initial name, first Save, cancelled naming, saved-name preservation and unsaved departure |

These are editor menus and their linked dialogs, not a claim that every screen or authenticated server flow in the game was tested. Shared game dialog artwork remains; this revision does not redesign the global game theme. All newly used text keys already exist in all twelve catalogues. The visual sweep uses English.

## Validation

| Check | Result |
|---|---|
| Native composition, captions, menu bounds, contrast, history and retained object transactions, Compatibility | **904 / 0** |
| Same checks, desktop Mobile renderer | **904 / 0** |
| Surface editing regression | **53 / 0** |
| Production parser | **583 scripts / 0 failures** |
| Viewports | **960x540, 1280x720, 1560x720** for shelf composition; menus at the first two |

Tests use isolated offline storage. They verify centred groups; shared fills; visible native captions and at least 4.5:1 caption contrast against the card fill; retained 48-unit logical targets; usable colour captions; actual open dropdowns; popovers above the footer; and contained import/export windows. The original exact object placement/reselection/cancel/history and naming sequences remain in the fixture. These measurements do not establish physical Android dp or real-player usability.

The earlier right-edge painting assertion was replaced by the owner's newly requested centre-alignment assertion. Other geometry, transaction, enclosure and target checks were retained. The rejected menu review (**35 checks / 1 failure**) and cropped brush/document/import/export images remain in `validation/`; the failing Area enclosure assertion was fixed without relaxing it. Earlier kerb-rendering and global localization inventory findings remain recorded in preceding reports and were not reclassified as passing here.

Actual entry points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_finish_2026_11_17.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_finish_2026_11_17.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_surface_modes.gd -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_shipping_parse.gd -CommandTimeoutSeconds 300
python scripts/checkpoint_editor_finish.py
```

Before: [surface shelf](evidence/editor-finish-2026-11-17/before/02-surfaces-1280.png), [object picker](evidence/editor-finish-2026-11-17/before/03-object-picker-1280.png). These are retained preceding native captures; `before-provenance.txt` identifies the source. World/start-line changes from concurrent work are not attributed to this styling task.

After: [centred surface shelf](evidence/editor-finish-2026-11-17/gl_compatibility/02-surfaces-1280.png), [object picker](evidence/editor-finish-2026-11-17/gl_compatibility/03-object-picker-1280.png), [brush menu](evidence/editor-finish-2026-11-17/gl_compatibility/13-brush-options-960.png), [Area menu bottom](evidence/editor-finish-2026-11-17/gl_compatibility/21-area-options-scrolled-960.png), [document commands](evidence/editor-finish-2026-11-17/gl_compatibility/22-document-menu-scrolled-960.png), [Colour caption](evidence/editor-finish-2026-11-17/gl_compatibility/23-colour-caption-960.png), [import](evidence/editor-finish-2026-11-17/gl_compatibility/25-import-dialog-960.png), [export](evidence/editor-finish-2026-11-17/gl_compatibility/24-export-dialog-960.png).

## Changed components and remaining acceptance

Runtime: `game/editor/editor_style.gd`, `editor_layout.gd`, `editor_button.gd`, `object_browser.gd`, `object_thumbnail.gd`, `container_color_button.gd`, `object_population_panel.gd`, and `game/core/features/editor.gd`. Supporting changes: the native finish fixture, the superseded alignment assertion in the preceding fixture, this report, marked plan/status notes and checkpoint helper. No track geometry, persistence format or input transaction was changed.

A task-scoped private checkpoint proves exact forward/reverse restoration while preserving the shared index and concurrent controller/vehicle work. `source-checkpoint.json`, `source.patch`, image hashes and the final source fence make this revision reviewable. Standard retention remains; no task pin, owner-save/process action, live service write, export or deployment.

P1: owner appearance acceptance, physical Android safe areas/input/keyboard and actual dp remain. P1: first-player task time, menu recognition and touch accuracy require real-player testing. P2: a complete multilingual visual sweep and authenticated publication dialogs remain outside this review. Native contrast and layout checks do not constitute AAA or Android acceptance. Reopen the editor screen to build the complete new presentation; existing controls also recover missing captions on redraw.
