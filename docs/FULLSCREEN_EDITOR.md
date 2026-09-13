# Full-screen creator — 2026-09-13

Owner request: Create must use the whole screen like racing; the previous small canvas made detail work impractical. Requirements R01 (touch usability), T02 (authoring), V03/V05 (editor presentation and shared geometry). No racing camera, handling, lap rules or source-track changes.

Create now bypasses the surrounding menu layout. The canvas fills the complete viewport, including behind the compact top and bottom controls. Paint, Route, Props and Pan remain directly accessible. Tools and Map settings are collapsed overlays; opening them does not resize or reframe the canvas. Tool selection is visibly highlighted. Tools stays open across undo/redo. Exit saves and returns to the race menu; Test drive keeps the existing return-to-editor flow.

Name/theme/road-helper/creator/new/share/preview/library actions are in Map. Undo/Redo and Fit/zoom sit along the bottom. Overlay controls account for mobile safe-area insets; the underlying map remains full-screen. This has not been verified on a physical phone.

Zoom range is now 0.25–16×, with wheel/pinch zoom anchored at the pointer or finger midpoint. Grid spacing adapts down to 0.5 m. Surface pixels stay sharp at close zoom instead of being blurred. Paint brushes now reach 0.5 m, snapping the smallest brush to native cell centres so a dab paints one actual cell. Fit includes paint and props beyond the lap route. The v3 schema's paint-width minimum is updated; compiler/simulation algorithms and stored coordinates retain their existing meanings.

Changed files: `game/core/app.gd` (dedicated workspace, overlays and explicit history-button references), `game/editor/editor_canvas.gd` (fit, anchored zoom, grid/filter and fine-brush placement), `game/editor/track_document.gd` and v3 schema (0.5 m brush), `game/tests/test_app.gd`, `game/tests/test_free_editor.gd`, plus status/plan documentation.

## Actual checks

Windows, pinned Godot 4.7.2, commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestApp`: 85 checks passed, including viewport-dispatched name editing through Map, touch dragging, undo/redo, save/import and five-lap test-drive return.
- `TestEditor`: 39 checks passed for route widths/corners, props, persistence and replay.
- `TestCreator`: 86 checks passed for bounded data, persistence, geometry and three diagnostic theme replays.
- `CaptureFreeEditor`: **60 checks passed**, with real Windows screenshots and synthetic touch checks. New assertions require a full-viewport canvas, initially collapsed panels, no surrounding menu tabs, unchanged canvas bounds with Tools open, an anchored 16× zoom, a visible half-metre detail, one-cell brush output and Fit including off-route paint.
- Existing development `jsonschema` validator accepted a 0.5 m brush and rejected 0.49 m; schema validation passed. No runtime dependency added.

The initial app tests still tapped the old always-visible name field, painting on the newly exposed canvas. Tests now open Map before interacting with the name field. Close-up inspection exposed blurry filtering and undersized round dabs falling between cell centres; both were corrected and covered by the final graphical checks.

No physical-phone test or APK export was performed. Remaining acceptance: finger precision, reach, safe areas and close-zoom performance on an actual phone. Large-map performance and the prior creator's shortcut-verification/bridge-tooling limitations remain open. Full physics regression was not rerun for this UI change; the targeted suites above include existing race/replay checks.

Reviewed screenshots: [full-screen workspace](evidence/fullscreen-editor.png), [overlay tools](evidence/fullscreen-editor-tools.png), [16× detail and a single painted cell](evidence/fullscreen-editor-detail.png). Logs: [graphical checks](evidence/fullscreen-capture.txt), [app integration](evidence/fullscreen-app.txt), [prior editor regression](evidence/fullscreen-editor-tests.txt), [creator domain](evidence/fullscreen-creator-tests.txt). Captures use temporary isolated drafts and synthetic input, not a physical phone. `git diff --check` passed.
