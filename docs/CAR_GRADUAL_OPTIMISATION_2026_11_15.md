# Gradual car optimisation: iteration 1 - 15 November 2026

The owner replaces the former 10,000-triangle target with **10-20% steps and a visual review after every iteration**. This first accepted source step covers **Forklift only**. Rally, Kart, Volt and Hover retain their restored pre-10k geometry; Challenger remains excluded. Further reductions wait for owner review of this step.

| Racing model/sample | Before | Iteration 1 | Reduction |
| --- | ---: | ---: | ---: |
| Forklift stock master triangles | 26,472 | 23,370 | 11.72% |
| Forklift sampled fitted triangles | 29,428 | 26,044 | 11.50% |
| Stock mesh buffers, including distance indices | 1,259,444 bytes | 1,130,964 bytes | 10.20% |
| Stock surfaces / mesh instances | 26 / 31 | 26 / 31 | unchanged |
| Full-detail Forklift triangles / buffers | 148,048 / 5,417,740 bytes | identical | unchanged |

[Matching before/after views](evidence/car-iteration-01-2026-11-15/forklift-before-after.jpg) show the front, rear and operator/engine area. Full-size [before](evidence/car-iteration-01-2026-11-15/prepared-gl_compatibility/forklift-stock-hardware-rear-before.png) and [after](evidence/car-iteration-01-2026-11-15/prepared-gl_compatibility/forklift-stock-hardware-rear-after.png) retain small detail. Actual [Garage](evidence/car-iteration-01-2026-11-15/app-gl_compatibility/forklift-garage.png) and [race](evidence/car-iteration-01-2026-11-15/app-gl_compatibility/forklift-race.png) views are also retained.

**CI01 - One limited geometry step.** Ninety-one reviewed static component meshes are merged into the existing complete-frame Forklift recipes: 91 immutable mesh resources and 97 frame manifests. Existing enclosed/zero-area removal and original frame protection remain. Exact planar cylinder-cap retriangulation saves 692 stock triangles without changing the cap boundary or surface. The remaining savings reduce small fittings. No runtime model-building code, quality setting, handling, camera or shader was changed; the experimental hook was removed before publication. Existing full/simple fixed/editable bases, all 104 full/simple Forklift kit outputs and its Garage reference were rebuilt. Only its Garage and factory-header pictures were refreshed.

**CI02 - Review and reject degradation immediately.** The broader trial was rejected: some lamp/bevel changes were visible and many components exceeded the fixed 2 mm sampled surface limit. The other cars were therefore deferred rather than forcing them into a numerical target. The selected Forklift resources retain original encoded vertex attributes, connected-component counts and boundary-component counts, without adding nonmanifold edges. Their maximum sampled local deviation is 1.850 mm; staging also checks the actual frame scale against the unchanged 2 mm limit. Samples include every used vertex and every triangle centroid, in both directions. This is a sampled check, not an exhaustive surface-distance proof.

The inspected final stock/fitted close views retain the mast, operator supports, mirrors, tyres, panel joins and the main silhouette. Small bevel highlight/raster differences remain; pixel identity and removal of pre-existing coarse faceting are not claimed. The before/after image checks verify stable reference/restoration and successful delivery, not an automatic aesthetic approval. Owner appearance review remains the next gate.

**CI03 - Verify the consumers and controls.** All thirteen unaffected stock/fitted/full master controls match the original GPU streams, transforms and shadow modes exactly. Small portable signatures exported from all fifteen pre-10k snapshots allow these controls to run without retaining disposable scene copies. The other eight identity keys, including the four other active cars and Challenger, remain unchanged. The production construction source is byte-exact to task start. Canonical car configurations, handling/ghost and Challenger sources remain exact.

| Actual verification | Result |
| --- | --- |
| Source counts and 10-20% stock step | 6 checks / 0 failures |
| Actual prepared hits, counts and thirteen exact master controls | 39/0 |
| Recipe validity plus bad-source/bad-bounds rejection and recovery | 313/0 |
| All Forklift full/simple kit, finish and ghost comparisons | 1,726/0 |
| Prepared native stock/fitted views and close-ups | 18 pairs, 75/0 in each desktop renderer |
| Actual five-car Garage/race App, handling and Kart steering | 48/0 in each desktop renderer |
| Driving | 72/0 |
| Production parser | 573 scripts / 0 failures |
| Prepared validation excluding Challenger | 468 resources / 1,925 checks / 0 failures |
| Forklift catalogue and two texture imports | 1 picture / 173 source hashes; 2 imports, no editor errors |
| Consumed-input fence | 16,516 unchanged inputs; all 188 published resource hashes exact |

