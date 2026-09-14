# Editor presentation refinement - 2026-09-14

Requirements R01/T01-T04, V02/V03/V04/V05: the owner rejected mixed control styles, rectangular Load/Save buttons, oversized browser chrome, the textual More button and blockout-quality prop graphics. This slice improves the editor presentation and direct object interaction. It does not certify AAA visual quality.

## Changes

- Shared `EditorStyle` supplies dark rounded surfaces, subtle borders/shadows, one regular typeface, cyan selection/focus and readable disabled styles. Header actions have matching 108 x 52 bounds and original folder/save/play glyphs. Navigation, tool rail, context controls, search, category chips, object tiles and options share this style. Confirm remains a distinct circular completion control.
- Browser now occupies two rows, below 170 logical pixels high instead of roughly 220. Removed its permanent Select/move, behavior, size and placement row. A compact options glyph opens a dismissible popover for behavior, variants, sizes and placement modes. Existing objects can be selected and dragged directly while an asset is active. Object-letter overlays no longer cover the 3D models.
- Replaced textual More pagination with an arrow-only button. Categories use bordered rounded chips with a selected surface instead of text tint over square blocks. Thumbnails render at double resolution with MSAA and correctly fit their tile; camera framing includes tall huts and roofs.
- Shared prop meshes gain pitched panel roofs, chimneys and windows; visible vehicle glass, lights and mirrors; rounded banded cones/barrels; clustered broadleaf foliage and rock facets. Tiny intersecting ink hulls are omitted from the placed-prop batch to avoid roof/foliage artifacts. Roof panels join without tiny gaps. Original code geometry is used in both editor and driving; no reference image was incorporated as a production asset.
- A 70-degree planning-camera pitch reveals object volume. Canvas ground coordinates use the same vertical projection factor. Fit, issue focusing and Edit here center via the actual projection. The driving camera and canonical collision/handling are unchanged. The dense grid is suppressed while editing Objects/Surfaces, where it obscured small details. Water gains restrained shoal/ripple variation without changing its driving effect. Editor shadow bias was adjusted after inspecting self-shadow artifacts.

## Contracts and files

Visual kit is `track-kit-13`. No simulation, save schema or authoring collision contract change in this slice. Ground projection is a presentation transform only.

New: `game/editor/editor_style.gd` and UID. Changed: `game/core/app.gd`; `game/editor/editor_button.gd`, `editor_canvas.gd`, `editor_world.gd`, `object_browser.gd`, `object_thumbnail.gd`; `game/track/creator_prop_visual.gd`, `native_track_visual.gd`, `terrain.gdshader`; `game/tests/test_object_browser.gd`; status/phase documents and evidence below.

The workspace initially contained independent road-join/start-alignment edits. They were preserved and became checkpoint `95b9ffd` during this work; this presentation checkpoint does not replace or undo them.

## Actual commands and results

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2 Windows.

- `Import`: passed; Android build-tools unavailable.
- `CaptureObjects`: 51 checks, zero failures, Compatibility/OpenGL RTX 3090. Includes direct one-gesture object dragging, two-row height, popover opening, save/reload, placement modes and wide-aspect layout. Inspected final images.
- `TestWorkflow`: initially caught stale Edit here centering after camera tilt. Fixed the centering operation rather than weakening the assertion. Final 94 checks, zero failures, including actual ground-to-camera projection and return-to-editor position.
- `TestApp`: 84 checks, zero failures.
- `TestFreeEditor`: 55 checks, zero failures, including five-lap free-form route.
- `TestConstruction`: 73 checks, zero failures, including five-lap bridge over/under passage.
- Total targeted verification: 357 checks, zero failures. Full simulation regression was not repeated for this presentation/input slice.
- `git diff --check`: passed.

[Two-row browser](evidence/editor-refined-browser.png) | [Nature and arrow pagination](evidence/editor-refined-nature.png) | [Prop close-up](evidence/editor-refined-props.png) | [On-demand options](evidence/editor-refined-options.png) | [Wide landscape](evidence/editor-refined-wide.png) | [Actual capture log](evidence/editor-refinement-capture.txt).

## Remaining acceptance

The object kit is still procedural prototype art and remains below the supplied AAA reference. More substantial mesh/material authoring, foliage silhouette variety, asset-specific weathering and a coherent finished environment are still needed. This pass improves readability and removes obvious blockout traits; it does not claim to complete that art target. The captured circuit is a test-authored editor fixture, not a replacement for the owner's tracks.

No physical-phone test or Android export was performed; device attachment was not enumerated. Phone touch reach, selection of tall-object silhouettes, popover use, shadows, thermal/frame pacing and final visual acceptance remain to be checked on a device. Ground mapping is verified; the editor continues to select planar footprints, with the existing touch tolerance around object centers.


## Reference layout follow-up (2026-09-14)

Requirements R01/T01-T04/V02/V04/V05: removed the #/Fit overlay control; raised and grouped the four main tools in a shared panel; lighter charcoal object tiles; text-only Load/Save/Test with a green action treatment and left-growing header container so content cannot expand past the right edge. Added an editable track name below Track Editor. Road glyphs now have contrasting shoulders, asphalt and dashed centre markings. Jump moved from Track to Objects > Props with a ramp-specific behavior description; its simulation is unchanged.

Changed app.gd, editor_button.gd, object_thumbnail.gd, creator_catalog.gd and the app/browser checks. Actual commands: scripts/dev.ps1 -Action CaptureObjects (55 checks, zero failures), TestWorkflow (94, zero), TestApp (84, zero). Initial App run referenced the intentionally removed Fit button; the test now calls the same fit operation directly while preserving its viewport assertions. An intermediate test edit had an out-of-scope variable and was corrected before the successful rerun. No simulation changes or full physics regression in this presentation slice.

Reviewed engine captures: [Objects](evidence/editor-layout-objects.png), [Road tools](evidence/editor-layout-road.png). Desktop and wide landscape captures were performed; no physical phone test or Android export was performed. The overall art remains below the AAA reference; this follow-up addresses the requested controls and catalogue placement.
