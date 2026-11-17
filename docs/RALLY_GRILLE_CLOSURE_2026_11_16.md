# Rally fascia see-through repair (2026-11-16)

The owner-marked opening beneath the grille is closed. The same repair also removes the triangular gaps in the lower painted strip and the dark fascia beside the grille. [Matched front and low-oblique comparison](evidence/rally-grille-closure-2026-11-16/grille-closure-comparison.png).

**RGC01 — Repair the exterior and its generator.** The grille aperture clipper emitted some triangles with winding opposite their outward normals. This occurred because the painted steel and dark applique use opposite parameter directions. The face-removal recipes then discarded much of that wrongly facing exterior. Clipped polygons now select Godot's clockwise winding from their existing interpolated normals. Both actual native front-coachwork resources are regenerated: 1,648 full and 512 simple triangles. Native triangle positions, normals and UVs match the originals exactly after ignoring vertex order; every new native front triangle faces outward.

The two affected frame recipes retain the complete original painted and dark fascia panels. New complete surface-frame bindings retain every unrelated reduction row. The surrounding grille, preferred reflector lamps, bumper, body shape, wheels, liveries and handling retain their designs. No extra covering box, material or runtime simplifier is added.

**RGC02 — Preserve the gradual reduction.** The painted panel changes from 316 to 512 triangles and its dark applique from 308 to 428, a measured total increase of **316**. Stock Rally changes **14,592 to 14,908 (+2.17%)**; the fitted sample **22,413 to 22,729**; full remains **100,356**. Every non-target raw and post-detail member and every unrelated reduction row is checked exact. Source coverage uses 2,844 stations in each of the fixed/editable frames, excludes the intended grille aperture, and tests only outward-facing triangles of the actual layered exterior. Corrected coverage has **0 misses**; the original reduced panel with the same surrounding fascia has **509 misses**, rejecting the unchanged coverage gate. Actual prepared base/four-module hits and all three model counts are verified.

**RGC03 — Verify receiving models and refresh derived assets.** Actual source comparisons cover front/low-front/low-left/low-right, simple/full, before/after: sixteen images per desktop renderer. The actual App checks Garage and race geometry and canonical configuration. All Rally base scenes, 78 optional-kit scenes and Garage model are genuinely rebuilt; complete scoped preflight covers 83 resources. The final Rally fence is stable across 18,475 consumed inputs.

| Check | Actual outcome |
|---|---|
| Exterior, exact members/rows, native shape and cost | 5,712 checks, 0 failures |
| Retained grille/lamps, original aperture, source/native equality, wash/night | 274 checks, 0 failures |
| Actual prepared stock/fitted/full consumers | 7 checks, 0 failures |
| Complete Rally prepared resources | 83 resources, 343 checks, 0 failures |
| Native Compatibility / desktop Mobile views | 16 matched images each; manually inspected |
| Actual desktop Mobile App | 8 checks, 0 failures; clean runner |
| Actual Compatibility App | 8 checks, 0 failures; runner rejects retained 2-object/1-resource shutdown diagnostic |
| Production parser | 581 scripts, 0 failures |

The Rally catalogue/header pictures and globally versioned six-car selection portraits are actually rendered again; eight native image imports are verified with no editor diagnostics and exact project settings. The other cars' portraits are derived UI artwork. No other-car model source is authored. A conservative shared `compact_*.gd` dependency also required a cache-only Challenger refresh; its source changed concurrently and the original full shared source fence rejects that run. No Challenger appearance/GPU/readiness claim is made. A subsequent scoped reconciliation also rejected a concurrent identity-generator edit. The final actual Rally rebuild and its strict scoped fence are retained separately; no metadata is restamped to bypass stale-source checks.

Initial controls remain in the evidence directory: a probe queried global transforms before tree entry; a corrected deferred probe is clean. The first source inventory process exited abnormally after recording its measurements. An indentation error in a generated harness was corrected before use. Two-sided ray tests initially hid the winding defect; front-facing ray tests exposed it. A panel-only gate also revealed the adjoining clipped fascia defect; the production clipper and both source panels were then repaired, retaining the zero-gap assertion. The preliminary +196 estimate covered only painted steel; the exact final cost proof includes the additional 120 fascia triangles. The initial prepared count fixture used that incomplete estimate and fails before the final exact two-panel count proof. Rejected prototype frame JSONs are archived under the task build directory and removed from production. The first completed picture pass then rejects its old model identity after those prototype inputs are removed; the final pass follows the real final rebuild.

The seven authored production files are the clipper, two native resources, two new detail-frame JSONs and two new surface-frame JSONs. [Exact paths and before/after hashes](evidence/rally-grille-closure-2026-11-16/publication.json). Other authored files are task harnesses, this report and the three tracker marker blocks, listed in the checkpoint receipt. Concurrent source/index work is preserved.

Representative actual commands; each engine receipt retains full arguments and diagnostics:

```powershell
python scripts/run_rally_grille_closure.py baseline res://tests/capture_rally_grille_closure_baseline.gd --headless
python scripts/run_rally_grille_closure.py native-bake res://tests/bake_rally_grille_closure.gd --headless
python scripts/run_rally_grille_closure.py migrate-winding res://tests/migrate_rally_grille_closure.gd --headless
python scripts/run_rally_grille_closure.py geometry-costs res://tests/test_rally_grille_closure.gd --headless
python scripts/refresh_rally_grille_closure.py
python scripts/artwork_rally_grille_closure.py
python scripts/close_rally_grille_closure.py
python scripts/checkpoint_rally_grille_closure.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Closure](evidence/rally-grille-closure-2026-11-16/closure.json), [source patch](evidence/rally-grille-closure-2026-11-16/source.patch) and [checkpoint receipt](evidence/rally-grille-closure-2026-11-16/source-checkpoint.json) retain a byte-exact forward/reverse checkpoint without staging the shared index. Reversal requires a real dependent-cache rebuild. Standard retention is applied without a task pin. No phone/device test, FPS qualification, export, backend/deployment or owner-save/process action is performed. Reload and owner appearance acceptance remain.
