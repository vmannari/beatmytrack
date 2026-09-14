# Creator asset browser and placement modes - 2026-09-14

Requirements: R01/T01-T04 (mobile authoring, usable placement and local persistence), V02/V04/V05 (shared readable art), G01 (deterministic object interaction). The supplied screenshots are indicative UI references. The [attached catalogue](CREATOR_CATALOGUE_REFERENCE.md) supplies the family/category model; the owner explicitly confirmed that tyres remain movable and subsequently requested movable lightweight props and future biome-specific availability.

## Delivered slice

- Four main tools: Track, Surfaces, Objects and Race. Existing jumps are under Track; oil and puddles are under Surfaces. The world remains full-screen beneath overlays.
- Objects uses Nature, Barriers, Trackside, Props and Buildings, plus All/Recent filters and search. Searches include variant names. Eight thumbnail tiles per page bound render cost; rows also support horizontal scrolling. Each thumbnail is a one-shot 3D render from the same mesh builder used in the world.
- 29 asset families / 33 object kinds: nature plants, pebbles, rocks/outcrops and logs; tyres, concrete, guardrails, wooden/wire fences and cones; boards, flags, poles and gantries; crates, barrels, pallets, parked vehicles and containers; garages, huts and grandstands. Existing five surface/ramp stamps remain outside the object browser.
- Rock/boulder, ridge/formation, one/six tyre stacks and utility car/van are grouped variants. Small/medium/large applies bounded scale to individual non-line assets. Decoration is capped at 1.5x and never stamps collision or changes the underlying surface. Linear kits retain fixed placement dimensions, so automatic joining does not change with a hidden scale setting. Selected objects retain existing rotate/copy/scale/delete controls.
- Barrier families and cones expose Single, Line, Curve and Road edge modes. A single tyre stack is now one physical stack, not six stacks under a misleading Single label. Lines support dragging or two end taps. Curve mode samples a freehand path and automatically spaces/orients segments; road-edge mode follows existing road geometry. Each run is one undo action, bounded by the existing 96-object limit. A long run truncates at capacity instead of spreading its remaining pieces farther apart.
- Search, category, recent selections and selected family survive editor rebuilds such as Undo. Current object kind, scale and line mode are retained alongside the existing editor view. No user's saved track is overwritten by the test fixtures.

## Interaction and biome boundary

Tyre stacks keep the approved resistant, movable pile solver. Cones, small boards, crates and barrels use deterministic lightweight bodies: 8 or 22 kg effective mass, bounded 0.18 m/s car normal-velocity loss per contact, 16 m/s prop speed cap and 5 m/s^2 drag. They slide and visually tip; they do not explode or create collidable fragments. State belongs to the run and resets on restart. Static terrain still stops loose props; light props can be driven over and do not form rigid shortcut barriers. Ground props do not hit cars on bridge decks or in flight.

Tree selection uses its canopy area, while solid rasterization uses the trunk. Pole/trunk raster radius has a 0.36 m minimum to remain present on 0.5 m native cells. Start gantries have solid supports and a clear central opening; they do not replace the Race timing line. Small decorative stones remain distinct from solid boulders.

`CreatorCatalog.BIOME_ASSETS` is the single future biome-to-family availability map. The browser passes the document's current theme as its initial biome key; unknown/unconfigured biomes use the common kit. The compiler and persisted stable object kinds do not depend on browser filtering, so changing a future biome palette cannot silently delete placed objects or change their collision. Actual new biomes and biome selection are deliberately reserved for the later owner-requested slice.

## Contracts and changed files

`creator-track-v5` gains allowlisted kinds and bounded decorative scale; schema updated. `creator-compiler-8`, `arcade-planar-0.17`, `track-kit-12`. Recorder schema 5 stores 17 state fields: existing fields 0-15 plus light-body rows `[x,y,vx,vy,tipped]` at index 16. The compiler-8 default identity is `5b02bb3d4c972346ac2650fe61dcda407dc03253a7824fcbe780ce6141501869`; the golden fixture was updated explicitly for this version change.

