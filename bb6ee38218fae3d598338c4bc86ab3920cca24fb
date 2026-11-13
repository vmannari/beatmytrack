# Prepared car asset pipeline — 4 November 2026

The prepared-asset pipeline now uses vehicle-specific dependency boundaries, rebuilds the complete current car library, and rejects stale prepared resources before Android export. The Compact header template is keyed by geometry rather than by Garage photographs. The procedural fallback remains intact.

Requirements: PAP01 one dependency manifest and accurate shared-helper coverage; PAP02 regenerate current bases/modules/Garage/header resources; PAP03 fail closed on stale or missing bakes; PAP04 retain geometry, material isolation, articulation, shadows and accepted visual quality; PAP05 record actual construction measurements, failures, commands and a task-only checkpoint.

## Implementation

`game/vehicle/prepared_asset_dependencies.json` is read by `prepared_asset_sources.gd` and `scripts/prepared_asset_identity.ps1`. Known Compact, Electric, Kart, Forklift and Hover builders and consumed mesh roots are assigned to their actual cars. Unknown geometry inputs remain shared. Shared Compact finish code still affects its five current consumers; Compact tyre/detail code affects Compact, Electric and Forklift; Electric glass still affects Hover. Shared dispatchers and unknown helpers remain conservative.

The dependency audit checks 183 actual builder/class/resource edges and declared mesh roots. It accounts for the fact that Electric/Forklift call only `CompactDetail.tire()`, while the Compact-specific body/detail entry point remains local. File hashes remain conservative for all three consumers of that shared file. The build-identity regression mutates an isolated repository and verifies local changes, shared helpers, unknown inputs, per-car resources and exclusion of generated outputs. New cross-car helpers or mesh roots must update this manifest and pass the audit.

Runtime source-checkout validation and build identities now share that manifest. The full build preflight validates consumed mesh/livery/font/resource content, in addition to code and shaders. Sorted file paths and their hashes feed compact dependency-tree digests; no consumed file is omitted from those tree receipts. Runtime validation retains the original code, shader, configuration and known geometry-font checks, together with the generated geometry revision, without rereading all binary asset trees on first entry. The preflight checks that this fast projection covers every preserved runtime leaf. Immutable per-process snapshots avoid repeated directory walks/hashing for every kit module. This validation is outside canonical simulation. As before, packaged compiled-script builds rely on embedded engine/configuration/build revisions rather than checkout source files. Editor binary-asset changes require the normal identity generation/preflight workflow.

`modular_car_base.gd` uses the new source receipts; kit validation inherits them. `garage_car_cache.gd` uses a per-car source map and a v2 key including engine and geometry revision. `header_simple_cache.gd` uses a v2 key with the Compact geometry revision, replacing the unrelated Garage-picture revision. Old keys fail closed. Mutable materials, wheel/steering pivots, Hover fan bindings and fallback/rollback behavior remain unchanged.

The bakers force procedural generation before taking their snapshots. All current 20 full/simple editable/fixed bases, 442 non-stock kit modules, five full Garage templates and the Compact header template are regenerated. Existing Garage index-only LOD preparation remains: 0.5-pixel thresholds, full original vertex streams and indices, full layered Hover/glazing detail. Five dormant scene files and historical source assets are retained.

`scripts/prepare_car_assets.py` is the repeatable entry point. It validates the pinned engine, uses a private offline profile, generates identities, checks whether geometry is already current, rebuilds when required, refreshes native Compatibility pictures when their provenance is stale, and verifies that outputs do not change geometry revisions. Constructor/cache/policy source changes during baking fail the run. Generated outputs are excluded from their own geometry identities. A completed default run therefore needs no second bake; `--verify` performs read-only validation without regenerating identities or assets.

`scripts/dev.ps1` runs this preflight before its existing Android export checks. It passes the selected pinned engine through to the verifier. `export_presets.cfg` explicitly includes the dependency manifest. No Android export was performed by this task.

## Validation

The geometry preflight checks every one of the **468 expected current scenes**: existence/loadability, exact engine/configuration keys, current complete source receipts, stored articulation and header revision. It also verifies the fast runtime projection against every preserved code/configuration/font leaf. It passes **1,925 checks / 0 failures**. Before rebuilding after the receipt-format change, the preceding 1,920-check version rejected stale keys/receipts with **936 failures**; those logs remain as a positive invalidation control.

