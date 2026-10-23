# Catalog road coverage review - 2026-10-16

CRR01: review the other available tracks for the Ajorata grass-through-road clipping failure. CRR02: compare original and corrected road coverage, including actual prepared/native geometry. CRR03/G01/R01/Q01: retain source documents, physical road data, rendering/cache contracts and a reproducible regression for any additional affected track.

The same large clipping failure also affected **Saw**. The existing shared `ShoulderMesh` correction from the Ajorata task already repairs it; this review makes **no further runtime-code or visual-version change**. Native before/after views reproduce Saw's triangular grass patch with the saved original helper and show continuous asphalt with the current helper. A new Saw regression checks three points across the original hole in CPU-prepared, direct native and uploaded prepared meshes, while preserving the document and canonical data.

All **27 entries in the retained local Free Race cache** were reviewed: 17 Grass, 3 Night, 4 Desert, 2 Winter and 1 Storm. Each selected document's SHA-256 matches its cache index. This is the actual local cache snapshot, not a fresh server listing. Two additional authored local draft variants, Ajorata and Easy night, were checked independently because their road documents differ from the cached versions. Both have zero remaining strict coverage findings; the local Ajorata draft reproduces the original bug and is repaired by the same shared fix. Eight other local drafts have no road pieces. The built-in Starter Circuit uses native `surface-grid-v2` with no authored road pieces and bypasses the polygon-clipping path; the cached creator version of Starter Circuit is included in the 27-track review. Retired v1-v4 files and hidden workflow fixtures are retained and are outside the playable-catalog review.

`game/tests/review_catalog_road_coverage.gd` compares independent horizontal scanline intervals across the entire authored ground road, spaced 25 cm apart, against triangulated/clipped geometry and actual CPU-prepared road arrays. The main catalog covers 9,320 rows for each representation. The original helper is instantiated from the saved pre-Ajorata source. Winter's direct-road path is reviewed without incorrectly applying the union operation. Bridge ground mouths retain their existing trims; elevated decks are visible in the native overviews. Exact document and canonical cell/kerb/route snapshots remain unchanged for all 29 documents.

The large original sampled deficits were approximately 73.51 m2 on Ajorata and 31.05 m2 on Saw. These are scanline area estimates, not exact polygon areas. The large holes disappear with the current code. The other 25 catalog tracks have identical original/current residual gap measurements. Prepared geometry has exactly the same residual gap positions and widths as the current geometric model on all 27 tracks; nearest-edge distance calculations can differ by fractions of a micrometre after subdivision.

The review does **not** establish mathematically perfect coverage. The fixed **0.1 mm** strict diagnostic still flags **69 sampled boundary intervals on 15 tracks**, counted as **30 failed path/track checks** because both the geometric model and prepared mesh are checked. Recorded distances to mesh boundaries range from just over 0.1 mm to about 0.9813 mm. These small residuals already exist with the original helper; the other 25 tracks' measurements are unchanged. Saw retains three small residual intervals after its large hole is repaired. The diagnostic failures are retained in `prepared.json` and its log, and the threshold was not increased to obtain a passing result. Native inspection found no additional visible grass patches of the reported kind. This is not an all-zero geometry or exhaustive moving-view claim.

| Actual pinned Godot 4.7.2 check | Result |
| --- | --- |
| Original/current/prepared scan of the complete cached catalog | 27 tracks completed; strict 0.1 mm diagnostic retains 30 failures as described above |
| Actual original/current residual comparison | Other 25 catalog tracks unchanged; prepared gap positions/widths match current geometry for all 27 |
| Current local Ajorata/Easy night draft scan | 2 tracks, zero strict failures |
| New Saw original-hole/CPU/direct/uploaded regression | Headless 17/17; Compatibility 17/17; Mobile/Vulkan 17/17 |
| Corrected native current catalog captures | 27/27 Compatibility and 27/27 Mobile/Vulkan |
| Native local draft captures | 2/2 on each renderer |
| Native original Saw reproduction | Both renderers, matching map/detail views |
| Final project parser | 811 scripts, zero failures |

Evidence is in `docs/evidence/catalog-road-review-2026-10-16/`. The two `current/contact-sheet.png` files show the catalog; `current-drafts/` contains the local variants. Compare each renderer's `before/saw-detail.png` with `current/saw-detail.png`. Full maps are 1280x900. Diagnostic overhead cameras and labels are confined to the capture helper; runtime camera, road finish and lighting code are unchanged. Night maps retain their original dark lighting. These captures are not whole-screen byte comparisons or evidence of phone performance.

Changed task files are the review helper, native capture helper, `game/tests/test_saw_road_coverage.gd`, its unchanged-source Saw fixture and their generated UID files, plus this record and project status notes. The review's four inspected road runtime files remain byte-for-byte identical to their task-start snapshots. `report.json` records hashes and commands; `classification.json` records the per-track conclusions. `task-only.patch` excludes all prior Ajorata runtime changes and unrelated concurrent work. No mixed-workspace commit is made.

Representative actual commands, with a separate workspace APPDATA profile for each process:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/review_catalog_road_coverage.gd -CommandTimeoutSeconds 900
# Retained nonzero exit from the strict catalog diagnostic is described above.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/review_catalog_road_coverage.gd -TestArgument '--drafts' -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_saw_road_coverage.gd -CommandTimeoutSeconds 240
# Saw native regression: add -Graphical -RenderingMethod gl_compatibility or mobile.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_catalog_roads.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 900
# Native original Saw: add -TestArgument '--baseline'. Local variants: '--drafts'.
```

The review helpers consume read-only snapshots and manifests under `build/catalog-road-review-2026-10-16/`; the source/hash inventory is retained with the evidence. `snapshot_catalog.py` records how those exact documents were selected and copied. They do not fetch or modify server tracks or player data.

Initial attempts are retained. A horizontal-only 0.1 mm interval test exaggerated errors where a scanline grazes a nearly horizontal edge; the refined diagnostic measures actual mesh distance at the midpoint and both quarter points, retaining the same perpendicular allowance. It still fails on the 15 documented tracks. The initial Compatibility contact sheet mixed RGB/RGBA formats; the saved captures were intact, and the helper now converts thumbnails to RGB. Initial overviews placed the diagnostic camera at 200 m beyond its existing 180 m far plane, so they showed the background and were rejected on inspection. Final overviews use 100 m with an explicit far-plane assertion; both renderers were recaptured successfully. The rejected sheets/logs are saved separately and are not acceptance evidence.

No phone attachment check, phone test, APK export/install, backend operation or deployment was performed. Owner appearance acceptance, physical-phone moving-view checks and future/uncached track versions remain outside this review.
