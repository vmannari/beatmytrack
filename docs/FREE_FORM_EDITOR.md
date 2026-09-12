# Free-form track editor

2026-09-12. The owner rejected the spline-only authoring model and selected **free-shaped roads, terrain, intersections and obstacles** as the priority. This replaces the previous requirement that the race route also define the road. Requirements: T01 bounded authoring data; T02 editable geometry/route; T03 content identity; T04 free local creation/exchange; V05 matching editor/race geometry; R01 touch interaction. Handling and production five-lap rules are unchanged.

## Using it

- **Paint** is the default. Draw asphalt, grass/erase, dirt/sand, water, barriers, kerbs, rough ground or low obstacles. Round and square brushes span 2–40 m. Paint crosses existing roads, fills open areas and cuts islands. Later strokes overwrite earlier surfaces.
- One finger paints; **Pan** or two fingers navigate. Pinching or canceling discards the tentative stroke. A completed gesture creates one undo step. **Clear map** removes ground edits and props, with Undo available.
- **Route** edits the ordered lap path independently. It can cross itself at ground level. Up to 96 sharp/smooth nodes retain independent helper widths. **Lay road along route** explicitly rebuilds the optional road helper; moving nodes alone leaves the map intact. The Helper surface selector applies the next time the road is laid.
- **Props** retains tree/rock/barrier/terrain stamping, moving, rotating, copying and deleting. Paint controls ground; props are placed above it. Remove placed props through this tab.
- **Tracks → Remix** opens a separate draft based on the selected bundled Slicks circuit. Original ground, bridge layers, route, spawn and checkpoints are retained. Ground paint can then modify that circuit. The source asset is never written.
- Preview the actual compiled 3D map, test five laps, and save/share/import locally as before.

The race route is an ordered guide with generated practice checkpoints, not a competition-grade shortcut verifier. An intersection can have several physically drivable exits; the route/checkpoint order determines the intended lap. The test figure-eight is deliberately spacious and its diagnostic laps take about 36 seconds, above the usual 10–30-second product target. This establishes junction behavior, not acceptance of its final pacing.

## Contract and rendering

Only `creator-track-v3` is accepted. No compatibility/migration is maintained, per the owner's earlier instruction. Existing files are not deleted. [Schema](schemas/creator-track-v3.schema.json) and checked-in starter fixture are updated.

The document separates `points`/`widths`/`corners` (lap guide), `layout` (optional frozen road helper), `paint` (ordered strokes), and `objects`. `base_track` can reference only a bundled manifest entry; arbitrary paths/scripts/assets are rejected. `route_override=false` retains that base's exact original timing geometry until the author changes the route. Its displayed editable guide is simplified; the exact native route remains authoritative until edited.

Creator maps compile to the existing native surface grid at 0.5 m; remixes retain the base's original cell size and bounds. Painting and props use those same collision/surface cells. Existing themes and original procedural art render the result; no new third-party assets, dependencies or simulation algorithms were added. Bridges in remixes remain intact, but **bridge placement/movement and painting the upper deck are not implemented**. The owner chose ground layout freedom for this revision.

The compiler is `creator-compiler-3`; hashes include normalized document JSON and the bundled base content hash. Changing a base version changes the resulting track identity. Exchanged remixes require the matching bundled base; they are not standalone copies of its native data. The in-memory base cache holds at most two tracks.

Safety bounds: 512 KiB file limit, 256 strokes, 512 points per stroke and 16,384 total paint points; finite coordinates/materials/brush sizes; 4–96 route nodes, minimum 2 m neighbour spacing and 40–1,600 m route length. Self-intersections are intentionally accepted. These are bounded data constraints, not paid quotas. Incomplete or obstructed courses can still be saved/tested; the author must assess drivability. Clearing a map retains the route guide so it can be reshaped without rebuilding lap metadata from nothing.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `Validate`: import, 50 script parses, startup and **565 checks passed**: 56 driving, 163 original tracks, 27 extra tracks, 86 creator, 39 prior editor, 43 free editor, 80 app, 53 records, 18 catalog.
- `CaptureFreeEditor`: final graphical free-editor suite passed **49 checks**, including the actual Tracks → Remix action and four screenshots.
- `TestApp`: 80 checks passed after updating route-gesture tests to select the new Route tab.
- Existing development-only `jsonschema.Draft202012Validator`: v3 schema valid, starter accepted, five hostile/legacy variants rejected. No runtime dependency added.
- Targeted `git diff --check` passed.

The free-editor suite checks independent map/route edits, open paving, continuous dirt strokes, grass erasure, water/barrier cells, JSON identity, invalid payloads, touch paint/undo/redo/cancel/pinch, file exchange, and native remix preservation for FREEWAY, 1WAY, 66 and OFFROAD. The crossing circuit completed five ordered AI laps with zero contacts (36.720 / 36.366 / 36.366 / 36.402 / 36.348 s), then replayed exactly from JSON inputs. These are Windows results, not cross-device determinism claims.

Earlier runs exposed expected v2 golden/UI assumptions, a missing optional native title fallback and a near-duplicate final point in simplified remix guides. These were corrected; exact original remix race routes were not simplified by those fixes. Source corpus conversion changes occurring concurrently in the workspace are outside this checkpoint and its acceptance claims.

Changed files: `game/editor/{track_document,track_compiler,editor_canvas}.gd`, `game/core/app.gd`, `game/persistence/track_library.gd`, `game/ui/track_browser.gd`, creator fixture/schema and editor/app tests, `scripts/dev.ps1`, and these docs. No canonical vehicle or camera files changed.

Remaining acceptance: actual phone brush accuracy, reach/scroll/pinch behavior, large-map performance, Android file exchange, novice creation/testing usability and human lap pacing. Android tooling/device enumeration remains unavailable; **no physical-phone test or APK export was performed**. Four representative native remixes were tested; this is not a claim that every corpus circuit has been human-reviewed in the creator.

## Final checkpoint evidence

Concurrent menu-art edits introduced unfinished font/scene imports during a later capture. The editor changes were staged separately, and `git checkout-index --all --prefix=build/free-editor-checkpoint/` produced an ignored snapshot without altering the working tree. Ran `powershell -NoProfile -ExecutionPolicy Bypass -File build/free-editor-checkpoint/scripts/dev.ps1 Validate` and the same wrapper's `CaptureFreeEditor` action there. **All 567 checks and 50 script parses passed**; the expanded free-editor suite contributes 45 headless checks. The graphical suite passed 49. No unfinished menu-art or corpus-conversion changes were included in the editor checkpoint.

Retained evidence: [isolated validation](evidence/free-editor-checkpoint-validation.txt), [earlier working-tree validation](evidence/free-editor-validation.txt), [graphical checks](evidence/free-editor-capture.txt), [painting](evidence/free-editor-paint.png), [independent route](evidence/free-editor-route.png), [3D intersection](evidence/free-editor-preview.png), [FREEWAY remix](evidence/free-editor-remix.png). Logs have terminal colour codes/trailing whitespace removed for review. Screenshots are real Windows captures using synthetic touch input and isolated temporary drafts.