The exhaustive modular suite passes **6,929 / 0** on final compact-receipt sources, checking every non-stock module at both qualities, original triangle streams/attributes, materials, shadow geometry, articulation, mutable-material isolation and stale/corrupt module rollback. The preceding expanded-receipt run also passed 6,929/0 and is retained separately.

Forced-procedural versus restored Garage and header geometry/material checks pass **20 / 0** and **12 / 0**. These fixtures now compare against genuinely procedural models rather than accidentally consuming a valid modular base. Anonymous Godot node names are normalised with the same stable-name routine used by the baker; transforms, hierarchy, geometry and finishes are still compared exactly.

The native three-way comparison matrix covers all 20 base configurations, five decorated fitted configurations, all five full live Garages with both planar reflections, and the actual Compact header presentation. It asserts actual prepared base/module/Garage/header hits. Compatibility and desktop Mobile each pass **164 / 0**, including final compact-receipt reruns. The largest mean RGB-channel difference in the first accepted matrix is **0.012076/255**, and at most **0.0401%** of pixels differ by more than 8/255. All per-run measurements are retained in the summary.

The unchanged retained Garage rendering/LOD suite passes **1,571 / 0 on each desktop renderer**, using newly captured front/rear/maximum-zoom full-detail versus LOD pairs for all cars. Its stricter close Hover canopy comparison remains intact. This adds 60 captured views. The native comparison matrices add 186 views across both renderers. These are desktop source-project tests, not physical-device or packaged-build acceptance.

The initial native diagnostic incorrectly demanded byte-identical pixels. That conflicts with the approved Garage LOD contract and with the already documented tiny procedural-repeat differences in modular car rendering. Its 33 failed assertions, captures and original fixture are retained. The corrected fixture uses the pre-existing GPO03/GPO04 bounds from `test_garage_render_optimization.gd`—mean channel delta below 0.25/255 and fewer than 0.5% of pixels above 8/255—alongside exact geometry/material checks. No production LOD setting or existing appearance gate was relaxed.

The isolated build-identity tests pass **128 vehicle/hash checks plus two complete-identity checks**, and the retained build-identity suite passes **18**. An owned minimal-project test passes **68 / 0**, demonstrating that mesh-byte changes, renames, deletion, shared artwork/fonts, per-car resources and new unknown helpers change the correct dependency-tree receipts; generated outputs do not. It also checks that callers cannot mutate cached snapshots and that runtime validation covers every preserved leaf. Photograph provenance passes **five positive/invalidation checks** covering changed prepared scenes, geometry revisions, model source and PNG content. Four changed PowerShell files parse successfully. Scoped Ruff and Python compilation checks pass for the four new public Python tools and the updated photograph checker.

The selected final validation set totals **12,577 passing checks / 0 failures**; repeated/supporting runs are not added to that total. The final read-only export preflight passes both geometry and photograph validation. `git diff --check` passes for the changed implementation files, with only Git line-ending conversion notices.

## Measurements and size

Construction results, all samples, actual cache hits and before/after scene byte totals are in the derived [summary](evidence/prepared-asset-pipeline-2026-11-04/summary.json). The construction fixture alternates procedural and prepared detailed fitted cars in the same private process, with three pairs per car. Report the first pair separately; later medians describe warm component wall time, not application launch, frame-rate, cold-driver or phone performance. Prepared attachment remains synchronous and can block a loading frame even when no cooperative model-building yields are needed.

| Car | Warm procedural construction median | Warm prepared construction median |
| --- | ---: | ---: |
| Rally | 176.241 ms | 27.736 ms |
| Kart | 80.568 ms | 23.021 ms |
| Forklift | 132.381 ms | 25.126 ms |
| Volt | 87.244 ms | 25.545 ms |
| Hover | 63.956 ms | 27.867 ms |

Each warm median uses the two later pairs; thirty total observations and all five first-use pairs are retained. Every prepared observation records one base and four module hits. The host is shared, and these small samples do not establish a general percentage gain.

The first paired Rally observations are 692.972 ms procedural and 83.226 ms prepared; Kart is 169.315/33.625 ms. The prepared observation follows its procedural control and benefits from shared first-use work. These are not independent cold-launch measurements. They confirm that the interim binary-tree scan has been removed from model construction, without weakening the full build/export preflight.

