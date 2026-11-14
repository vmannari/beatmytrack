# Garage model optimisation, second pass — 2026-11-13

Implemented locally. This pass removes another **18,321 workshop triangles (11.25%)** and **760,406 bytes of mesh/index/LOD buffers (9.92%)** relative to the accepted first pass. Native comparisons preserve the appearance of the workshop, all six cars, close props and both reflections. Device performance and owner visual acceptance remain unmeasured.

| Requirement | Implementation |
|---|---|
| GMP201 | Review the remaining geometry and compare normal and full-detail rendering in Compatibility and desktop Vulkan Mobile. |
| GMP202 | Remove duplicate-position zero-area triangles and triangles strictly inside another opaque, static bevelled box. Compact unused vertices by copying their original encoded records; do not resample exposed surfaces, normals, colours or UVs. |
| GMP203 | Use 16/32/48 radial samples for small bolts, hubs, brake discs and gallery-light cylinders according to radius. Keep all three large platform cylinders at 96 samples, their dimensions and both rolled platform rings unchanged. Small-fixture chord error stays below 1.1 mm in model space. |
| GMP204 | Rebuild the prepared workshop and six native catalogue photos. Track the new helper and raw packing dependency in workshop/photo provenance and preview identities. Preserve vehicle builders, handling, cache guards and concurrent changes. |

| Workshop measure | First pass / task start | Second pass | Reduction |
|---|---:|---:|---:|
| Triangles | 162,815 | 144,494 | 11.25% |
| Vertices | 213,041 | 193,704 | 9.08% |
| Mesh/index/LOD bytes | 7,664,324 | 6,903,918 | 9.92% |
| Compressed workshop resource bytes | 2,419,449 | 2,144,725 | 11.35% |

The room still has 108 mesh instances. The already optimised turntable remains 5,292 triangles / 177,840 buffer bytes, including contact quads; its five shared material batches and independent reflection materials are retained. This pass reduces geometry, not draw-call count. It does not establish a tablet FPS, thermal, total RAM or loading-time improvement.

The cleanup runs during static material-batch construction, including offline preparation, and is absent from normal frame rendering. Ordinary Garage entry loads the rebuilt native scene; procedural fallback performs the additional cleanup once when it must build that scene. A survey of 1,805 parts / 1,052 box solids found the hidden-face opportunity in about 530 ms on this desktop before implementation. The first cleanup-only result was 156,526 triangles; radius-aware fixture sampling then produced the final 144,494.

The hidden-face rule uses each opaque box's strictly shrunken core, leaving a 10 micrometre local margin beyond the bevel inset. All three triangle corners must lie in the same convex interior. Crossing, coplanar and exposed bevel faces remain. Cutaway roof groups, vinyl and browsable sleeves cannot occlude other batches; hidden, transparent, fading, billboarded, normal-displaced, depth-disabled, unknown-shader and multi-pass finishes cannot act as opaque solids. The smoked record-player lid is explicitly excluded. Existing multi-surface, blend-shape, skinned/compressed and already-LOD-bearing meshes retain their original data rather than losing unsupported streams.

The new helper copies retained GPU position, normal/tangent, colour, UV and UV2 records without decoding and re-encoding them. Source resources remain immutable. Fresh workshop LODs are generated after batching, retaining the existing half-pixel viewport policy and the full-detail master geometry.

Verification used pinned Godot `4.7.2.stable.official.ed1daf0bf`, isolated task APPDATA/LOCALAPPDATA, Dummy audio, an empty backend URL and the crash-dialog wrapper:

- **808 native checks / zero failures in each renderer** in the paired review; **532/0** headless after the fixture's control scene was attached to the tree for automatic cleanup.
- **276 paired images pass** the unchanged Garage bounds: mean RGB difference <0.25/255 and <0.5% of pixels differing by more than 8/255. Actual worst mean is **0.007372/255**, and worst >8 fraction is **0.029297%**. **131 pairs are pixel-exact**, including all **92 car-only reflection pairs**. Both native normal and full-detail meshes are covered, so ordinary LODs cannot conceal a missing surface.
- All six active cars have front, rear and maximum-zoom captures, plus close records, trophies, workbench, tyre rack and overhead views. The paired fixture swaps only room mesh resources around the same car instance, transforms, camera, lighting and live materials. Representative full-detail tyre-rack views were inspected visually before and after.
- Dedicated cleanup proof: **20/0**, covering retained encoded attributes, unused vertices, source immutability, interior/crossing/border cases, nonuniform transformed boxes, animation/cutaway exclusions, transparency/fading/displacement, multi-surface and existing LOD exclusions, and a sparse 32-bit-to-16-bit index transition.
- Radius checks: **38/0**, included in the native review, cover ten radii, closed cylinder caps, exact dimensions/axis extrema, the unchanged large platform and the small-part chord-error bound.
- Existing actual-App Garage suite: **287/0 Compatibility**; focused actual-App Vulkan entry, five sections, repaint/wash/reflections and capture: **15/0**. Existing menu responsiveness: **35/0**, washing surfaces **54/0**, production parser **557/0**. Focused preview/modular dependency routing: **4/0**.
- Native catalogue provenance at the qualified refresh: **six images / 159 current source hashes**, including the new helper and existing raw-packing dependency. Later concurrent vehicle/LOD writes invalidate live catalogue readiness, as noted below.

