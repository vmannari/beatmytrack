# Surface editor usability - 2026-09-17

Owner requested removing bottom-right acceptance, placing acceptance inside the draft, moving oil to Objects, removing Road from Surfaces, and separating modes from asset/material choices. Requirements R01/T01-T04/V03/V05.

The bottom-right confirm button is removed globally. Roads retain their existing world-space confirmation. Surface lines and bounded areas now draw a 56 px gold confirmation target on the draft; area placement uses an interior triangle centroid, so concave contours do not put the target outside. Line placement selects a point on the smoothed path away from control points. Confirmation is committed on release; a drag cancels the tap. Enter remains available. Free painting still commits on release; already placed objects retain direct editing and do not need confirmation. Escape and inspector Cancel/Remove last point remain.

Surface placement now has a separate top toolbar labeled Placement: mode dropdown, Brush options, Pan and road protection. Bottom tiles are Grass, Sand, Water and Puddle. Road is removed from the surface palette and inspector, and a legacy asphalt brush selection changes to sand when Surfaces opens. Existing saved asphalt paint is preserved. The inspector retains the existing additional terrain brushes and is reached through Brush.

Oil spill is an Objects > Props asset with its real rendered thumbnail and an explicit slippery/tyre-coating behavior description. Choosing it stays in Objects and uses the existing object placement/size/rotation flow. Its deterministic hazard behavior is unchanged. Puddle remains under Surfaces.

Changed files: `game/core/app.gd`, `game/editor/editor_canvas.gd`, `game/editor/creator_catalog.gd`, `game/tests/test_surface_modes.gd`, `game/tests/test_editor_workflow.gd`, status/plan and this document/evidence. No physics, document schema or asset dependency changes.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `CaptureSurfaces`: final 48 checks, zero failures. New checks cover in-world release confirmation, area target inside the contour, removal of corner accept, separate toolbar bounds at 1280x720 and 960x540, no road/oil/mode tiles in material palette, oil catalog/category and actual spill placement. Existing mode/paint/road mask tests remain.
- `TestWorkflow`: 166 checks, zero failures. Updated the former hidden-corner-button assertion to require its complete absence.
- `TestObjects`: 58 checks, zero failures.
- `TestFreeEditor`: 43 checks, zero failures, five-lap diagnostic drive unchanged.

Total: 315 checks passed. Captures inspected: [area](evidence/surface-usability/surfaces-area-preview.png), [line](evidence/surface-usability/surfaces-line-preview.png), [smaller landscape](evidence/surface-usability/surfaces-area-small-landscape.png), [oil in Objects](evidence/surface-usability/surfaces-oil-objects.png). Logs saved alongside the PNGs.

No phone/device test or Android export performed. The 960x540 check is a desktop viewport test, not device acceptance. Owner workflow review, physical touch-target usability and portrait/narrow-screen behavior remain unverified. Very small drafts may require zoom to separate the confirmation target and handles; wide/landscape remains the supported editor presentation. Existing uncommitted work is retained; no combined Git commit made.


## Reference-style top paint controls - 2026-09-17

Owner supplied Free / Area / Line segmented-control reference and requested the controls beside the existing top buttons plus a neat brush-size control. Replaced the dropdown with three directly selectable icon buttons, labeled Paint mode, with cyan active styling. Original code-drawn brush, area-corner and line glyphs; reference image is not a shipping asset. The controls sit at the top alongside undo/redo and map/test; the track title is narrower in Surfaces to make room.

Brush size is a live 0.5-40 m slider with numeric readout and +/- half-metre adjustment buttons. It updates the existing draft preview without committing a stroke. Area shapes remain determined by their control points; width applies to Free/Line. Shape, Pan and Keep road controls remain available via the adjacent options button. Bottom material tiles and in-world confirmation are unchanged.

Requirements R01/T01-T04/V03/V05. Changed `game/core/app.gd`, `game/editor/editor_button.gd`, `game/tests/test_surface_modes.gd`, status/plan and this evidence.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureSurfaces`: 58 checks, zero failures. Added real button selection, slider value, half-metre increment, width limit and top-band placement checks. Inspected [1280x720](evidence/paint-mode-controls/surfaces-area-preview.png) and [960x540 desktop viewport](evidence/paint-mode-controls/surfaces-area-small-landscape.png) captures. No phone test or Android export performed. Physical touch usability and owner visual review remain outstanding.

Additional actual verification: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestWorkflow`: 166 checks, zero failures. Total for this follow-up: 224 passing checks. `git diff --check` passed for changed implementation/test files.
