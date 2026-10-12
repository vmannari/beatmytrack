# Ajorata internal road-edge seam — 2026-10-08

Owner report: the marked white line runs perpendicular to the road at a connected Ajorata bend. Requirements: R01, T01–T04, V03–V05, Q01; RB03 (no paint or shoulder across a connected road mouth).

The exact cached original map reproduces the screenshot at `(14.2981,16.86583)`, where a tight curve meets an S-bend. The task-start renderer produces **63 marking triangles inside that joined driving lane**. The correction produces **zero marking and zero sandy-apron triangles across all 16 Ajorata joins**. [Before](evidence/ajorata-seam-2026-10-08/before/seam-14-16.png), [after](evidence/ajorata-seam-2026-10-08/after/seam-14-16.png), [compact](evidence/ajorata-seam-2026-10-08/after/seam-compact.png) are inspected native captures.

## Cause and correction

The curve is wider than its tight inner radius, so it uses the exposed sweep introduced by the preceding bend repair. Its two joined mouths intersect at the inner corner. Sequentially projecting an inset corner onto one mouth, then aligning it to a full-width tip, moved it off the other mouth's plane. A single matching exterior tip then received half a cosmetic fillet. The displaced closing edge failed internal-cap recognition, so it was painted and received a sandy shoulder across the lane.

`VisualRoadJoin` now collects all inset mouth constraints before moving vertices and places a shared corner at the intersection of its original planes. A truncated inner tip stays on both mouth planes. Cosmetic fillets commit only when both matching tips exist; partial fillets leave the intact cap plane. The existing strict internal-cap test then omits those edges from paint, shoulders and kerbs. No global tolerance is widened and no canonical gate or collision condition is changed.

**track-kit-117** invalidates baked meshes from kit116. Compiler22 Ajorata identity remains `e4c11a875b135001b1c648155cc8782d59c1922d6c1a8078d8ffa9b9368e6174`. Authored objects, coordinates, widths, start line, surface cells and physical kerb triangles are exactly preserved. Physics/rules and player files remain unchanged; no backend rollout is needed.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`, Windows Compatibility/OpenGL on RTX 3090. Tests use workspace-local `APPDATA=build/ajorata-seam-userdata`; captures bypass disposable disk mesh caches. Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_ajorata_seam.gd -Graphical` | **44 checks, zero failures**. Original helper reproduces the unrecognized cap; rotated/reordered narrow joins remain recognized. All 16 actual mouths have zero paint/apron triangles in their central lane, canonical data is exact, and two captures pass. |
| `TestScript -ScriptPath res://tests/test_tree_road_bends.gd` | **91 headless checks, zero failures**. Earlier To the trees repair, shared tips, exact physical data and four-biome original mesh/join/kerb comparisons remain intact. |
| `TestShoulders` | Union 30 m²/10 triangles; **71 visual-join + 18 internal-contour checks**, zero failures. |
| `TestRoadCache` | **66 checks, zero failures**. |
| `TestPieces` | **377 checks, zero failures**; retained five-lap races with zero contacts and exact replay checks. |
| `TestScript -ScriptPath res://tests/test_spline_joins.gd` | **124 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_spline_borders.gd` | **1,107 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **365 scripts, zero failures**. |
| `Import` | Exit 0; registers the new regression UID. |

Initial actual-track reproduction: **17 checks / 1 failure**, including the supplied seam. An intermediate geometry run passed the seam assertions but quit before the graphical fixture had finished releasing six resources, causing an engine shutdown error. The test now waits briefly after freeing its owned scene; final exit 0 has no shutdown warning. A diagnostic headless capture attempt emitted the existing 29-instance scene warning; the final headless regression skips graphical scene construction. No road assertion or invariant was weakened.

## Files, provenance and acceptance

Runtime: `game/track/visual_road_join.gd`, `game/track/native_track_visual.gd` (kit revision). Regression: `game/tests/test_ajorata_seam.gd` and UID, `game/tests/fixtures/ajorata.json`; `scripts/dev.ps1` adds it to full Validate. Documentation: this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. The fixture is a byte-for-byte copy of the owner's cached original, SHA-256 `69e94d9cb34bb4d3277cc2ad3f2c6d1fa34d7b5834b27df412815e611cd8931a`; `tests/*` remains export-excluded. No new image asset or dependency is added.

Actual logs, task-start source snapshots and the [task-only patch](evidence/ajorata-seam-2026-10-08/scoped-change.patch) preserve the review checkpoint without staging unrelated work. The checkpoint generator, reverse patch check and scoped whitespace check exit 0.

No phone attachment check, physical-device test, Android export/install, full Validate or backend/production deployment was performed. Restart the desktop app to load kit117 and refresh old baked meshes. Owner visual/in-motion acceptance and phone performance remain outstanding.
