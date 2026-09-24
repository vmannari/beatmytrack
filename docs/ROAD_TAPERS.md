# Asymmetric road tapers - 2026-09-24

Requirements: R01 (phone-friendly direct manipulation), T01-T04 (bounded local creator data and deterministic compilation), V03/V05 (clear editable presentation and shared editor/race geometry).

## Behaviour

The Road palette now includes **Taper**. A taper starts at the normal authored `width` and converges to `narrow_width` over its adjustable straight length. One road edge remains straight while the opposite edge converges; **Flip** swaps the straight side. The default is 14-to-6 m when created after a 14 m road, with both values bounded to the existing 6-20 m road-width contract and the narrow end prohibited from exceeding the wide end.

Tapers remain ordinary two-ended road pieces. Their shifted centre endpoint participates in snapping, connected-road route generation, roadside geometry, surface compilation and persistence. Width samples follow the asymmetric surface rather than treating the whole piece as its wide width. Existing creator-track-v5 documents remain valid because `narrow_width` is required only for `kind: taper`.

## Changed files

- `game/editor/road_pieces.gd`: taper contract, sampling, endpoint, variable widths and connected path widths.
- `game/editor/editor_canvas.gd`: accurate asymmetric preview and direct wide/narrow/length handles.
- `game/core/app.gd`, `game/editor/editor_button.gd`: Road palette entry and original vector glyph.
- `docs/schemas/creator-track-v5.schema.json`: allowlisted taper kind and bounded taper-only field.
- `game/tests/test_road_pieces.gd`: straight-edge, flip, endpoint, bounds, compile and attachment coverage.

## Verification and acceptance

Commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`.

- `TestPieces`: 362 checks, 0 failures; includes five-lap compile/replay fixtures with zero contacts.
- `TestWorkflow`: 204 checks, 0 failures.
- `TestConstruction`: 82 checks, 0 failures; taper endpoint dragging preserves the opposite endpoint. Two pre-existing ObjectDB leak warnings remain at shutdown.
- `TestCreator`: 112 checks, 0 failures across all five biomes.
- Creator-track-v5 schema: `Draft202012Validator.check_schema` passed using the repository review environment.
- `CaptureEditor`: 38 checks, 0 failures; [desktop evidence](evidence/road-tapers.png) was inspected and shows the new Taper palette action at 1280x720.
- `git diff --check`: passed before documentation update.

No phone was attached or enumerated. No Android export, installation, performance measurement or physical-device touch test was performed. Human acceptance remains for preferred default taper dimensions, palette scrolling on a phone, and the visual transition where a taper joins a differently sized neighbour.