The global prepared-car preflight remains unqualified: its retained run reports **551 resources / 2,267 checks / 970 stale key/source findings**. No vehicle builder, car configuration, vehicle binary or vehicle-cache guard was authored or replaced by this pass. The separate general build-identity fixture fails before reaching these preview changes because it omits the required `godot-version.txt` checkpoint dependency; its assertions were not weakened. The focused source-routing check passes.

Initial independent-process comparisons failed the appearance gate on concurrent Super Rally car changes (worst mean 0.395980/255 and >8 fraction 1.329536%). The same threshold is retained. Switching to the paired room-only comparison controls the exact car instance instead of attributing those unrelated car changes to workshop cleanup. The unpaired measurements and the failed global preflight are retained. Source receipts also identify a concurrent `rivalry_car_photo.gdshader` edit, which is preserved and excluded from this task's checkpoint.

The initial cleanup fixture contained an invalid conditional-expression `pass`, then attempted to reparent nodes outside the scene tree. Both fixture defects were corrected; the final 20-check run has no engine errors. An initial interactive-shell source-routing attempt was rejected by PowerShell's script execution policy; the explicit `-NoProfile -ExecutionPolicy Bypass -File` run supplies the passing result.

Late closeout: a concurrently introduced `car_static_reduction.gd` initially logged empty-buffer HashingContext update errors in a repeated native attempt. Those logs are retained and are not counted as clean runs. Its current source subsequently contained an empty-buffer guard; the final closeout paired runs again pass 808/0 each without engine errors and supply the retained comparisons. Concurrent edits to `car_mesh_lods.gd` also supersede the live catalogue check and inherited workshop-LOD provenance after the qualified bake. The final source/scene receipt records this drift; no older vehicle or LOD source was restored, and whole-tree export readiness remains unclaimed.

Production source changes are `game/ui/garage_environment.gd`, new `game/ui/garage_mesh_cleanup.gd`, `game/tests/bake_garage_architecture.gd`, `scripts/build_identity.ps1` and `scripts/bake_garage_previews.gd`. New regression/review scripts are `test_garage_mesh_cleanup.gd`, `test_garage_model_pass2.gd` and `test_garage_mesh_paired_render.gd`. Generated workshop/photo assets and their provenance are refreshed. The source checkpoint excludes generated build identity/version output and unrelated work. No Git staging or commit was performed; the shared index's byte hash changed during the session, and the staged diff was empty when inspected.

Representative commands, with isolated task profile variables set in the launching environment:

```powershell
$engine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_garage_mesh_cleanup.gd
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/bake_garage_architecture.gd
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_mesh_paired_render.gd -- --control-room=res://../build/garage-model-pass2-2026-11-13/workshop.before.scn --output=res://../build/garage-model-pass2-2026-11-13/paired/gl_compatibility
# The paired review also ran with --rendering-method mobile.
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_simple_models.gd -- --output=res://../build/garage-model-pass2-2026-11-13/app-gl
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_responsiveness.gd -TestArgument '--output=res://../build/garage-model-pass2-2026-11-13/menu-final' -CommandTimeoutSeconds 180
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_garage_wash_surfaces.gd
python scripts/run_no_crash_dialog.py -- $engine --headless --path game --script res://tests/test_editor_shipping_parse.gd
python scripts/run_no_crash_dialog.py -- $engine --path game --audio-driver Dummy --rendering-method gl_compatibility --position 10000,10000 --script res://../scripts/bake_garage_previews.gd
python scripts/check_garage_previews.py
python scripts/run_no_crash_dialog.py -- python scripts/prepare_car_assets.py --verify --godot $engine --output build/garage-model-pass2-2026-11-13/prepared
```

[Concise receipts, selected comparisons, fixture source, measurements and source checkpoint](evidence/garage-model-pass2-2026-11-13/) are retained. Full capture sets, control scenes and private test profiles are disposable under `build/`. The active-work pin is removed and the repository retention cleaner is run at completion.

Completion cleanup ran successfully with `scripts/clean_build.ps1 -Apply`: 23.54 GiB before/after and zero eligible entries. Recent/protected output remains under the existing retention policy; the task's `.keep` pin is absent. Concise durable evidence is approximately 7.7 MB.

Reload the desktop app to review the result. Owner appearance and device performance acceptance remain. No device attachment query/test, APK/export/install, backend request, deployment, owner-save change or owner-process restart was performed.
