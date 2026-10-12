# To the trees: folded curve borders — 2026-10-08

Owner report: the supplied race screenshot shows triangular white paint, shoulders and kerbs at two tight bends on **To the trees**. Requirements: R01, T01–T04, V03–V05, Q01; RB01 (simple exposed borders on tight ordinary road pieces), RB02 (continuous joined mouths).

The exact cached original track reproduces the screenshot. Its third piece is a 10.5 m wide S-bend with radius 8.496 m and height 27.278 m. The changing curvature makes its inner offset double back: the old visual contour has **two proper self-intersections**, both at road margin 0 and marking margin −0.20 m. Local smoothing cannot remove those folds. The repaired view has **zero intersections**, removes the triangular paint/apron/kerb tips, and retains the existing kerb placement on inside bends.

## Correction and contracts

`VisualRoadJoin` detects proper crossings of ordinary piece outlines. Only folded pieces use the existing exposed swept-boundary builder, with genuine holes retained. Each build owns its contour/cache state. Joined mouths retain their exact shared cross-section before the existing cosmetic rounding; both adjacent pieces then share identical tips within 0.000004 m on the actual track. Road fill, edge markings, sandy shoulders and cosmetic kerbs follow the same simple contour. Very tight grass-facing kerb offsets use the existing bounded radius taper. Solitary folded pieces also use the cosmetic kerb repair.

Ordinary uncrossed pieces retain their original construction. Four-biome tests compare exact road mesh arrays, original join shapes and original cosmetic kerb triangles against saved task-start sources. **track-kit-116** invalidates old baked presentation meshes. The fixture retains compiler22 content identity `1617ca276e8e3de24c70b247faebcd29299b461b22183f4e253f155df246c0bf`; physical kerb triangles, surface cells, authored coordinates/objects/start line, physics and rules remain unchanged. No player file or published revision is rewritten; this correction needs no backend rollout.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, using `scripts/dev.ps1`, Windows Compatibility/OpenGL on RTX 3090. Tests use workspace-local `APPDATA=build/tree-bends-userdata` and isolated records/cache. Commands below were actually run with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Actual result |
|---|---|
| `TestScript -ScriptPath res://tests/test_tree_road_bends.gd -Graphical` | Final **96 checks, zero failures**: exact owner track, both road/marking borders, six rotated/mirrored tight bends, open matching joins, exact ordinary-road/kerb equivalence and canonical-data preservation; four captured views. |
| `TestShoulders` | Union area 30 m²/10 triangles, **71 visual-join and 18 internal-contour checks**, zero failures. |
| `TestRoadCache` | **66 checks, zero failures**; persistent cache round trips, invalidation and bounds. |
| `TestPieces` | **377 checks, zero failures**; genuine five-lap runs with zero contacts and retained replay checks. |
| `TestScript -ScriptPath res://tests/test_spline_joins.gd` | **124 checks, zero failures**; no cross-lane marking/apron triangles, physical kerbs preserved. |
| `TestScript -ScriptPath res://tests/test_spline_borders.gd` | **1,107 checks, zero failures**; steep curves, variable widths, genuine holes and four legacy-biome comparisons. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **360 scripts, zero failures**. |
| `Import` | Final exit 0; registers the new regression UID. |

Final isolated contour-build measurement for all nine ground pieces at both margins: **63.993 ms cold / 46.601 ms with the local contour cache**, desktop only. This measures construction, not frame time or phone performance. The renderer's existing bounded memory/disk caches remain active in ordinary use.

The initial reproduction returned **21 checks / 2 failures** and saved the matching before screenshots. An intermediate repair left 0.018–0.371 m differences at joined mouths; restoring exact shared endpoints removed them. A four-biome equivalence run caught incorrect hole classification on clockwise ordinary outlines; the final classification retains their original solid treatment. Early test-only cache-reference and packed-array type errors were corrected. An earlier timing label included diagnostic assertions; final measurements time construction only.

Initial sandbox runs could not write the default user log/read the certificate store; subsequent approved native runs used isolated workspace data. Import and two app-dependent regressions were temporarily interrupted by a concurrently edited `track_browser.gd` with an undefined `test_histograms`. That other edit was completed independently; this task did not modify it, and final import/parser/spline suites pass. No failed invariant was weakened. Full Validate and historical road-build goldens were not run or claimed green.

## Files, provenance and review

Runtime: `game/track/visual_road_join.gd`, `game/track/native_track_visual.gd`. Regression: `game/tests/test_tree_road_bends.gd` and UID, `game/tests/fixtures/to_the_trees.json`; `scripts/dev.ps1` registers it in full Validate. Documentation: this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. The fixture is a byte-for-byte copy of the owner's existing cached original creator document, SHA-256 `62388ecccfecaf6254ab1c34e9febdca9cf6366175cc636f6d3fac57b288f81e`; it contains no new track edits. `tests/*` remains export-excluded. No generated art or dependency was added.

[Before](evidence/tree-road-bends-2026-10-08/before/bend-32--18.png), [after desktop](evidence/tree-road-bends-2026-10-08/after/bend-32--18.png), [after compact](evidence/tree-road-bends-2026-10-08/after/bend-compact.png) are actual native captures, inspected visually. The other two captured corners are retained in the same folders. Original sources, actual logs and the [task-only review patch](evidence/tree-road-bends-2026-10-08/scoped-change.patch) retain the evidence without staging unrelated working-tree changes.

`python docs/evidence/tree-road-bends-2026-10-08/create_checkpoint.py` produces a nine-file scoped patch and normalized source hashes. It, `git apply --reverse --check docs/evidence/tree-road-bends-2026-10-08/scoped-change.patch` and the scoped `git diff --check` all exit 0. The Git index is untouched; concurrent work is excluded from this checkpoint.

No phone attachment check, physical-device test, Android export/install, backend/production deployment or full Validate was performed. Restart the desktop app to load the repaired renderer and invalidate the old kit115 mesh cache. Owner visual acceptance, in-motion inspection of every bend and physical-phone performance remain outstanding.
