# Garage rendering and model optimisation — 2026-11-01

Implemented locally; tablet frame-rate and owner appearance acceptance remain. No device attachment query/test, APK, deployment, owner save/session mutation, owner-process restart or main Git index write was performed.

| Requirement | Result |
|---|---|
| GPO01 | Audit the actual Garage room and all five current cars, including shadows/reflections and close views. |
| GPO02 | Music no longer forces continuous Garage rendering while the spinning record is outside both the main camera and floor-reflection camera. Playback phase continues. Visible and reflection-only record views remain animated. |
| GPO03 | Prepare index-only mesh LODs offline for the workshop and four stock Garage models. Keep the layered Hover model and all glazing at full detail. Use a conservative 0.5-pixel threshold in the main and reflection viewports. Retain every original vertex attribute, original triangle stream, transform, material and shadow setting. |
| GPO04 | Verify geometry, native before/after images, rendering lifecycle, washing, menus and existing kit transitions without touching owner data. |

The room contains 254,605 full-detail triangles; cars contain 72,060–145,512 each. Geometry is submitted again for shadows and the two planar reflections. Retained one-shot rendering already handled silent idle, but the playing record requested the main view and room reflection every frame even while off camera. The new conservative sphere/frustum check is cached until the camera, viewport or reflection setting changes. A record visible only in the floor reflection still causes rendering.

The prepared meshes add smaller triangle-index streams. Close views retain more detail automatically; there is no runtime mesh generation or blanket switch to the racing models. Full-resolution positions, normals, tangents, UVs, colours and original indices remain exact. The offline helper copies the pinned Godot resource's original GPU storage and transfers only LOD indices, avoiding compressed-normal rounding during a decode/re-encode cycle. Both existing Garage bake tools now retain this preparation. Ordinary race models, handling, saved appearances and customisation rules are unchanged.

At 1280×720 on the desktop RTX 3090, native visible primitive counters give the following normal front-view results. These are main-view triangle submissions, before separate shadow/reflection work; they are not tablet FPS estimates.

| Car | Full-detail main view | Optimised main view | Reduction |
|---|---:|---:|---:|
| Rally | 320,276 | 183,226 | 42.79% |
| Kart | 305,816 | 183,556 | 39.98% |
| Forklift | 364,128 | 199,932 | 45.09% |
| Volt | 339,196 | 193,036 | 43.09% |
| Hover | 290,668 | 215,894 | 25.72% |

