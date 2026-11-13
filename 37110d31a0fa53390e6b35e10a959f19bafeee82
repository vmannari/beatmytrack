# Garage model simplification — 2026-11-12

Implemented locally. The workshop retains its rounded outlines, bevels, materials, lighting, shadows, furniture, record player and both planar reflections. The approved reduced cars and their fitted parts are unchanged by this task.

| Requirement | Change and evidence |
|---|---|
| GMS01 | Review actual Garage geometry, all six active cars, front/rear/maximum zoom, close record/trophy/workbench/tyre views, overhead view and both reflected views. |
| GMS02 | Remove four unnecessary height rings from straight furnishing tubes and the three turntable cylinders. Retain every radial sample, cap, end-ring position, normal and UV. Curved/tapered profiles, toruses and bevels retain their detail. |
| GMS03 | Cache the five immutable turntable material batches in one PackedScene. Reuse their meshes when constructing another display. Each instance owns its deck reflection material; car attachment, steering, paint, contact shadows and transitions remain live. |
| GMS04 | Rebuild the packaged workshop and native catalogue photographs; extend workshop provenance to cover its previously omitted workshop/plant builders, plant shaders and inherited LOD generators. Retain the original half-pixel viewport LOD policy. |

Measurements use a fresh control generated with the original height rings and uncached pedestal, using the same current prop and artwork sources as the final build:

| Component | Control | Final | Reduction |
|---|---:|---:|---:|
| Workshop triangles | 254,927 | 162,815 | 36.13% |
| Workshop vertices | 261,569 | 213,041 | 18.55% |
| Workshop mesh/index/LOD bytes | 10,111,528 | 7,664,324 | 24.20% |
| Turntable triangles, including unchanged contact quads | 7,596 | 5,292 | 30.33% |
| Turntable buffer bytes | 224,256 | 177,840 | 20.70% |

The workshop still has 108 mesh instances and the pedestal has 11 including contact quads. This reduces geometry and repeat construction, not draw-call count. The final workshop resource is about 2.42 MB versus 3.39 MB for the previously packaged room. Compatibility pedestal reconstruction samples fall from 5.286 ms in the control to 0.360 ms in the final run; these are desktop component samples under variable host load, not a device/FPS guarantee. The Vulkan control's unusually slow allocation sample is retained but excluded from a speedup claim. The cached scene's neutral deck material is isolated from the first live stage as well as subsequent instances, so it retains no viewport texture.

Native verification uses pinned Godot `4.7.2.stable.official.ed1daf0bf`, the desktop RTX 3090, a separate APPDATA/LOCALAPPDATA under this task's disposable build directory, Dummy audio and an empty `BMT_API_URL`. No owner data or running game/editor was changed.

- Dedicated native geometry/cache/capture checks: **107 checks, zero failures in each renderer**; Compatibility and desktop Vulkan Mobile each capture 23 views and their two reflections.
- All **138 image pairs** pass the established Garage appearance bounds: mean RGB difference below 0.25/255 and fewer than 0.5% of pixels differing by more than 8/255. Final worst mean is **0.132615/255**; worst >8/255 fraction is **0.433377%**. Other pairs have small edge/interpolation/LOD differences, so pixel identity is not claimed. The close record and workbench views remain especially close, and representative views were inspected visually. The preceding capture set measured a worst mean of 0.015102/255; the final Super Rally close pictures also include independent concurrent car-render variation. No car source or vehicle binary was authored in this task.
- Structural/source-control review: **1,703 checks, zero failures**. Hierarchy, transforms, bounds, material slots, shader code, finish properties and texture pixels match. Direct primitive tests cover seven radial resolutions and exact retained cap/end-ring attributes. The five pedestal buffers are shared; changing one deck's reflection material does not change another's.
- Actual App Garage suite in Compatibility: **287 checks, zero failures**, including retained views, every car, fitted parts, repainting, washing, saved condition and both reflections.
- Focused actual-App Vulkan Garage smoke: **15 checks, zero failures**, covering entry, five sections, retained pedestal, repainting, washing, both reflections and a native capture.
- Existing menu responsiveness: **35/0**; washing surfaces **54/0**; production script compilation **553/0**; dependency routing **183 edges**; native catalogue validation **six images / 157 current source hashes**.