An interim expanded source manifest added about **35.92 MiB** to the prepared scenes by duplicating thousands of mesh hashes in every module. That interim was replaced before delivery by sorted dependency-tree digests and per-process snapshot reuse, while preserving individual configuration/font leaves for the runtime guard. The final library is **57.122 MiB**, versus **57.328 MiB** at task start (0.206 MiB smaller); input-byte coverage is preserved. No package-size saving is inferred from raw scene sizes, and no APK was built.

The complete final pipeline succeeds with zero constructor/cache/policy source changes during baking and unchanged geometry revisions across all emitted outputs. A second default invocation succeeds with **no bake stages and no native captures**. All five 2048×512 bundled pictures and their 156-source provenance manifest pass the checker. The photographs are additionally bound to the actual prepared Garage scene hashes and geometry revisions, so changing only a mesh/scene cannot leave stale bundled photographs accepted. This also covers a configuration-key change that rebuilds a Garage scene without changing a photograph's own rendering source files. Compared with task-start photographs, mean channel changes are 0.000278–0.008196/255; the studio, car lighting, polished deck and real reflection remain. Existing LODs are now available to previously falling-back cars, so these refreshed photographs are not claimed byte-identical.

## Reproduction and retained findings

From the repository root:

```powershell
python scripts/prepare_car_assets.py --output build/prepared-car-assets
python scripts/prepare_car_assets.py --verify --output build/prepared-car-assets-verify
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_modular_car_identity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_build_identity.ps1
python scripts/check_prepared_asset_dependencies.py
python scripts/test_prepared_dependency_receipts.py
python scripts/test_garage_preview_provenance.py
```

The [evidence directory](evidence/prepared-asset-pipeline-2026-11-04/) contains before snapshots, source receipts, build identities, native images, logs, commands and owned process IDs. `run_check.py` launches a bounded private offline pinned-engine process through `scripts/run_no_crash_dialog.py`. Its labels preserve initial attempts rather than overwrite them. `summarize.py` derives machine-readable results, and `checkpoint.py` produces and forward/reverse-checks the task-only source/binary patch in an owned workspace directory.

Retained initial findings:

- The first bake completed all resources but its initial source guard also tracked unrelated UI work. Concurrent App/Garage preparation edits caused that guard to reject the run. All geometry revisions were unchanged; an independent preflight verified the complete emitted library. The guard was narrowed to constructor/cache/policy inputs, and the final pipeline rerun uses those boundaries.
- Initial exact-array equality tests exposed only generated node-name differences when forcing the procedural path; the fixtures now use the baker's stable names. The original 10 Garage and three header assertion failures are retained.
- The first retained Garage suite lacked its archived full-detail room and paired-image fixtures in the new evidence destination. Its load/output errors and bounded failure remain. A scoped stop of the owned diagnostic tree was denied by Windows; no owner process was touched. The complete fixture and fresh pairs were then installed in owned directories and both final retained suites passed.
- Initial dependency-audit lint findings and a nested-shell PowerShell parser invocation were corrected. The direct parser and final scoped lint checks pass.
- The first minimal dependency-receipt fixture omitted an empty `track` directory and a private user-directory environment. It still recorded 63/0 assertions but emitted directory/log errors; the corrected isolated fixture passes with only the retained certificate-store diagnostic.
- Warm timing alone hid an interim first-use source-checkout regression: full binary-tree hashing made the first Rally/Kart prepared samples slower than procedural controls. The final implementation keeps full byte checks in the build/export preflight and retains lightweight runtime code/configuration/font guards plus the generated geometry revision. The earlier timing rows remain under `construction-final`; final runtime-guard measurements are reported separately.
- The first runtime-leaf fixture did not seed its known geometry font/cache helper files. That fixture was completed before acceptance; the final 68 checks pass, and the real-project preflight independently checks all five runtime projections. No runtime leaf was removed to satisfy the fixture.
- Native/headless logs retain the environment's Windows certificate-store error. There is no blanket clean-log claim.

Concurrent startup-shell/shared-graphics work is preserved. Receipts report its source changes explicitly; those runtime sources are excluded from this task's checkpoint. Generated overall build identities/project version reflect the shared workspace and are recorded as evidence rather than bundled as task-only source hunks. Run the normal identity generation after applying the checkpoint elsewhere.

No phone/device query or test, APK, real authentication/purchase, owner-save change, owner-process restart, backend/live request or mutation, deployment or main-index write. Reload/rebuild, owner appearance acceptance and representative Android loading, memory, frame pacing and thermal checks remain. This task repairs prepared construction; it makes no whole-startup or first-race speedup claim.
