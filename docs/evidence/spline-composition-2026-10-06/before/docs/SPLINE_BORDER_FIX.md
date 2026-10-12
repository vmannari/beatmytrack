# Smooth spline borders and kerbs — 2026-10-06

Owner correction: steep spline curves produced crossed white borders and triangular kerb tips inside the road. Requirement IDs: R01, T01–T04, V03–V05, Q01, SP01–SP03; SP04 (simple exposed spline boundary), SP05 (smooth curved kerbs). This supersedes the folded-offset limitation in [SPLINE_ROADS.md](SPLINE_ROADS.md).

Spline roads now draw their exposed swept boundary. Folded offset lines inside overlapping portions of the same spline are removed; inward corners are rounded and curved perimeter sections retain the existing red/white kerbs. Kerb widths taper where their grass-facing offset would otherwise fold around a very small radius. Joined mouths stay open, and genuine enclosed islands remain holes in the asphalt. Free ends have smooth caps rather than leaving the raster end visible behind a square visual cutoff. The five authored points, their widths, road position/heading/flip, automatic route and editor controls remain independent of this boundary repair.

## Implementation and contracts

New pure `SplineBorders` constructs the union of bounded, variable-width swept spans. It includes every authored point sample and otherwise uses approximately 0.70 m intervals. The original centreline/width samples and native surface rasterizer are unchanged. Polygon union removes internal folds; holes are retained as subsequent spans enter them. Bounded simplification removes microscopic clipping fragments, and quadratic corner fillets round remaining sharp boundary turns. Join caps are cut only locally so a distant returning road branch is retained.

Rendering and canonical kerb construction use `RoadEdges.section_contours`. The editor's pending/selected spline overlay uses the same contour algorithm and caches four immutable previews locally. Contour caches belong to one construction operation, with no global simulation cache or display-rate input. Asphalt tessellation treats all contours together, so it fills road slabs without filling a real grass island or drawing overlapping road strips. Curvature is measured along the exposed spline perimeter over a distance window, allowing continuous kerbs even when a tightly folded inner centreline offset no longer exists. Concave kerb offsets are bounded by the local radius. Other block types retain their existing border/kerb construction.

The implementation uses the pinned engine's native polygon union, difference, convex hull and round offsets. See [Godot Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html) for these operations. No third-party dependency or generated artwork is added.

