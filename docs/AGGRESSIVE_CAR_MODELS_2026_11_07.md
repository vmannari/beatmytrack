# Optional stronger car simplification — 2026-11-07

Settings → Graphics now offers **Simpler car models**, off by default. Select it and Apply to use substantially lighter cars from the next race. Reset graphics stages the standard models again. The description explicitly allows less accurate small details and curves. Menus and Garage continue to display the standard models.

The user explicitly authorizes greater visual differences for this optional tier. Standard quality retains the prior strict geometry and LOD policy; the wider tolerances belong to the new option.

## Requirements and implementation

| ID | Delivered behavior |
|---|---|
| ACM01 | A staged, saved Graphics switch with Apply, failed-save rollback, Reset and next-race behavior. The new boolean `reduced_car_models` defaults false; the retired `simple_car_models` preference stays ignored and cannot silently enable the option. |
| ACM02 | All five cars and their fitted parts use the existing lower-sampling procedural model family plus a stronger offline LOD policy. Reduced race assets use `lod_bias=0.5`, giving a nominal two-pixel selection threshold with the race viewport's one-pixel setting; standard assets keep bias 2 / half a pixel. No runtime decimation is added. |
| ACM03 | Paint, liveries, stickers, glazing, condition, brake lights, wheel/fan articulation, personal ghosts, canonical driving and lap count retain their existing roles. Fitted reduced cars restore an editable prepared base and independently prepared modules with actual silhouette casters. Fixed stock cars retain their existing shadow proxies. |
| ACM04 | Source-stable prepared assets, native comparisons, complete module checks, Settings screenshots, explicit limits and an isolated task-only checkpoint. |

Runtime changes are [SettingsPage](../game/ui/settings_page.gd), [Game](../game/core/game.gd), boolean validation in [LocalRecords](../game/persistence/local_records.gd), [CarVisual](../game/vehicle/car_visual.gd) and [RacingCarModels](../game/vehicle/racing_car_models.gd). The two offline modular bakers select the stronger bias for reduced variants. The description is translated in all twelve supported catalogues.

The fitted-model path needed two corrections. Editable reduced bases now keep their actual casters for every vehicle, allowing safe module assembly without stock-only proxies. Newly fitted primitive meshes are reduced **before batching**, matching construction-time reduction. This also fixes the previously latent mismatch between a directly constructed reduced fitted Compact and its hot-swapped modules; they differed by 768 triangles in the first selected fit. Exact geometry, materials, corner attributes and rest-pose ghost checks were retained while fixing it.

## Drawing reduction and appearance

The comparison is against the current optimized standard models, after both earlier simplification passes. Stock daylight native visible primitive counts at 1280×720, including the unchanged two-triangle fixture floor:

| Vehicle | Overhead standard → reduced | Fewer | Close standard → reduced | Fewer |
|---|---:|---:|---:|---:|
| Rally | 32,825 → 15,008 | 54.28% | 36,976 → 25,211 | 31.82% |
| Kart | 23,368 → 9,946 | 57.44% | 40,672 → 17,824 | 56.18% |
| Forklift | 26,816 → 12,856 | 52.06% | 56,652 → 23,286 | 58.90% |
| Volt | 34,570 → 15,218 | 55.98% | 42,718 → 17,082 | 60.01% |
| Hovercraft | 56,594 → 18,704 | 66.95% | 61,298 → 20,050 | 67.29% |

These are main-view primitive counts, not FPS, total render work, package size or memory measurements. Fitted native comparisons select the final catalogue option in each of the four categories; the independent exhaustive module tests cover every individual option. Arbitrary combinations are not exhaustively rendered.

The optional appearance budget was set before the first native run: mean RGB difference below **8/255** and fewer than **15%** of crop pixels differing by more than 8/255. It is measured on the union of the two projected car bounds with an eight-pixel margin, so empty background cannot conceal a large change. Every overhead case must draw at least 35% fewer primitives, and every close/rear/macro case at least 20% fewer, than standard. These are additional optional-tier assertions; standard's stricter gates are not changed.

Final Compatibility and desktop Mobile runs each contain 80 comparisons and 160 captures (320 final PNGs). The worst car-crop mean difference is 2.939435/255; the largest above-8 fraction is 11.2487%. Every case passes the predeclared appearance and reduction budgets.

[All-five close comparison](evidence/aggressive-car-models-2026-11-07/close-comparison.png) uses cropped native frames. Full-resolution daylight/Night, stock/fitted, overhead/close/rear/macro pairs are retained for both desktop renderers. The close comparison and compact Settings screen were inspected. Small curves, tyre/hardware detail and some fine shading differ; the vehicles retain their designs, finish and fitted silhouettes. This is implementation review, not owner/device appearance acceptance.

## Actual checks

| Check | Actual result |
|---|---|
| Standard raw assets / reduced model structure | 8,004 checks / 0 failures |
| Native Compatibility / desktop Mobile | 400/0 each, 80 stock/fitted daylight/Night comparisons each |
| Every modular kit option, all five vehicles | 6,953 checks / 0 failures across five isolated runs |
| Actual Settings / Garage / race flow | 19/0, including failed Apply and three native viewport sizes |
| Actual Game model policy / shader context / canonical state | 116/0 |
| Retained graphics / shared Settings / racing models / ghosts / driving | 146/0, 1037/0, 88/0, 38/0, 72/0 |
| Prepared assets and photographs | 468 resources; 1925/0 checks; 5 current pictures / 157 source hashes |
| New description translations | 12/0; broad catalogue issue retained separately |

