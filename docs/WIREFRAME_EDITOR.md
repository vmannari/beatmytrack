# Wireframe creator revision — 2026-09-13

Owner direction: the supplied phone-editor wireframe replaces the previous toolbar-and-inspector workspace. This revision covers R01 (phone interaction), T01–T04 (creation, editing, validation and sharing), and V03/V05 (presentation and shared track geometry). The latest wireframe also explicitly changes creator tests to untimed practice; ordinary races still use five laps.

## Implemented workflow

Create opens on blank terrain. The entire viewport is an editable world, with a small Road/Surface/Objects/Race rail, top Back/Undo/Redo/Map/Test controls and a contextual bottom palette. Metadata, theme, local library and sharing stay in the Map overlay. Opening controls does not resize the world. Pan, anchored pinch/wheel zoom, fit and the prior 0.5 m surface brush remain available.

Road offers Straight, Curve, S-bend and Hairpin. Choose a section, tap or drag its cyan preview, and confirm with the checkmark. A new section starts at the previous end; snapping matches available endpoint positions, angles and width. Tap an existing section to move it. Shape and Width expose large touch handles plus 1 m adjustment buttons; curved pieces have a separate lead-in adjustment. Rotate uses 15-degree steps; Flip mirrors the bend. One drag or placement creates one undo step and saves locally. Geometry changes affect the selected section; open joins are reported for reconnection.

Surface retains arbitrary roads, terrain, intersections, erase-to-grass, round/square brushes and the complete material palette. Road pieces do not constrain free painting. Race edits the independent numbered lap route, including sharp corners and individual helper widths; Use roads derives a route from one closed connected chain. A partially built road can be saved and practiced without inventing a completed lap.

Objects offers barriers, tyre walls, fences, trees and rocks. Two taps place barrier/wall/fence runs along the nearest connected road edge; runs become ordinary individually movable/removable objects and one undo step. Trees and rocks place with a tap. Select exposes move, rotate, copy and delete. Fixed allowlisted objects and bounded JSON remain the entire content contract.

The issue badge locates open endpoints and starts covered by blocking objects or painted obstacles. Focusing a blocking object selects it, centres the view, and offers direct removal or relocation. Move start places a saved **practice start** on a clear road; the timed lap start remains in Race > Set start. Open endpoints are advisory for untimed practice. These checks are local editing aids, not competition-grade route/shortcut verification.

Test enters the real game camera and driving controls immediately. Practice has no countdown, lap completion, PB or results interruption. Restart and Edit here remain accessible; Edit here restores the editor zoom and centres on the actual driven location. An ordinary library/menu race still counts five laps and records through the existing rules.

## World and contract

`EditorWorld` uses the same `NativeTrackVisual`, theme materials and bridge presentation as racing. Its orthographic planning camera exactly follows canvas position/zoom; the approved racing camera and physical handling are unchanged. Original smooth road meshes and narrow white edge markings are drawn from the same piece samples; painted native cells exclude the overlays so surface edits remain visible. Pine, coast and desert continue to share the track kit. Original procedural tyre stacks, timber fences and deterministic distributed scenery extend the kit. The owner image is a design reference, not a shipping bitmap asset; all new icons/meshes/shaders are original code, with the existing cleared Barlow fonts.

Creator-track-v4 adds `pieces` and an optional bounded `practice_start`. Defaults and native remixes omit the optional start. Maximums remain explicit: 96 sections, 4,000 m total section length, 96 props, 256 brush strokes and 512 KiB JSON. Roads compile to deterministic native cells; no network, SDK or runtime external dependency was introduced. Native remixes retain their original ground, bridge geometry and lap data until explicitly edited. Earlier user-created formats are unsupported, as authorized; their files are not deleted.

## Changed files