**creator-compiler-22** versions the changed spline contact geometry; **track-kit-113** invalidates cached old road meshes. Authoring remains additive `creator-track-v5` with no player-file migration or deletion. Existing compiler/hash goldens advance, while recorded input frames, timing assertions, physics/rules versions and original native road-grid geometry remain intact. The verified oval fixture changes only its compiler-version and content-hash fields. Standalone verifier staging now includes `spline_borders.gd` and its UID.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`; Windows desktop Compatibility/OpenGL on RTX 3090. Actual commands:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import`: exit 0; registers the new geometry helper.
- `... TestScript -ScriptPath res://tests/test_spline_borders.gd -Graphical`: final **1,111 checks, zero failures**. The reference-like steep S fixture demonstrably crosses its old raw offset edges. Corrected contours have zero proper crossings, are triangulatable, preserve authored points/widths, retain continuous kerbs with no folded strips, keep joined mouths open, and work with variable widths and mirroring. A returning loop keeps exactly one real central island; tessellation leaves it unfilled. Synthetic slab test retains the exact 364 m² annulus area. Four legacy-biome road mesh arrays are exactly equal to the task-start renderer snapshot. The real app/editor completes its build and supplies inspected desktop, compact, selected and close-up screenshots.
- Final boundary build is about **13–15 ms**, with **207 vertices** for the steep fixture. The initial unbounded circle-union output had 11,384 vertices, about 308 ms boundary construction and an actual 30-second editor-build timeout. Bounded swept spans/simplification corrected this without relaxing the build deadline or contour assertions. These are desktop observations, not phone performance measurements.
- `... TestScript -ScriptPath res://tests/test_spline_road.gd -Graphical`: **479 checks, zero failures**. Final headless repeat after kerb taper: **476 checks, zero failures**. Both include **five laps / 13,517 ticks / zero contacts** and exact recorded-input replay, alongside point widths, persistence, snapping, undo/redo and pinch behavior.
- `... TestKerbs`: **31 checks, zero failures**, including real physical kerb crossing.
- `... TestPieces`: **377 checks, zero failures**, including five-lap road races and exact replay.
- `... TestCreator`: **113 checks, zero failures**; original 228×188 grid, 219 route points and 8,715 road cells remain pinned, with all retained diagnostic replay/timing assertions.
- `... TestWorkflow`: **252 checks, zero failures**.
- `... TestRoadCache`: **66 checks, zero failures**.
- `... TestScript -ScriptPath res://tests/test_script_parse.gd`: **311 scripts, zero failures** (before the final equivalence-test addition, which also compiles and passes in the final graphical run).
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -k 'spline or standalone_verifier or real_five_lap or variable_width_route or validated_saved_route'`: **10 passed / 53 deselected**, including genuine packaged-verifier spline validation and the unchanged existing five-lap oval recording/times. Existing Starlette deprecation warning retained.
- Final packaged-helper repeat after the kerb taper, `-k 'standalone_verifier or spline'`: **7 passed / 56 deselected**; overlaps the previous batch and verifies the final helper in the stripped canonical project.

`TestRoadBuild` still fails its older checked-in **desert** mesh hash (`ROAD_EQUIVALENCE ... desert`, `Road mesh arrays differ: desert`). The independent task-start renderer comparison passes exact mesh-array equality for **pine, desert, winter and night_city**, proving this task preserves those pre-existing legacy meshes. The old golden is retained, and **TestRoadBuild/full Validate are not claimed green**. No full Validate was rerun; its previously recorded unrelated menu/HTTP test failures are not repaired or suppressed by this task.

An intermediate mixed spline/legacy rendering run exposed an untyped-array fallback assigned to `Array[PackedVector2Array]`; replaced with explicit typed-array append operations and the original mixed-road suite passes. Early kerb classification yielded isolated tips because nearest dense centreline samples missed perimeter curvature; the final distance-window perimeter classification is tested with a minimum continuous-segment count.

## Files, evidence and remaining acceptance

Runtime: new `game/editor/spline_borders.gd` and UID; `game/editor/road_pieces.gd` (preserves spline node sample indices), `editor_canvas.gd` (shared overlay and bounded cache), `track_compiler.gd`; `game/track/road_edges.gd`, `road_kerbs.gd`, `native_track_visual.gd`; `backend/deploy/stage_verifier.py`.

Tests/contracts: new `game/tests/test_spline_borders.gd` and UID; `game/tests/test_creator.gd`, `backend/tests/test_verifier.py`, `backend/tests/fixtures/verified_oval.json` (versioned identities only); `scripts/dev.ps1` adds the border regression to Validate. Documentation: this file, a follow-up link in `docs/SPLINE_ROADS.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Evidence and exact task-start source snapshots: `docs/evidence/spline-borders-2026-10-06/`. [Close-up](evidence/spline-borders-2026-10-06/bends-closeup.png), [desktop](evidence/spline-borders-2026-10-06/steep-1280x720.png), [compact](evidence/spline-borders-2026-10-06/steep-960x540.png), [selected spline](evidence/spline-borders-2026-10-06/selected-1280x720.png). The supplied owner screenshot is diagnostic reference, not a shipping asset. `python docs/evidence/spline-borders-2026-10-06/create_checkpoint.py`, `git apply --reverse --check` on its scoped patch, and scoped `git diff --check` each exit 0. The task-only patch and normalized source hashes provide the review checkpoint without staging concurrent work.

No phone attachment check, Android export/install or physical-device test was performed. Owner visual acceptance and phone performance on larger spline maps remain outstanding. No backend/cloud/NAS deployment was performed; online use requires a matching compiler22 rollout/current immutable revisions. This task does not rewrite live published documents or records. Shared-workspace cloud/test-driver, checkpoint, privacy, desert and other work is preserved.
