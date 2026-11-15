# Gradual five-car optimisation toward 15% (2026-11-15)

The owner accepted the first Forklift review point and asked to aim for 15% reduction across the five finished cars. Challenger remains work in progress and is excluded. The target is cumulative from the restored pre-10k baseline, as stated before implementation; Forklift therefore receives a small additional reduction after its accepted 11.72% step.

| Stock racing model | Restored baseline | Before this step | Reviewed result | Cumulative reduction |
|---|---:|---:|---:|---:|
| Rally | 19,074 | 19,074 | 16,653 | 12.69% |
| Kart | 24,223 | 24,223 | 20,590 | 15.00% |
| Forklift | 26,472 | 23,370 | 22,502 | 15.00% |
| Volt | 19,826 | 19,826 | 17,015 | 14.18% |
| Hover | 22,068 | 22,068 | 18,758 | 15.00% |
| **Total** | **111,663** | **108,561** | **95,518** | **14.46%** |

Rally and Volt stop short of the numerical target to retain safer geometry. This is one review point, with no compulsory 10k endpoint or automatic next reduction.

**C1501 — Limited offline authoring.** Select one qualified candidate per source mesh, avoiding double-counted alternate methods. The selected set has 308 source identities: 69 boundary-locked original-corner candidates and 239 source-projected candidates. Existing complete-frame `car_detail_v1` recipes retain enclosed/zero-area reductions, exact source/bounds guards and articulation context. Hover uses its existing native race/coarse resource paths; full assets stay separate. Publication writes 384 explicit source bindings, with immutable meshes before recipe manifests. There is no runtime simplifier or production construction, shader, camera, quality or handling change.

**C1502 — Review immediately and retain protection.** Helmets, driver morphs, glazing, cabin/roof seals, arches, contour joins, thin paint overlays and the Kart steering assembly are excluded. Source-projected opaque fittings preserve contact/extreme anchors, and interpolate original normals, UVs and colour fields with recorded barycentric witnesses. Two Rally lamp components use regular original-profile angular resampling, preserving lenses and gaskets; an initial bezel proposal exceeded 2 mm and was rejected in favour of 20 angular samples. Every selected part passed the unchanged 2 mm sampled world-scale surface limit, with a maximum of **1.830 mm**. Samples include all used vertices and triangle centroids in both directions; this is not an exhaustive surface-distance proof.

Connectivity, boundary-component and Euler checks reject topology damage without adding nonmanifold edges. Original-corner candidates retain encoded source corner records. The proof handles equivalent collinear subdivisions and source float precision; retained positive/negative controls accept a subdivided square and reject a real missing face. Source-projection witnesses validate fields and touching anchors. Witness arrays remain offline and are not shipped in runtime resource metadata.

The first staging attempt exposed protected Kart steering contexts. Those source identities were excluded before publication; the final stage and Kart preview passed. Deprecated LOD, broad bevel and excessive-deviation proposals were rejected, and alternate candidates were not summed as independent savings. Early fixture/JSON index conversion problems and the original rejected receipts remain recorded. No existing assertion or 2 mm limit was weakened.

[Five-car before/after comparison](evidence/car15-2026-11-15/front-comparison.png) and [critical-detail comparison](evidence/car15-2026-11-15/details-comparison.png) show the final prepared Compatibility models. The left Forklift image already includes the accepted first iteration; the row caption states the cumulative result from restoration. Review found small fitting/highlight changes, with the helmet, Rally windshield and Volt roof seal intact. Fine faceting and interrupted Volt door-seam segments also occur in the baseline; this task does not claim flawless surfaces or pixel identity.

**C1503 — Rebuild consumers and verify appearance.** Five fixed/editable, full/simple bases, all fitted-part outputs, Garage references and the stock header template are rebuilt from current sources, followed by scoped picture/import refresh. Full master GPU streams and articulation/shadow controls are compared with portable task-start signatures. Matched native stock/fitted front/rear/side/top/distant views include real shadows and close views of the owner-marked helmet, Rally windshield, Volt roof joins and Forklift equipment. Every before/after pair restores its baseline as a stability control.

**C1504 — Measured review point and reversibility.** Final command receipts, measurements, source fences and the authored resource/source checkpoint live in [evidence](evidence/car15-2026-11-15/). The checkpoint excludes derived scenes/pictures, which must be rebuilt if reversed. It uses a disposable private Git repository and leaves the shared main index untouched during checkpointing. Concurrent Garage, Challenger, documentation and index work is preserved rather than included in this change.

