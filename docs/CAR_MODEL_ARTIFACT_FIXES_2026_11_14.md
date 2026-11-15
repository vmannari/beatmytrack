# Reduced car artifact repairs, 14?15 November 2026

The marked Kart helmet, Rally windshield shard and open Volt roof/window joint are corrected. The five-car review also corrected malformed tyre silhouettes, Rally cabin/roof/wheel-arch joins and rear lamps, and Volt wheel-arch returns and lower window seals. **Challenger remains excluded from model authoring, native budget publication and prepared-model/image bakes.**

[Before/after close-ups](evidence/car-model-artifacts-2026-11-14/repairs-before-after.jpg) ? [All five cars, front/rear](evidence/car-model-artifacts-2026-11-14/five-car-review.jpg) ? [High-contrast Volt roof](evidence/car-model-artifacts-2026-11-14/source-mobile-decorated/electric-stock-roof-left-after.png)

## Result and costs

These are actual prepared stock simple/racing masters, excluding shadow-only proxy triangles. The same counts are verified in fixed and editable source construction and in the prepared consumers.

| Car | Before triangles | Repaired triangles | Visible surface change |
| --- | ---: | ---: | ---: |
| Rally | 10,294 | 10,994 | 3 |
| Kart | 10,294 | 10,526 | 0 |
| Forklift | 10,504 | 10,182 | 0 |
| Volt | 9,987 | 10,289 | 2 |
| Hover | 10,300 | 10,300 | 0 |

Total **51,379 -> 52,291 (+1.78%)**. The stock target remains approximately 10,000, within the existing 9,000?11,000 gate. The sampled four-category fitted masters are Rally 13,363, Kart 11,204, Forklift 12,096, Volt 12,132 and Hover 11,649; optional kits are not capped at 10,000.

Full-quality stock masters remain 102,556 / 72,544 / 148,048 / 114,648 / 71,932 triangles. Every full master GPU stream and transform, and all five prepared buffer totals, compare exactly with the task-start prepared snapshots. No handling, contact, replay or ghost source was authored.

Protected joints retain their original pre-budget geometry at every distance. This costs some distant triangles and a few material groups. The matched stock distance studio counters below include the same room and real shadows; they are **not FPS or phone measurements**.

| Car | Whole-view primitives, before -> after | Whole-view draws, before -> after |
| --- | ---: | ---: |
| Rally | 14336 -> 14980 | 61 -> 64 |
| Kart | 14302 -> 14404 | 67 -> 67 |
| Forklift | 14034 -> 13976 | 32 -> 32 |
| Volt | 13765 -> 14275 | 44 -> 46 |
| Hover | 14124 -> 14124 | 21 -> 21 |

The icon renderer selects existing distance levels with bias 0.25 for these five cars, keeping protected boundaries exact. Its existing unmodified 15% saving gate passes: **61,163 -> 51,661 primitives (-15.54%)** across five equipped icons. Worst Compatibility mean RGB difference from the same-camera master image is 0.001547, below the retained 0.025 gate. Challenger retains its previous 0.35 icon bias.

## Requirements and implementation

- **CMA01 ? Diagnose the marked defects.** Detached stock/fitted/full snapshots preserve the receiving baseline. Disabling the last budget pass restores the helmet, windshield and roof join, locating the damage in generic simplification rather than the original design.
- **CMA02 ? Preserve meaningful surfaces.** `car_budget_reduction.gd` identifies glazing, helmet openings, tyres and the named joining skins before the older reduction stages. It inspects the original asset role as well as the node name: Godot anonymizes duplicate names on mirrored parts. Material identities preserve this policy through sibling/final batching, paint variants remain editable, and `car_mesh_lods.gd` strips approximate distance levels from those groups. The underlying older source-piece reduction remains available elsewhere.
- **CMA03 ? Recover the budget elsewhere.** Native and planar candidates are combined for Rally/Kart/Forklift, duplicate triangle-count levels are removed, and the remaining source pieces carry the reduction. Complete regular tyre profiles replace arbitrary tyre index pruning: 20 radial sections on racing Rally, 24 on Kart/Forklift/Volt; full tyres retain 64. Challenger already requests the full tyre branch and is unaffected. Kart's 1,194-triangle helmet and all ten moving driver poses remain intact. Candidate staging now clears only the task-owned five-car recipes, preventing an obsolete experimental file from supplying a source key omitted by the current plan. The clean 717-file stage compares byte-for-byte with the accepted published set.
- **CMA04 ? Refresh and qualify consumers.** Five full/simple fixed/editable bases, every full/simple kit, five Garage references, the stock header template, five Garage photographs and five factory header pictures are refreshed. All ten native image imports validate. An obsolete optional LOD cache now skips missing dependencies before loading; fresh-source bake errors still reject. The regression rejects the original helper with 6 checks/1 failure and passes the fix 6/0. A concurrent Challenger thumbnail refresh originally changed every conservative model key; a narrow dependency rule now assigns those generated Challenger thumbnails only to Challenger. Shared livery SVGs still invalidate all their actual consumers. The source fence now includes artwork, fonts and non-mesh resource leaves instead of silently omitting them.

## Verification

