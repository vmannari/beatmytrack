# Desktop Desert appearance regression — 2026-11-07

DAR01 identifies the reported desktop failure; DAR02 checks the corrected source in fresh worlds and the actual App. The owner reported missing Desert objects and road texture and confirmed this was the desktop game.

## Cause and source ownership

The owner's desktop log contains `Cannot find member "sha256_text" in base "PackedByteArray"` at `track/scenery_mesh_lods.gd:12`. This prevented the scenery dependency graph from compiling, followed by missing `append_plan`, `prepare_source`, `apply` and `packets` calls, empty prop surfaces and failed spatial preparation. The [retained excerpt](evidence/desert-appearance-fix-2026-11-07/desktop-compile-error.log) records the initial compiler failure and its dependent-script failures. Only the diagnostic excerpt was copied; owner records and track files were not changed.

The concurrent scenery task had already corrected `SceneryMeshLods.signature()` before this investigation inspected it: it uses `HashingContext.HASH_SHA256`, hashes the serialized geometry bytes and returns `finish().hex_encode()`. That correction is preserved and is not attributed to this task. A process that loaded the failed script needs a full game restart to load the corrected dependency graph. The source on disk passed all fresh-process appearance checks below. This task does not add a separate runtime workaround or change the approved artwork.

The log directly establishes the scenery failure. The road-texture complaint was not independently reproduced in fresh processes: the actual bound approved road texture contributes substantial rendered pixels in both tested desktop renderers. After restarting the desktop game, the owner explicitly confirmed **both objects and road texture are restored**. Desktop acceptance for the reported regression is complete.

## Changes

- `game/tests/test_desert_appearance.gd`: valid authored Desert circuit with Egyptian props, rocks, slate, cliff, signs, flag and gantry; synchronous build, sliced first build and prepared-world reuse; artwork binding, actual prop/texture pixel contribution and unchanged canonical track data.
- `game/tests/test_desert_app_appearance.gd`: fresh actual App startup and first/repeated race installation; complete world, Egyptian geometry, approved road binding and native prop/texture pixel contribution.
- `scripts/run_desert_appearance_checks.py`: pinned standard 4.7.2 engine, crash-dialog wrapper, private offline APPDATA, Dummy audio, bounded execution, retained logs and command receipts. Nonzero exits and engine errors fail the runner; the sandbox's separately recorded certificate-store error is the only exempt error.
- This report, source receipt, native pictures and task-only patch. No main Git index write.

## Actual commands and outcomes

Commands run from the repository root. Each invocation has its full command/exit/duration receipt and log in [the evidence folder](evidence/desert-appearance-fix-2026-11-07/).

```powershell
python scripts/run_desert_appearance_checks.py appearance-baseline-headless res://tests/test_desert_appearance.gd --headless -- --stage=baseline
python scripts/run_desert_appearance_checks.py appearance-baseline-gl res://tests/test_desert_appearance.gd --rendering-method gl_compatibility -- --stage=baseline
python scripts/run_desert_appearance_checks.py appearance-baseline-mobile res://tests/test_desert_appearance.gd --rendering-method mobile -- --stage=baseline
python scripts/run_desert_appearance_checks.py app-headless res://tests/test_desert_app_appearance.gd --headless
python scripts/run_desert_appearance_checks.py app-gl res://tests/test_desert_app_appearance.gd --rendering-method gl_compatibility
python scripts/run_desert_appearance_checks.py app-mobile res://tests/test_desert_app_appearance.gd --rendering-method mobile
python scripts/run_desert_appearance_checks.py final-headless res://tests/test_desert_appearance.gd --headless -- --stage=final
python scripts/run_desert_appearance_checks.py shader-flags res://tests/test_surface_shader_pruning.gd --headless
```

| Check | Result |
|---|---|
| World, headless baseline and final | 14 checks / 0 failures each |
| World, Compatibility | 20 / 0 |
| World, desktop Mobile | 20 / 0 |
| Actual App, headless | 40 / 0 |
| Actual App, Compatibility | 44 / 0 |
| Actual App, desktop Mobile | 44 / 0 |
| Existing shader-pruning regression | 39 / 0 |

The native world checks exercise three preparation paths per renderer. Compatibility's road-texture control changes 217,533 pixels and Egyptian-prop control changes 113,374 pixels in every path; desktop Mobile gives 154,214 and 95,399 respectively. In the actual Compatibility App, both first and repeated race controls change 183,168 road-texture pixels and 82,909 Egyptian-prop pixels. Both native App runs reach `APP_READY` and two `PLAYGROUND_READY` installations. Native views were inspected, including [the road](evidence/desert-appearance-fix-2026-11-07/app/gl_compatibility/pass0-road.png) and [the pyramid](evidence/desert-appearance-fix-2026-11-07/app/gl_compatibility/pass0-pyramid.png).

## Retained findings and limits

The existing `test_desert_visibility_regression.gd` was also run in private headless and Compatibility profiles with `--evidence=res://../docs/evidence/desert-appearance-fix-2026-11-07/baseline`. It returns **22 / 1** and **28 / 1**, respectively: its exact-array comparison against the archived October 24 deformation script fails. Its current prop retention, actual App cold/warm pyramid visibility and wind-sand gates pass. The failure is retained without weakening its assertion or claiming this investigation resolves that historical comparison.

An initial standard `scripts/dev.ps1 -Action TestScript` invocation could not open the default `user://` log and reported Access denied; it exited 1. Subsequent checks use private offline profiles. The sandbox also denied a read-only process-command-line query; inspection proceeded through the existing desktop log. Fresh test runs retain the certificate-store diagnostic, and graphical App fixtures retain focus/compilation frame-hitch logs; no performance claim is made.

No device test was performed. No APK, deployment, backend request, gameplay/physics change, owner-save edit, agent-initiated owner-process restart or manual cache deletion was performed. The owner restarted the desktop game and confirmed both reported symptoms are resolved. Concurrent scenery/vehicle/ranking work is preserved. Source hashes and task additions are recorded in `evidence/desert-appearance-fix-2026-11-07/source-receipt.json` and `task-additions.patch`.