This step removes 13,043 stock master triangles (12.01% from task start) and lowers encoded stock mesh buffers from 4,332,406 to 3,750,006 bytes (**13.44%**). The cumulative 14.46% triangle saving includes the prior Forklift step. Stock/fitted surface counts remain unchanged. Equipped samples are Rally 24,450, Kart 22,670, Forklift 25,468, Volt 24,467 and Hover 29,278 triangles; fitted-part choices have different savings from stock.

| Desktop studio stock sample | Front viewport primitives before → after | Distant before → after | Front draws, Compatibility / Mobile |
|---|---:|---:|---:|
| Rally | 23,116 → 20,695 | 22,324 → 20,543 | 64 / 58, unchanged |
| Kart | 28,265 → 24,632 | 26,439 → 23,122 | 67 / 48, unchanged |
| Forklift | 27,412 → 26,544 | 26,076 → 25,272 | 39 / 32, unchanged |
| Volt | 23,676 → 21,057 | 22,588 → 19,865 | 51 / 44, unchanged |
| Hover | 24,950 → 22,606 | 22,818 → 20,518 | 23 / 21, unchanged |

These viewport counters include studio/shadow work and existing LOD selection; they differ from master triangle counts. They are matched desktop samples, not GPU timing or FPS measurements. The largest mean crop difference across 82 stock/fitted views is 1.434/255 in Compatibility and 1.197/255 in Mobile, both on distant fitted Kart. All 164 native pair restoration controls are exact. [Detailed measurements](evidence/car15-2026-11-15/measurements.json) retain every view, counters and pixel differences.

Initial icon verification used an invalid resource-relative output directory; the output path was corrected to an absolute task directory. Its repeat then correctly exposed an already-populated disk cache from the interrupted fixture. A fresh isolated profile passed the original capture/cancellation/disk-reuse assertions. The original failures are retained, without changing production icon code or weakening the test. The pixel-measurement helper uses native System.Drawing because Pillow is not installed.

| Final validation | Result |
|---|---:|
| Reviewed source stock budgets | 5 checks / 0 failures |
| Prepared budgets, actual base/module hits and five exact full masters | 30 / 0 |
| Actual recipe source/bounds/protection and negative controls | 789 / 0 |
| Every fitted kit for all five cars | 7,545 / 0 |
| Native before/after, 82 pairs per desktop renderer | 343 / 0 each |
| Actual Garage/race App, canonical handling and steering | 48 / 0 each renderer |
| Prepared Kart driver/steering geometry and poses | 170 / 0 each renderer |
| Header icon appearance, capture cancellation and disk reuse | 496 / 0 each renderer |
| Driving regression | 72 / 0 |
| Production parser | 576 scripts / 0 failures |
| Final prepared preflight excluding Challenger | 468 resources, 1,925 checks / 0 failures |
| Scoped catalogue provenance | 5 pictures, 173 current source hashes |
| Native picture imports | 10 verified, 0 editor diagnostics; project settings exact |
| Final source fence | 25,539 stable consumed inputs; all 384 published source hashes exact |

All four unrelated car keys, including Challenger, remain unchanged from the publication snapshot. Challenger's source and the main index changed concurrently earlier in the task; their current contents are preserved. Production construction, dependency routing, handling/ghost controls and the five configurations match the task-start controls. This is a scoped model qualification, not a clean whole-project test claim.

Representative actual commands (the per-command receipts retain full engine arguments and isolated paths):

```powershell
python scripts/select_car15.py
python scripts/run_car15.py stage-final res://tests/stage_car15.gd --headless
python scripts/review_car15_selection.py
python scripts/publish_car15.py
python scripts/run_car15.py source-final res://tests/test_car15.gd --headless
python scripts/refresh_car15_assets.py
python scripts/run_car15.py prepared-models res://tests/test_car15.gd --headless -- --prepared
python scripts/run_car15.py prepared-native-gl res://tests/capture_car15.gd --rendering-method gl_compatibility
python scripts/run_car15.py prepared-native-mobile res://tests/capture_car15.gd --rendering-method mobile
python scripts/qualify_car15.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car15.ps1
python scripts/measure_car15_results.py
python scripts/close_car15.py
python scripts/checkpoint_car15.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Selected geometry proof](evidence/car15-2026-11-15/selected-geometry.json), [publication](evidence/car15-2026-11-15/publication.json), [final closure](evidence/car15-2026-11-15/closure.json), [source/resource checkpoint](evidence/car15-2026-11-15/source-checkpoint.json) and [binary review patch](evidence/car15-2026-11-15/source.patch) record exact scope. The standard build-retention output is retained in `build-retention.log`; candidate-only draft captures and private profiles stay disposable under `build/`.

Device testing was not performed. Reload/owner appearance review remains before the next reduction; no FPS, whole-project, export, backend request, deployment or owner-save/process acceptance is claimed.