- `game/core/app.gd`, `game/editor/editor_canvas.gd`, new `editor_button.gd` and `editor_world.gd`: full-screen interaction, contextual controls, issue recovery and practice return.
- New `game/editor/road_pieces.gd`, `track_document.gd`, `track_compiler.gd`, `creator_objects.gd`, v4 schema and default fixture: geometry, snapping, object runs, bounded persistence and native compilation.
- `game/track/native_track_visual.gd`, new `creator_road.gdshader`: shared road/prop rendering and painted-cell exclusions. Editor boundary hiding is explicitly presentation-only; physical barriers remain visible in racing. `native_track.gd` exposes the existing collision-overlap depth as a read-only query for start clearance; collision resolution is unchanged.
- `game/core/game.gd`, `game/ui/playground_hud.gd`: untimed practice lifecycle and compact return controls.
- New piece/practice/workflow suites, updated app/creator/editor/free-paint regressions and `scripts/dev.ps1`: reproducible checks and engine captures.

## Actual validation and evidence

Windows with pinned Godot 4.7.2. All named actions use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>`.

- `TestPieces`: 101 checks passed, including endpoint joins, occupied-end rejection, independent shapes, road-following runs, tyre/fence collision, optional practice-start validation, five completed piece-road laps with zero contacts and exact replay.
- `TestPractice`: 31 checks passed. A six-lap witness continues for 12,472 ticks with zero contacts and no scored practice result; a regular race completes exactly five laps. `CapturePractice`: 32 checks passed.
- `TestWorkflow`: 96 checks passed; `CaptureWorkflow`: 103 checks passed. Real viewport-dispatched category taps, geometry-handle drags, one-step undo, live dimensions, native-camera alignment, route derivation, barrier-run persistence, blocked-start move/delete recovery, correct car heading, actual driving and Edit here return are covered. Final review added both pinch release orders, cancelled-finger handoff, immediate next-piece palette, nearest-tangent start placement, tight-bend practice heading, whole-car clearance and symmetric solid overlap.
- `TestApp`: 84, `TestEditor`: 39, `TestFreeEditor`: 55 and `TestCreator`: 86 checks passed. Existing free-map crossing finishes five laps with zero contacts and exact replay; historical handling fixtures retain their diagnostic lap counts.
- `TestTracks`: 163 and `TestMenus`: 11 checks passed. Focused graphical inspection checked 1,352 painted cells without road-overlay leaks, camera projection correspondence, and editor-only perimeter presentation.
- `Validate`: import, all 63 script parses, main-scene startup and the complete domain/UI regression suite passed (driving, native/extra tracks, creator, prior editor, free editor, pieces, practice, workflow, app, records, catalog and menu presentation). Subsequent pinch/start-clearance review fixes are covered by the targeted final workflow/app reruns below; canonical physics algorithms were not changed.
- `Doctor` failed because the matching Android debug export template, configured SDK/platform-tools/build-tools and JDK are absent. No APK export or physical-phone test was performed; device attachment could not be checked through the unconfigured ADB.
- The optional standalone Python JSON Schema check was unavailable (`jsonschema` is not installed). No package was installed. The native bounded-document validator, invalid-input cases, schema JSON parsing and fixture round trips were checked.

Reviewed engine captures: [place a section](evidence/wireframe-start.png), [aligned connection](evidence/wireframe-connect.png), [local geometry handle](evidence/wireframe-geometry.png), [object palette and run](evidence/wireframe-objects.png), [focused obstruction](evidence/wireframe-issue.png), [untimed practice](evidence/wireframe-practice.png). Captures use isolated temporary documents and synthetic input on Windows, not a phone.

Final logs: [103 graphical checks](evidence/wireframe-capture.txt), [96 workflow checks](evidence/wireframe-workflow.txt), [101 piece checks](evidence/wireframe-pieces.txt), [32 practice/capture checks](evidence/wireframe-practice.txt), [84 app checks](evidence/wireframe-app.txt). The last graphical run includes the adjacent red issue callout. `git diff --check` passed.

## Remaining acceptance

The procedural environment is simpler than the concept illustration; the image's detailed foliage, terrain relief and cinematic lighting are not reproduced. The reference's automatic adjustment of neighbouring sections is not implemented: local edits retain other sections and expose any resulting open joins. Object runs use the existing bounded prop count and closest connected road; arbitrary road groups and bridge construction tools remain outside this slice. Practice-start checks do not prove full-route drivability or prevent competitive shortcuts.

Physical-phone reach, safe-area behavior, precision, thermal performance and sustained map-rebuild latency remain unverified. The creator has no phone acceptance claim until the Android tooling and an actual device are available. Owner review of this new workflow and visual direction remains outstanding.
