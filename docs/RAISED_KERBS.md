# Raised kerbs and tyre response ? 2026-09-15

## Owner request and requirements
G01/V02/V04/V05/R01/R03/R07: add visible kerb depth and a slight driving impact. The earlier grass, asphalt and lighting restoration remains in place. Handling presets, car scale, wheelbase, ordinary five-lap rules and gameplay camera are unchanged.

## Implemented behavior
- Creator inside-bend kerbs now have a 10 cm crown, a sloped road-side approach and outside bevel, with geometric width/height taper at the existing white run tips. Red/white blocks retain equal fitted lengths and white starts/ends. Correct facet normals and shadow casting make the height visible.
- Native source kerbs near asphalt get a joined crown on their existing raster footprint, with sloped boundary cells. Larger concrete areas remain flat. Source kerbs are retained in remixes outside new road-piece scenery; new pieces' raster shoulders do not become extra kerbs.
- Pure `RoadEdges` construction and `RoadKerbs` triangles provide shared presentation and tyre-support geometry. Fixed 4 m lookup buckets avoid a whole-track triangle scan per wheel. Paint exclusions, occupied cells and rough barriers use the same mask for rendering and contact.
- Four tyre positions sample resolved travel in at most 10 cm increments at the canonical 120 Hz rate. Kerb ascent removes a small amount of speed, capped at 0.65 m/s per second; low-speed impact fades below 8 m/s and is zero below 1 m/s. It never adds forward energy or a steering kick.
- A deterministic damped spring supplies heave, pitch and roll. The rendered car follows that state. A kerb does not invoke jump/airborne physics or increment wall-contact counts. Ground kerbs are ignored on bridge decks and while airborne. Suspension settles after leaving the kerb.

Measured isolated crossing from 20 m/s on Original+: forward peak heave 0.01809 m, maximum pitch 0.01041 rad, speed difference after 100 ticks 0.04032 m/s; reverse peak 0.01801 m and speed difference 0.02132 m/s. This is the kerb-only difference from an otherwise identical paved test. The real creator capture includes the existing grass response and reaches 0.03218 m body heave.

## Contracts and identity
- Physics: `arcade-planar-0.21`.
- Creator compiler: `creator-compiler-10`; deterministic starter golden hash `7fe32b621ab386ea41eec94557a25510a6cde682d32651b959440732ccd9e443`. Native surface-cell golden dimensions and counts are unchanged.
- Visual kit: `track-kit-17`.
- Diagnostic recorder schema: 7. Snapshot indices 0?17 retain their meanings. Index 18 appends `[heave, pitch, roll, heave_velocity, pitch_velocity, roll_velocity]`, giving 19 top-level entries. Heave uses metres; angles use radians; velocities are per second.
- Existing local-record keys already include physics identity. Old records remain stored under their old rules and are not compared with the changed driving response. User document schema remains v5; no files are deleted or migrated.

## Changed files
- `game/track/road_edges.gd`, `road_kerbs.gd`, `kerb.gdshader` (+ Godot UID files): pure shared geometry, height lookup and raised material.
- `game/track/native_track.gd`, `playground_data.gd`: canonical wheel-support query.
- `game/track/native_track_visual.gd`, `terrain.gdshader`: raised mesh construction and replacement of flat native kerb paint.
- `game/vehicle/vehicle_simulation.gd`, `vehicle_state.gd`, `game/core/game.gd`: bounded response, spring snapshot and presentation.
- `game/editor/track_compiler.gd`, `game/persistence/handling_recorder.gd`: versioned contracts.
- `game/tests/test_kerbs.gd` (+ UID), `test_road_pieces.gd`, `test_tracks.gd`, `test_creator.gd`: response/replay/mask/geometry coverage and explicit revised schema/golden assertions.
- `scripts/dev.ps1`: TestKerbs, CaptureKerbs and full-validation inclusion.
- This document, creator-format/status/plan notes and `docs/evidence/raised-kerbs/`.

## Actual checks and captures
All Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned Godot 4.7.2. No PATH alias was used.

- `Import`: succeeded; existing missing Android build-tools diagnostic remains.
- `TestKerbs`: 31 checks, zero failures: bevel/crown interpolation, off-strip misses, forward/reverse impact, bounded pitch, speed loss, settling, one-sided roll, stationary behavior, bridge/airborne exclusion, top-speed crossing, exact full-state replay at 1/2/4/8 ticks per render batch, schema pinning, painted openings, headless rebuild agreement, dirt exclusion and native/remix support.
- `TestPieces`: 164 checks, zero failures; all flat-surface normals, raised crown/bevel normals, physical UV run lengths, full fitted blocks, closed tapered seams, native cells and the five-lap zero-contact witness remain asserted.
- `CaptureKerbs`: 39 graphical/functional checks passed; actual before/crossing/after images from a native creator curve and real canonical simulation. This uses a separate inspection camera to expose the profile, not a gameplay-camera change.
- `CaptureStyle -StyleDocument <APPDATA>/Circuit01Lab/tracks/track_5765ff853b63dea5.json`: start plus twelve route views, native cells preserved, flat road normals upward. Owner document read only.
- `Snapshot -Track slicks_freeway_test`: actual native-track capture inspected.
- `git diff --check` and staged patch check: passed.
- Full `Validate`: passed import, 93 script parses, main-scene startup and all 21 domain/UI suites (1360 checks, zero failures). Complete log: [validation.log](evidence/raised-kerbs/validation.log).

[Before crossing](evidence/raised-kerbs/before.png) ? [On the kerb](evidence/raised-kerbs/crossing.png) ? [After crossing](evidence/raised-kerbs/after.png) ? [Curvy gameplay](evidence/raised-kerbs/curvy.png) ? [Native circuit](evidence/raised-kerbs/native.png).

During development, an inferred untyped triangle-index array required an explicit Array declaration; a legacy snapshot assertion required the explicit new 19-entry contract. Native per-cell crowns were joined after graphical review. A later UV check exposed unintended raster shoulders on standalone creator pieces; source raster kerbs are now built only for native/legacy circuits or explicit native remixes. No failing invariant was removed: flat-surface normals and physical UV checks remain; kerb normals now assert the requested raised facets, and new seam/contact agreement checks cover the changed geometry.

## Remaining acceptance
Owner driving-feel and appearance acceptance remain open. This is a bounded arcade kerb/suspension approximation, not a full 3D tyre/suspension solver. Native edges retain their source raster stair-stepping; narrow source cells necessarily have tighter bevels. Imported concrete-near-asphalt interpretation remains an inferred source semantic. Added triangle/query cost, motion aliasing and phone thermal performance are unmeasured. No physical-phone test, Android export or continuous-motion video capture performed; device attachment was not enumerated. Existing ObjectDB exit warnings in some regression suites are recorded in logs, not claimed fixed. No external assets, dependencies, services or AI calls added.