| Check | Actual result |
| --- | --- |
| Published source keys, retained encoded attributes, stock budgets and all options | 6,964 checks / 0 failures |
| Critical geometry, stale-recipe injection, colour and LOD checks | source 398/0; prepared 327/0 |
| Actual prepared stock/fitted/full hits and exact full controls | 40/0 |
| Existing exhaustive module/source/material/ghost comparisons, both tiers | 7,545/0 across five cars |
| Actual Garage/race App | 48/0 each desktop renderer |
| Prepared native stock/fitted, six general views plus marked close-ups | 76 image pairs, 319/0 each renderer |
| Diagnostic source opaque native controls | Compatibility 304/0; decorated desktop Mobile 152/0 |
| Equipped icon geometry, paint, delivery and cancellation | 529/0 each desktop renderer |
| Kart steering and original morph poses | native 170/0 |
| Washing and missed-surface checks | 1,383/0 plus 54/0 |
| Driving | 72/0 |
| Production parser | 573 scripts / 0 failures |
| Prepared preflight, explicitly excluding Challenger | 468 resources / 1,925 checks / 0 failures |
| Catalogue and workshop provenance | five pictures / 173 source hashes; workshop 28 sources |

The model refresh fence passes **25,109 unchanged inputs**, including artwork/fonts, and exact final five-car revision keys. The full snapshot comparisons use prepared-to-prepared controls; an initial source-to-prepared raw-buffer comparison mixed existing batching/LOD layouts and was rejected as an unsuitable control. All original budget, appearance, source, module and performance assertions remain intact.

Earlier candidates exposed additional mirrored gaps and a stale private recipe set; those candidates were corrected rather than published. The original icon threshold failed after boundary restoration, then passed with the measured icon-only LOD selection. The first refresh also encountered an obsolete cached Kart dependency and the concurrent Challenger thumbnail revision change; both failures are retained in the evidence. Early fixture errors (inherited constant name, invalid colour spelling, embedded rather than external missing-dependency control, and montage tooling) were corrected. No failed run is counted as a pass.

## Actual commands

The isolated runner pins Godot 4.7.2, redirects APPDATA/LOCALAPPDATA, disables API configuration and uses Dummy audio. Representative completed invocations:

```text
python scripts/fix_car_model_artifacts.py
python scripts/run_car_model_artifacts.py collect-final-rally-round res://tests/bake_car_10k.gd --headless -- --collect --vehicle=compact
python scripts/fix_car_model_artifacts.py --resume --revalidate
python scripts/fix_car_model_artifacts.py --install
python scripts/fix_car_model_artifacts.py --refresh
python scripts/fix_car_model_artifacts.py --pictures
python scripts/run_car_model_artifacts.py source-published-final res://tests/test_car_10k.gd --headless
python scripts/run_car_model_artifacts.py prepared-results res://tests/measure_car_model_artifacts.gd --headless -- --prepared
python scripts/run_car_model_artifacts.py artifact-proof-prepared res://tests/test_car_model_artifacts.gd --headless -- --prepared
python scripts/run_car_model_artifacts.py modules-electric res://tests/test_modular_car_assets.gd --headless -- --vehicle=electric --all-kits
python scripts/run_car_model_artifacts.py prepared-native-gl res://tests/capture_car_model_artifacts.gd --rendering-method gl_compatibility
python scripts/run_car_model_artifacts.py prepared-native-mobile res://tests/capture_car_model_artifacts.gd --rendering-method mobile
python scripts/run_car_model_artifacts.py app-gl res://tests/test_car_artifacts_app.gd --rendering-method gl_compatibility
python scripts/run_car_model_artifacts.py app-mobile res://tests/test_car_artifacts_app.gd --rendering-method mobile
python scripts/run_car_model_artifacts.py icons-gl res://tests/test_car_10k_icons.gd --rendering-method gl_compatibility
python scripts/run_car_model_artifacts.py icons-mobile res://tests/test_car_10k_icons.gd --rendering-method mobile
python scripts/import_car_model_artifact_images.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_model_artifacts.ps1
```

Each native icon invocation supplies its task evidence directory through `BMT_RIVALRY_CARS_EVIDENCE_DIR`. Per-command logs and receipts are in [the evidence directory](evidence/car-model-artifacts-2026-11-14). The raw [summary](evidence/car-model-artifacts-2026-11-14/summary.json) retains complete inventories and camera counters.

## Files, review and limits

Production changes: `game/vehicle/car_budget_reduction.gd`, `car_visual.gd`, `car_mesh_lods.gd`, `compact_detail.gd`, `kart_geometry.gd`, `prepared_asset_dependencies.json`, and `game/ui/header_icon_renderer.gd`. Offline changes include the budget producer/export/path helpers, missing-dependency LOD guard, scoped header-picture producer, artifact regressions/capture/measurement runners, image import and comparison scripts. Native budget resources, the regular Kart tyre, prepared consumers and ten photographs accompany them. Generated identity/project metadata use the existing helper. The [source checkpoint receipt](evidence/car-model-artifacts-2026-11-14/source-checkpoint.json) lists every task-authored source and its hashes; the [source-only patch](evidence/car-model-artifacts-2026-11-14/source.patch) applies and reverses against the private checkpoint.

These are desktop Compatibility and desktop Vulkan Mobile checks. **No device test, APK/export, live backend request, deployment, owner-save/process action, or main-index staging was performed.** No whole-repository clean-suite or phone/FPS claim is made. Low-poly faceting and ordinary shadow aliasing remain quality tradeoffs; the marked missing/overlapping surfaces are the repair scope. Reload the client/project to discard previously cached meshes; owner appearance and physical-device performance acceptance remain.

The prescribed build retention cleaner ran successfully; its output is retained as `build-retention.log`. It reports 30.37 -> 30.37 GiB and zero removals because recent/protected/locked entries remain. Automatic approval review rejected direct deletion of this task's disposable build files as blocked by policy. Those temporary geometry/JSON caches, detached baseline scenes and private profiles remain under the existing build retention policy; no retention pin was added and no disposable files were moved outside `build/`. This is a cleanup limitation, not a model validation failure.