In the rotating Hover component sample, all-pass submissions fall from 724,852 to 543,068 triangles/frame (25.08%); draw calls remain 201. With music playing in the normal car view, the control submits 180 draw calls and 652,792 triangles/frame; the final Garage submits no repeated 3D redraw requests (only the retained image's one 2D draw/two triangles). The close record view remains animated, including its room reflection, and leaves the unchanged car reflection idle. Frame samples are capped at 60 FPS and therefore do not establish a speedup or CPU/GPU bottleneck on the tablet.

Verification used pinned Godot `4.7.2.stable.official.ed1daf0bf`, isolated workspace APPDATA/LOCALAPPDATA, empty `BMT_API_URL`, and the scoped crash-dialog wrapper. Compatibility and desktop Vulkan Mobile each pass **1,589 checks, zero failures** in `test_garage_render_optimization.gd`. These include original room buffers, freshly built versus prepared geometry for all five cars, transforms/shadows/wheel positions, real playback visibility, reflection-only visibility, snow melt, orbit, hide/return, native image checks and the canopy-specific regression. The prior headless exact-buffer run passes 1,523/0. Retained existing washing passes **45/0**, and actual-App menu responsiveness passes **35/0**.

Thirty native full-detail/optimised image pairs cover front, rear and maximum zoom for every car in both renderers. The largest mean RGB-channel difference is **0.051605/255**; at most **0.1266%** of pixels differ by more than 8/255 in any channel. Original attributes are exact; LOD output is deliberately not claimed pixel-identical. The closest Hover canopy region matches exactly in both renderers. A separate full-detail comparison against the initial Compatibility captures has at most 0.000265/255 mean byte difference, retained in the report. Views were inspected, including the Volt and closest Hover view. Owner appearance acceptance is still required.

Manual review rejected the first otherwise passing close Hover trial: independently simplified curved cockpit layers intersected, producing visible speckles despite small whole-image error. Final preparation excludes the entire layered Hover model and all glazing from LOD. The rejected captures remain under `after/rejected-canopy-*`; the additional regional regression requires the canopy to match within 1/255 and measures zero difference. The final reduction deliberately gives priority to appearance over the rejected candidate's higher triangle reduction.

The unchanged kit-transition fixture reports **2,424 checks, three failures**: active sweep, immediate equipped compare and preview restore. A control that loads the archived task-start showroom, room and car assets reproduces the same three failures. Assertions were not weakened. Initial restricted launches failed log/certificate-store access; isolated offline normal-access runs completed. An initial missing output-path globalisation, the first compressed-normal trial, one profiling enum argument-order error and a fixture-only nonexistent bounds property are retained in the logs; corrected runs supply the results above.

Actual commands (with isolated profile variables set by the launching PowerShell process):

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_render_cost.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--output=res://../docs/evidence/garage-performance-2026-11-01/baseline/gl_compatibility' -CommandTimeoutSeconds 240
# Subsequent native commands use the same verified pinned executable directly:
$garageGodot = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/bake_garage_cars.gd
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/bake_garage_mesh_lods.gd
python scripts/run_no_crash_dialog.py -- $garageGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/profile_garage_render_cost.gd -- --control --output=res://../docs/evidence/garage-performance-2026-11-01/control/gl_compatibility
python scripts/run_no_crash_dialog.py -- $garageGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/profile_garage_render_cost.gd -- --output=res://../docs/evidence/garage-performance-2026-11-01/after/gl_compatibility
python scripts/run_no_crash_dialog.py -- $garageGodot --path game --rendering-method mobile --position 10000,10000 --script res://tests/profile_garage_render_cost.gd -- --output=res://../docs/evidence/garage-performance-2026-11-01/after/mobile
python scripts/run_no_crash_dialog.py -- $garageGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_render_optimization.gd
python scripts/run_no_crash_dialog.py -- $garageGodot --path game --rendering-method mobile --position 10000,10000 --script res://tests/test_garage_render_optimization.gd
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/test_garage_wash_surfaces.gd
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/test_garage_kit_transition.gd -- --evidence-root='C:/Codes/Godot/Beat my track/docs/evidence/garage-performance-2026-11-01/kit-transition'
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/probe_garage_kit_control.gd -- --evidence-root='C:/Codes/Godot/Beat my track/docs/evidence/garage-performance-2026-11-01/kit-transition-control'
python scripts/run_no_crash_dialog.py -- $garageGodot --headless --path game --script res://tests/test_menu_responsiveness.gd -- --output=res://../docs/evidence/garage-performance-2026-11-01/menu-responsiveness
```

Remaining costs: draw-call count, lighting/material shading, 4× main-view MSAA, display-density rendering, first shader preparation and the close record view. Those have not been reduced by lowering visual quality. LOD preparation covers stock Garage templates; newly fitted modules and procedural fallback retain their original geometry. Added LOD index buffers increase packaged assets and resident geometry memory; per-file sizes are recorded. Source changes safely invalidate existing image-cache identities on a normal rebuild. Do not infer tablet thermal, memory, sustained FPS or cold-start acceptance from these desktop measurements.

[Machine report and file hashes](evidence/garage-performance-2026-11-01/report.json), [image measurements](evidence/garage-performance-2026-11-01/image-review.json), [native views](evidence/garage-performance-2026-11-01/after), [logs](evidence/garage-performance-2026-11-01/logs), and [scoped binary-inclusive checkpoint](evidence/garage-performance-2026-11-01/task.patch). The checkpoint excludes concurrent vehicle/source work and generated build identities; forward/reverse checks and exact-content round trips are recorded in the report. No commit or main-index staging was performed.

The LOD design follows Godot's [screen-space mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) and offline [ImporterMesh generation](https://docs.godotengine.org/en/stable/classes/class_importermesh.html); this task uses a stricter half-pixel threshold than the documented one-pixel default.