The wider prepared-car preflight does **not** pass: **551 resources / 2,267 checks / 188 stale key/source findings**, retained with diagnostic source differences. These concern full Garage rest templates, vehicle modules, Super Rally generated geometry and the header template. The two runtime scripts edited here are outside the modular-car identity inputs; no vehicle builder, handling resource or vehicle-cache guard was changed. Complete project export readiness is not claimed, and the larger vehicle library was not overwritten to resolve this separate finding.

The first capture fixture incorrectly called an ArrayMesh-only counter on primitive meshes; the finding is recorded and the fixture now reads generic mesh arrays. The original packaged workshop was also behind current source changes: 94 versus 108 mesh instances, older record artwork and a 322-triangle source difference. The source control avoids attributing that existing drift to simplification; the final bake preserves the current sources. An exact-byte packing survey saved only about 1.3% of the old room's buffers and was not adopted. A full Vulkan actual-App interaction run reached APP_READY but exceeded its 180-second limit; its owned process tree was stopped, and it is not counted as a pass. The focused Vulkan App smoke, native component checks and image comparisons pass independently.

Changed production files are `game/ui/garage_environment.gd`, `game/ui/garage_furnishings.gd`, the packaged workshop/provenance and the six active catalogue PNGs/provenance. Preparation/test sources are `game/tests/bake_garage_architecture.gd` and `game/tests/test_garage_model_simplification.gd`. Build identity/version output from the normal dev entry point is generated and excluded from the source checkpoint. Existing changes elsewhere are preserved; no main-index write or commit was made.

Representative commands, with the isolated profile environment described above:

```powershell
$engine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/bake_garage_architecture.gd
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_model_simplification.gd -- --phase=source-control --output=res://../build/garage-model-review-2026-11-12/source-control/gl_compatibility
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_model_simplification.gd -- --phase=final --output=res://../build/garage-model-review-2026-11-12/final/gl_compatibility
# The same two native comparisons were run with --rendering-method mobile.
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_garage_model_simplification.gd -- --phase=final --reference-room=res://../build/garage-model-review-2026-11-12/source-control-gl_compatibility.scn --output=res://../build/garage-model-review-2026-11-12/structure
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://../scripts/bake_garage_previews.gd
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_responsiveness.gd -TestArgument '--output=res://../build/garage-model-review-2026-11-12/menu' -CommandTimeoutSeconds 180
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_simple_models.gd -- --output=res://../build/garage-model-review-2026-11-12/app-garage-gl
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_garage_wash_surfaces.gd
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_editor_shipping_parse.gd
python scripts/check_prepared_asset_dependencies.py
python scripts/check_garage_previews.py
python scripts/prepare_car_assets.py --verify --godot $engine --output build/garage-model-review-2026-11-12/prepared
```

Concise receipts, image measurements, selected source-control/final comparisons, actual-App capture, source checkpoint and retained findings are in [the evidence directory](evidence/garage-model-simplification-2026-11-12/). Full captures, test profiles and transient control scenes remain disposable under `build/`; they are not archived as permanent project copies.

Reload the desktop app to use the new meshes. Owner visual acceptance and device performance remain unmeasured. No device attachment query/test, APK/export/install, backend request, deployment, owner-save edit or owner-process restart was performed. The build-retention cleaner is run at completion; its target can remain exceeded by protected or recently active output.

Completion cleanup: automatic approval review rejected the direct recursive deletion of this task's verified build directory. Its temporary `.keep` pin was removed and the authorized repository cleaner completed successfully: 21.85 GiB before/after, zero eligible entries. Recent output remains subject to the ordinary 24-hour grace and seven-day retention; the 20 GiB target is exceeded by recent/protected output. Concise permanent evidence occupies about 6.2 MB.