New files: `game/editor/creator_catalog.gd`, `object_browser.gd`, `object_thumbnail.gd`; `game/track/creator_prop_visual.gd`; `game/vehicle/light_props.gd`; `game/tests/test_object_browser.gd`, with engine UIDs. Changed boundaries: editor canvas/document/compiler/object definitions; app composition; native visual/ground adapters; game presentation; tyre position generation; vehicle state/version and recording header; tests, v5 schema, build entry point and status/phase documents.

## Actual validation

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned Godot 4.7.2 Windows engine.

- `Import`: passed; Android build-tools unavailable.
- `CheckScript -ScriptPath res://core/app.gd`: passed.
- Initial `TestObjects` exposed a test decoding API error, then an off-tree thumbnail camera call and a stale test browser reference after Undo. These were corrected. The hung test process was stopped explicitly; existing editor/game processes were not stopped.
- `CaptureObjects`: initial 38 checks, zero failures, Compatibility/OpenGL RTX 3090. Reviewed actual browser and Nature screenshots, then improved small-item thumbnail framing and corrected text separators.
- `TestHazards`: 141 checks, zero failures, including all allowed kinds, scale bounds, collision, saved scenery deletion and jump replay.
- `TestPieces`: 144 checks, zero failures, including updated default hash, five-lap circuit and object validation.

- Final `CaptureObjects`: 45 checks, zero failures. [Barriers](evidence/object-browser.png), [Nature](evidence/object-nature.png), [wide landscape](evidence/object-wide.png), [actual capture output](evidence/object-browser-capture.txt). Wide-aspect assertions use logical viewport bounds to account for the project's existing stretch transform.
- Existing `.tools/review/Scripts/python.exe` with `jsonschema.Draft202012Validator`: v5 schema valid, all 38 kind values accepted, five invalid size cases rejected. No dependency installed.
- First `Validate` passed driving/native/creator/replay suites and stopped at two outdated rail-caption assertions. The assertions now require the owner's Track/Surfaces labels; their visibility/size checks remain.

- The second `Validate` passed all suites through movable props, then caught a test selecting the first LineEdit (now the hidden object search) instead of the circuit-name field. The field now has a stable `CircuitName` ID and the test still dispatches a real viewport touch. `TestApp`: 84/84 passed; `TestRecords`: 53/53; `TestCatalog`: 18/18; `TestDeleteTracks`: 19/19; `TestMenus`: 11/11. Remaining suites were completed with these targeted commands rather than claiming that the interrupted aggregate command passed.
- Final `TestObjects`: 42/42 passed, including injected biome availability and preserving placed object validity. Across the completed full-run suites and targeted reruns, all 1,188 domain/UI checks passed. Import, startup and all 82 script parses passed in the full run. [Collected actual suite outputs](evidence/object-browser-validation.txt).
- `git diff --check`: passed (line-ending normalization warnings only).

## Remaining acceptance and catalogue limits

This is the initial shared procedural object kit and browser, not every future variation listed in the catalogue. Configurable board numbers/colours, canopy occlusion fading, foliage bending, separate building footprints, free terrain height editing and additional road presets are not implemented here. Existing shallow water/oil/jump behavior and the existing blocking pond are preserved; progress-safe deep-water/fall recovery and authored recovery points need a separate race/hazard slice. The rendered palette thumbnails and indicative screenshots are not production asset quality guarantees.

Freehand curves are automatically spaced runs of independent segments, not persistent editable wall splines. Extremely tight curves can overlap segments; undo/repaint or select individual pieces to adjust them. No arbitrary per-object collision/grip strengths are exposed. Native solid collision remains a 0.5 m raster and airborne handling retains the earlier hazard limits.

No physical phone test or Android export was performed. Android tools/templates remain unavailable. Remaining manual acceptance: thumbnail legibility, palette scrolling/reach and freehand curves on a real phone; dense-scene thermal/frame pacing; movable-prop feel and the visual reference match. Replay equality is tested on the pinned Windows engine, not across platforms.