Engine: pinned `4.7.2.stable.official.ed1daf0bf`, through `scripts/run_no_crash_dialog.py`. The standard `scripts/dev.ps1` entry point was verified with the driving suite. Every engine process uses task-private APPDATA/LOCALAPPDATA, an empty backend URL/configuration and Dummy audio. Native windows are off screen. Normal Windows execution was used for the isolated engine runs because the established sandbox certificate-store failure prevents reliable startup.

Commands and exact arguments, owned PIDs, durations and exit codes are retained in [commands](evidence/aggressive-car-models-2026-11-07/commands/). The native contact sheet uses the task-owned `make_comparison.ps1` with the same explicit execution-policy bypass as the standard development entry point; its first direct invocation encountered the machine's disabled-script policy. The task runner is `build/aggressive-car-models-2026-11-07/run.py`. Main invocations:

```powershell
python build/aggressive-car-models-2026-11-07/run.py entry-driving res://tests/test_driving.gd --entry --timeout 180
python build/aggressive-car-models-2026-11-07/run.py assets-final res://tests/check_prepared_assets.gd --pipeline --timeout 1800
python build/aggressive-car-models-2026-11-07/run.py structural-final res://tests/test_reduced_car_models.gd --timeout 600
python build/aggressive-car-models-2026-11-07/run.py final-gl res://tests/test_reduced_car_models.gd --renderer gl_compatibility --timeout 600 -- --output=res://../docs/evidence/aggressive-car-models-2026-11-07/final-gl
python build/aggressive-car-models-2026-11-07/run.py final-mobile res://tests/test_reduced_car_models.gd --renderer mobile --timeout 600 -- --output=res://../docs/evidence/aggressive-car-models-2026-11-07/final-mobile
python build/aggressive-car-models-2026-11-07/run.py settings-final res://tests/test_racing_car_settings.gd --renderer gl_compatibility --timeout 600
python build/aggressive-car-models-2026-11-07/run.py policy-final res://tests/test_optimized_model_policy.gd --timeout 600
python build/aggressive-car-models-2026-11-07/run.py graphics res://tests/test_graphics_settings.gd --timeout 600 -- --output=res://../docs/evidence/aggressive-car-models-2026-11-07/graphics
python build/aggressive-car-models-2026-11-07/run.py racing-final res://tests/test_racing_car_models.gd --timeout 600 -- --evidence-root=res://../docs/evidence/aggressive-car-models-2026-11-07/racing-final
```

The exhaustive modular script is run independently for each `VehicleCatalog.IDS` entry with `--vehicle=<id> --all-kits`; each run has its own task-private profile. The scoped localization check validates the new message in every approved language and compares broad catalogue errors against the archived task baseline. `run.py translations res://tests/test_reduced_car_translations.gd --timeout 120` also passes 12/0 against the actual project-loaded translations.

## Initial findings and limits

The first native runs passed 400/0 each renderer. The initial exhaustive kit run exposed the reduced fitted Compact discrepancy and a rest-pose ghost mismatch before it was stopped by its exact owned process-tree PID for correction. Its partial log is retained and is not counted as a completed suite. The geometry and ghost assertions were not weakened. The old requirement to keep a procedural fitted-shadow fallback is explicitly superseded by safe prepared fitted models with actual casters; the updated assertion requires the prepared base, every selected module and absence of stock proxies, while all geometric equality checks remain.

The retained racing suite initially failed two Settings assertions because it still used the retired preference. It now tests the new independently saved option, including staged Reset. Final review caught non-ASCII text being converted to question marks by the initial shell pipeline. The strings were rewritten from a UTF-8 script, checked byte-for-byte against independent expectations, and verified through the actual project translation loader in all twelve locales. The superseded checkpoint receipt and candidate remain retained separately. The broad `python scripts/localization.py check` remains unpassed because of pre-existing stale/obsolete messages: 6,799 errors versus 6,823 with the archived pre-task catalogues/sources. There are no newly introduced broad catalogue errors; the twelve new translations pass their scoped checks. Unrelated catalogue content is preserved.

The final pipeline has no source changes during or after baking. All 468 scene receipts refresh; changed scene files total 78,643,204 → 78,319,815 bytes (-323,389 bytes). 5 of the five menu PNGs remain byte-exact. Prepared assets and photographs retain their normal source/export guards; the optional tier does not bypass validation.

[task.patch](evidence/aggressive-car-models-2026-11-07/task.patch) and [checkpoint receipt](evidence/aggressive-car-models-2026-11-07/checkpoint-receipt.json) provide the isolated reviewable source/binary change, with forward/reverse application checks and byte-exact ownership verification. Concurrent work and generated build identity are excluded. The first checkpoint whitespace check rejected two raw parser logs for blank final lines; both remain intact in the evidence, with their receipts included and the raw logs omitted from the patch. The final check uses a fresh isolated repository. The main Git index remains byte-exact to the starting hash.

No device query/test, APK export/install, owner-save/process change, live/backend request, backend rollout or deployment was performed. Reload/rebuild is required. Owner appearance acceptance and actual tablet FPS, memory, thermal and loading behavior remain unverified.