Compatibility stock front studio primitives fall **30,514 to 27,412** with **39 draw calls unchanged**. The distance view falls 28,974 to 26,076 with 32 draws unchanged. This reduces geometry/buffer work; it does not reduce material passes or establish an FPS improvement. No phone/device test was performed.

Initial fixture indentation/non-indexed-input failures were corrected. The original publication then correctly failed the exact-bounds/count guards because a few primitive resource bounds differed at float precision after serialization. Original recipes were restored, the producer retained the exact original surface bounds, and source counts passed without relaxing the guard. A later import attempt rejected a changing generated project version; its stable repeat passed without reverting settings. Rejected trial receipts and the original 6/2 source result remain in the evidence. No existing assertion was weakened.

**CI04 - Continue gradually.** Each subsequent step starts from the last owner-reviewed model, keeps a reversible source/resource checkpoint, targets a 10-20% reduction for the car being worked on, and compares matched stock/fitted close, side, top and gameplay views. Check silhouettes, joins, glazing, tyres, small detail, shadows and animated controls. Restore or repair any degrading component before presenting the step. Rebuild and qualify the prepared consumers, then pause for owner review before the following reduction. There is no compulsory final 10k target.

Completed commands used the pinned engine and isolated local profiles with API configuration disabled:

```text
python scripts/run_car_iteration.py survey res://tests/survey_car_iteration.gd --headless
python scripts/run_car_iteration.py candidates-v3 res://tests/bake_car_iteration.gd --headless
python scripts/check_car_iteration_geometry.py
python scripts/publish_car_iteration.py
python scripts/refresh_car_iteration.py
python scripts/run_car_iteration.py source-corrected res://tests/test_car_iteration.gd --headless
python scripts/run_car_iteration.py prepared-portable-control res://tests/test_car_iteration.gd --headless -- --prepared
python scripts/run_car_iteration.py recipe-guards res://tests/test_car_iteration_recipe_guards.gd --headless
python scripts/run_car_iteration.py modules-forklift res://tests/test_modular_car_assets.gd --rendering-method gl_compatibility -- --vehicle=forklift --all-kits
python scripts/run_car_iteration.py native-gl res://tests/capture_car_iteration.gd --rendering-method gl_compatibility -- --vehicle=forklift
python scripts/run_car_iteration.py native-mobile res://tests/capture_car_iteration.gd --rendering-method mobile -- --vehicle=forklift
python scripts/run_car_iteration.py app-gl res://tests/test_car_iteration_app.gd --rendering-method gl_compatibility
python scripts/run_car_iteration.py app-mobile res://tests/test_car_iteration_app.gd --rendering-method mobile
python scripts/import_car_iteration_images.py
python scripts/check_garage_previews.py --vehicles=forklift
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_iteration.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Per-command receipts retain the precise refinement, source/fitted, picture, parser and driving invocations. [Publication](evidence/car-iteration-01-2026-11-15/publication.json), [geometry review](evidence/car-iteration-01-2026-11-15/geometry-review.json), [closure](evidence/car-iteration-01-2026-11-15/closure.json) and the [source/resource checkpoint](evidence/car-iteration-01-2026-11-15/source-checkpoint.json) record exact scope. The [review patch](evidence/car-iteration-01-2026-11-15/source.patch) includes authored recipes/meshes; derived scenes and pictures require refresh if the source step is undone. Disposable draft captures/caches remain under build retention, not permanent project copies.

Reload the game/project to discard old in-memory geometry. This is a desktop/source qualification and an owner review point, not phone/FPS or whole-project acceptance. No backend request, export, deployment, owner-save/process action or main-index staging was performed. Unrelated Garage and concurrent work were preserved. The prescribed cleanup output is retained in build-retention.log.
