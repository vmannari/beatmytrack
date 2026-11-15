# Pre-10k car models restored ? 15 November 2026

The owner requested the models from **before the 10,000-triangle optimisation attempts**. This supersedes the C10K target and CMA follow-up geometry. The earlier coarse and low-visibility optimisations remain.

| Stock simple/racing model | Restored triangles |
| --- | ---: |
| Rally | 19,074 |
| Kart | 24,223 |
| Forklift | 26,472 |
| Volt | 19,826 |
| Hover | 22,068 |

**CRV01 ? Restore the recorded earlier geometry.** Six source files are restored byte-for-byte from the retained pre-10k/pre-CMA checkpoints: `car_visual.gd`, `racing_car_models.gd`, `car_mesh_lods.gd`, `compact_detail.gd`, `kart_geometry.gd` and `header_icon_renderer.gd`. Current hashes were checked against the last task before restoration, preventing accidental overwrite of later edits. The 10k helper is disabled and no longer called by production construction. Experimental recipes and reports remain inactive historical data. Cache safety and dependency-routing fixes are retained.

**CRV02 ? Refresh consumers.** The five cars' full/simple fixed/editable bases, all their full/simple kits, Garage references, the stock header template, five Garage catalogue pictures and five factory header pictures were rebuilt. All ten texture imports validate. Challenger model sources/configurations and its prepared models/pictures were excluded from authoring. Concurrent Garage source edits were preserved. A workshop dependency refresh rebuilt from live source; Garage geometry optimisation was not reverted.

**CRV03 ? Verify the rollback.** The restored prepared stock, fitted and full models compare **exactly in master GPU data and transforms** with all fifteen detached snapshots recorded before the 10k work. The source construction gives the same stock counts. The sampled fitted counts are Rally 26,600, Kart 25,613, Forklift 29,428, Volt 26,216 and Hover 31,324. Full stock counts remain 102,556 / 72,544 / 148,048 / 114,648 / 71,932.

[Restored Rally](evidence/car-model-revert-2026-11-15/prepared-gl_compatibility/compact-stock-front-after.png) ? [Restored Kart helmet](evidence/car-model-revert-2026-11-15/prepared-gl_compatibility/kart-stock-helmet-side-after.png) ? [Restored Volt](evidence/car-model-revert-2026-11-15/prepared-gl_compatibility/electric-stock-roof-left-after.png)

| Actual validation | Result |
| --- | --- |
| Exact historical source hashes | 6 files |
| Source stock counts | 6 checks / 0 failures |
| Prepared hits, exact pre-10k master geometry and transforms | 41/0 |
| Existing exhaustive five-car kit, finish and ghost comparisons | 7,545/0 |
| Stock native views and marked close-ups | 38 pairs, 157/0 each desktop renderer |
| Actual Garage/race App | 48/0 each desktop renderer |
| Equipped icon appearance, LODs and cache delivery | 496/0 each desktop renderer |
| Driving | 72/0 |
| Production parser | 573/0 |
| Prepared validation, explicitly excluding Challenger | 468 resources / 1,925 checks / 0 failures |
| Catalogue validation and texture imports | 5 pictures / 173 sources; 10 imports, no editor diagnostics |
| Model refresh fence | 25,109 unchanged inputs; exact final five-car keys |

The native repeat/restoration controls pass. PNGs match the historical reference exactly in 24/38 Compatibility and 25/38 desktop Mobile views; regenerated distance levels/render ordering can differ, so full pixel identity is not claimed. Master geometry matches all fifteen historical snapshots exactly.

An initial fixture line-ending/preload error and a missing customisation default were corrected. One native picture attempt logged a shader-cache read error and correctly preserved accepted files; its retry passed. A concurrently edited Garage further-reduction budget fixture reports 81 checks/3 failures and is outside this model rollback; no Garage source was restored to hide those findings. The obsolete 10k-specific budget/protection tests are historical contracts superseded by the owner's rollback, not weakened acceptance gates.

Completed commands used the pinned isolated offline runner with private APPDATA/LOCALAPPDATA and disabled API configuration:

```text
python scripts/refresh_car_model_revert.py
python scripts/refresh_car_model_revert.py --pictures
python scripts/run_car_model_revert.py source-revert res://tests/test_car_model_revert.gd --headless
python scripts/run_car_model_revert.py restored-prepared res://tests/test_car_model_revert.gd --headless -- --prepared
python scripts/run_car_model_revert.py native-gl res://tests/capture_car_model_revert.gd --rendering-method gl_compatibility -- --stock-only
python scripts/run_car_model_revert.py native-mobile res://tests/capture_car_model_revert.gd --rendering-method mobile -- --stock-only
python scripts/run_car_model_revert.py modules-electric res://tests/test_modular_car_assets.gd --headless -- --vehicle=electric --all-kits
python scripts/run_car_model_revert.py app-gl res://tests/test_car_model_revert_app.gd --rendering-method gl_compatibility
python scripts/run_car_model_revert.py app-mobile res://tests/test_car_model_revert_app.gd --rendering-method mobile
python scripts/import_car_model_revert_images.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The other four exhaustive kit invocations and icon runs have individual logs/receipts in the [evidence directory](evidence/car-model-revert-2026-11-15). Icons supply `BMT_RIVALRY_CARS_EVIDENCE_DIR`. [Source restoration hashes](evidence/car-model-revert-2026-11-15/restored-source-checkpoints.json), [closure/fence](evidence/car-model-revert-2026-11-15/closure.json), [source-only checkpoint](evidence/car-model-revert-2026-11-15/source-checkpoint.json) and [review patch](evidence/car-model-revert-2026-11-15/source.patch) retain scope and verification. Derived assets have been rebuilt rather than merely restamped.

No main-index staging, backend request, export, device test or owner-save/process action was performed. Desktop checks do not establish phone FPS or whole-project/Garage readiness. Reload the project/client to discard previously cached 10k meshes. Build cleanup uses the prescribed retention policy; its actual output is retained in `build-retention.log`.
