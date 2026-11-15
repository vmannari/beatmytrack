Car detail reductions — 2026-11-14

Implemented the approved low-visibility opportunities from the [deeper review](CAR_DEEP_OPTIMISATION_REVIEW_2026_11_14.md). The largest improvements are Forklift **−23.23%** and Rally **−12.84%** stock master triangles. The six stock masters together fall from **163,400 to 150,275 (−8.03%)**. This sum describes catalogue geometry, not a race frame or an FPS gain.

| Stock car | Before triangles | After triangles | Reduction | Active unique mesh bytes before → after |
| --- | ---: | ---: | ---: | ---: |
| Rally | 21,884 | 19,074 | 12.84% | 804,266 → 719,308 |
| Kart | 24,554 | 24,223 | 1.35% | 1,277,372 → 1,274,442 |
| Forklift | 34,484 | 26,472 | 23.23% | 1,557,756 → 1,259,444 |
| Volt | 21,042 | 19,826 | 5.78% | 628,800 → 600,872 |
| Hover | 22,068 | 22,068 | 0% | 606,820 → 606,820 |
| Challenger | 39,368 | 38,612 | 1.92% | 1,414,416 → 1,295,408 |

Sample fitted masters, using the last option in each of four categories: Rally **29,730 → 26,600**, Kart **25,944 → 25,613**, Forklift **35,380 → 29,428**, Volt **26,472 → 26,216**, Hover **31,324 → 31,324**, Challenger **36,778 → 36,108**. These numbers are specific assemblies. The exhaustive module suites separately exercise every offered kit in both quality tiers.

**CLV01 — Straight cylinders and small fittings.** `game/vehicle/racing_car_models.gd` removes straight-cylinder height rows by setting `rings=0` in production simple models. Radii, caps and height remain. Small cylinders at most 6 cm in radius use eight sides; larger eligible cylinders retain twelve or more. The existing generic helper keeps its default axial behavior for other callers. An exact topology guard recognises only the existing plain 96-segment planar rings, selecting 24 segments below a 12 cm radius and otherwise 48. It retains encoded normals/tangents, materials, bounds and source outline radii. Textured, coloured, skinned or unfamiliar ring streams are excluded. Large tyres, body curves, glazing and the Kart driver are protected.

**CLV02 — Enclosed and zero-area triangles.** `game/vehicle/car_detail_reduction.gd` loads offline recipes rather than searching or simplifying geometry at runtime. The producer examines stock, editable stock and every offered kit. It accepts only strict zero-area faces or triangles whose three vertices are at least 0.5 mm inside one opaque, closed, consistently wound convex solid in the same articulation frame. Kit boundaries, wheels, steering, fans and rudders separate frames; layers and shadow state participate in the proof. Driver/helmet/morph geometry, live handles, reflected transforms, distance visibility and uncertain shader coverage are protected.

The complete frame fingerprint covers geometry, relative transforms, finish coverage, layers, shadows and protection. The runtime validates every replacement before applying any in that frame; mismatches keep original geometry. Shared physical-piece removals are intersected across observed contexts so fixed and editable construction agree. Nodes remain available to existing references; fully enclosed nodes are hidden rather than freed. Active-buffer figures therefore do not measure total retained process memory. Recipe/mesh caches are bounded to 256 each, with 1,024 cached geometry keys; Hover skips recipe hashing because the study finds no useful candidates.

After hardware changes, this contributes 1,439 stock triangles: Rally 204, Kart 11, Forklift 884, Volt 160 and Challenger 180. These are final qualified results, superseding the earlier review's 1,311 estimate on older source geometry. The full study observes 400 contexts; current runtime qualification verifies 1,314 changed part observations. Production publishes 322 reduced mesh resources and 100 context manifests, about 1.33 MB compressed on disk. Some obsolete digest-addressed candidates remain harmlessly unused; final asset hashes identify the complete published set.

Direct fitted source construction now reduces the stock editable base before applying selected kit modules, matching the prepared assembly order. The final requested editability, finishes, customisation and snapshot identity are preserved. This was required to keep source/prepared/ghost equality; existing module assertions were retained.

**CLV03 — Rally plate and exact sharing.** `game/vehicle/compact_rear_design.gd` replaces 1,190 triangles of already-flat lettering with a native bake of the same licensed font, strings, size and placement. Only batched simple models use the printed plate; full/unbatched references retain TextMesh geometry. One opaque shader samples a shared 512×256 L8 image with mipmaps: lit paper and the original unshaded ink finish. There is no extra transparent overlay or surface. The image contains **174,763 bytes of image/mipmap payload**; compressed disk size is much smaller. This image cost must be included when evaluating Rally's mesh savings. L8 shader sampling has not been qualified on Android hardware.

`game/tests/support/car_model_buffers.gd` also permits Challenger to use the existing exact immutable mesh-sharing path. It preserves encoded geometry and instance finishes. Full-quality master triangle counts stay exactly **102,556 / 72,544 / 148,048 / 114,648 / 71,932 / 83,936** in catalogue order. Challenger full-quality active unique buffers fall **2,730,680 → 2,393,660 bytes** through sharing; other full-quality buffer totals remain exact.

The separate approximate half-count ghost prototype remains deferred because its translucent internal lines change visibly. Ordinary ghosts inherit the accepted source reductions; those combined differences are measured below. `personal_ghost.gd`, handling source and all eight car configurations remain byte-exact.

**CLV04 — Consumers, appearance and performance.** All bases, full/simple kits, Garage cars and the stock header were rebuilt with the pinned engine `4.7.2.stable.official.ed1daf0bf`. The final refresh consumes 24,063 unchanged inputs and passes strict prepared checks for **551 resources / 2,267 checks / zero failures**. Six catalogue photographs have **171 current source hashes**. Dependency rules scope recipes per car and the plate to Rally; Android's existing include filter includes the recipe JSON files. No export was performed.

Every stock and sample fitted case retains its previous visible surface count. Triangle removal therefore primarily lowers geometry processing and buffer traffic; it does not reduce those submission counts. No CPU/GPU frame-time or device FPS improvement is claimed. Existing distance LODs can already remove much of the same geometry, and changing a master can shift generated LOD choices. At the distant studio camera, the whole-scene visible primitive counters are:

| Car | Before | After |
| --- | ---: | ---: |
| Rally | 24,265 | 22,324 |
| Kart | 26,482 | 26,439 |
| Forklift | 30,678 | 28,974 |
| Volt | 22,284 | 22,588 |
| Hover | 22,818 | 22,818 |
| Challenger | 34,532 | 33,818 |

These counters include studio passes and are identical between the two tested desktop renderers. Volt's **304-primitive increase at this distance** is a measured tradeoff despite its smaller master. Close/master savings must not be advertised as equivalent distant savings. No new distance thresholds or renderer settings were introduced.

There are **44 paired native comparisons per renderer**: stock/fitted front, rear and distance views, two plate close views, and six actual ghost-shader distance views. The captures use unchanged detached task-start model scenes, matching studio glass treatment, directional shadows, reference repeats and restoration controls. Alpha is exact in all 88 pairs. Visual inspection of the contact sheets retains the vehicle identity, visible fittings, plate lettering and shadow silhouettes; tiny faceting/raster differences remain.

| Appearance group | Compatibility worst crop mean /255 | Desktop Mobile worst crop mean /255 | Largest fraction of crop pixels changing >8/255 |
| --- | ---: | ---: | ---: |
| 36 opaque stock/fitted views per renderer | 0.116847 | 0.107653 | 0.3114% |
| 2 plate close views per renderer | 0.108453 | 0.165954 | 0.5928% |
| 6 translucent ghost views per renderer | 0.228280 | 0.172675 | 0.8822% |

All **38 opaque-car/plate pairs per renderer** have exact reference and restoration controls. Desktop Mobile completes **194 checks / zero failures**. Compatibility completes **194 checks / two failures**, both Challenger ghost exact-image controls: reference seven pixels and restoration eight pixels differ by at most **1/255 RGB**, with exact alpha. The same renderer's ghost-control instability was present in the earlier review. This remains a qualification failure, not a waived assertion or evidence of pixel identity. The candidate ghost difference is separately measured. Owner appearance and actual racing overlap/device acceptance remain open.

Native evidence: [Mobile comparison sheet](evidence/car-detail-reduction-2026-11-14/mobile-comparison.png), [Compatibility sheet](evidence/car-detail-reduction-2026-11-14/gl_compatibility-comparison.png), [all pixel/control metrics](evidence/car-detail-reduction-2026-11-14/native-pixel-metrics.json), [prepared measurements](evidence/car-detail-reduction-2026-11-14/prepared-results.json), [source proof](evidence/car-detail-reduction-2026-11-14/source-verification.json). Before is left, reduced is right. Full frames, actual App captures and header comparisons are beside these files.

Verification commands actually run from the repository root:

```powershell
python scripts/run_car_detail_reduction.py baseline res://tests/capture_car_detail_baseline.gd --headless
python scripts/run_car_detail_reduction.py plate-bake-final res://tests/bake_compact_plate_texture.gd --rendering-method gl_compatibility
python scripts/bake_car_detail_reductions.py
python scripts/finalize_car_detail_materials.py
python scripts/refresh_car_detail_assets.py
python scripts/refresh_car_detail_assets.py --pictures
python scripts/run_car_detail_reduction.py source-final res://tests/test_car_detail_reductions.gd --headless -- --evidence-root=res://../docs/evidence/car-detail-reduction-2026-11-14
python scripts/run_car_detail_reduction.py prepared-final res://tests/measure_car_detail_results.gd --headless -- --prepared
# Run for each of compact, kart, forklift, electric, hovercraft, super_rally:
python scripts/run_car_detail_reduction.py modules-final-compact res://tests/test_modular_car_assets.gd --headless -- --vehicle=compact --all-kits
# Run each native script with gl_compatibility and mobile:
python scripts/run_car_detail_reduction.py native-final-gl res://tests/capture_car_detail_models.gd --rendering-method gl_compatibility
python scripts/run_car_detail_reduction.py app-final-gl res://tests/test_car_detail_app.gd --rendering-method gl_compatibility
# BMT_RIVALRY_CARS_EVIDENCE_DIR points inside this task's evidence directory:
python scripts/run_car_detail_reduction.py header-final-gl res://tests/test_header_icon_capture.gd --rendering-method gl_compatibility
python scripts/run_car_detail_reduction.py wash-final res://tests/test_car_wash.gd --headless -- --evidence-root=res://../docs/evidence/car-detail-reduction-2026-11-14
python scripts/run_car_detail_reduction.py wash-surfaces-final res://tests/test_garage_wash_surfaces.gd --headless -- --evidence-root=res://../docs/evidence/car-detail-reduction-2026-11-14
python scripts/run_car_detail_reduction.py parser-final res://tests/check_model_refinement_parse.gd --headless
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_detail_reduction.ps1
```

The corresponding per-run receipts contain complete commands, exit codes, diagnostics and elapsed times. The runners use private APPDATA/LOCALAPPDATA, Dummy audio and empty API configuration. Final source proof **5,347/0**, prepared measurements **54/0**, actual App **56/0 each renderer**, header **594/0 each**, washing **1,655/0**, Garage washing **54/0**, driving **72/0**, materials **115/0**, primitive shape checks **16/0**, production parsing **570/0** pass. Final exhaustive module results and closeout receipts are recorded below.

Earlier rejected attempts remain explicit: a source change rejected an intermediate recipe publication; a reconstructed ring AABB required exact native bounds; an early StandardMaterial L8 plate draft was blank in native views and was replaced by explicit `.r` shader sampling; redundant surface overrides caused Dummy-renderer material diagnostics and were removed; detached reference glazing initially differed from the live showroom and was corrected in the fixture. The first exhaustive module pass exposed source-fitted construction mismatches, fixed before final refresh. Hover's existing kit-reset triangle difference is reproduced with exact task-start RacingCarModels source; that unchanged behavior is retained, not silently fixed or accepted by weakening an existing test. Initial fixture/draft metrics are not current appearance qualification. No production invariant was removed or relaxed.

Changed production sources are the six task-start files in [before controls](evidence/car-detail-reduction-2026-11-14/before-controls.json), plus the new detail loader and plate shader. Offline producers, focused tests and comparison/refresh/checkpoint tools accompany them. Native recipes/meshes, plate image, 551 prepared resources and catalogue images are generated derivatives. The normal build-identity helper refreshes generated identity/project metadata; canonical checkpoint-layout identity remains unchanged. [Final controls](evidence/car-detail-reduction-2026-11-14/final-controls.json) record a concurrent real-index change without restoring or staging it. Other concurrent work remains preserved.

No physical-device query/test, APK/AAB/export, backend request/deployment, owner-save/process change or task-authored main-index staging/commit occurred. Full Android frame time, total process RAM/VRAM, first-run shader cost, all possible simultaneous kit combinations and owner visual acceptance remain unmeasured. A fresh client launch is needed to load the regenerated resources.

Final exhaustive module results: **8,981 checks / zero failures** across both quality tiers: Rally 1,441; Kart 1,156; Forklift 1,726; Volt 1,934; Hover 1,288; Challenger 1,436. See [module receipts](evidence/car-detail-reduction-2026-11-14/module-results.json). Source and prepared stock/fitted master counts agree for all twelve cases.

The [source-only patch](evidence/car-detail-reduction-2026-11-14/source.patch) and [round-trip receipt](evidence/car-detail-reduction-2026-11-14/source-checkpoint.json) preserve the task-start sources and only this task?s tracker blocks. The small private Git checkpoint lives in disposable build output; the real index is untouched by checkpoint generation. Generated assets have a separate [final hash inventory](evidence/car-detail-reduction-2026-11-14/final-assets.json). Duplicate draft captures were moved into disposable build output; failed run receipts and final native comparisons remain as concise evidence.

Prescribed completion cleanup ran: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply`. Its actual decisions, remaining protected entries and final size are retained in the [build retention log](evidence/car-detail-reduction-2026-11-14/build-retention.log); no historical pins or owner processes were removed.
