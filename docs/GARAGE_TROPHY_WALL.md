# Garage detail and right-side trophy wall

Owner request, 2026-10-12: GC15 (clearer premium rail icons), GC16 (workshop detail), GC17 (recognisable spare tyres/wheels), GC18 (visible trophy cabinet on the right-hand side wall), GC19 (dedicated camera view and return). Preserve GC06–GC14/CW13/CW15/CW16/V06/G01/R01/Q01. AAA remains a visual quality target requiring owner and physical-device review.

The cabinet is mounted on the garage's negative-X side wall, which is on the right when looking into the showroom. Six empty display bays have inset felt backs, metal trim, deep timber shelves, illuminated undersides and award bases. The wall remains visible behind the pedestal in the normal car view. Its trophy rail action is available both during car browsing and after Select car; browsing a trophy wall does not confirm a previewed car. No earned trophies, grants, trophy inventory, backend calls or new race criteria are introduced: the requested display is ready for future award integration.

Selecting Trophy wall moves the existing camera toward that cabinet over 0.65 seconds, with eased rotation and a raised travel path. Choosing Customise, Care, Tuning or Back to cars returns to the existing car pose, including its current yaw, tilt and zoom. Rapid switches cancel the previous movement. Trophy viewing stops a wash gesture and hides the car controls; leaving Care still saves the exact partial wash. The car and pedestal retain horizontal rotation while the workshop stays fixed.

Garage rail artwork is now original solid monochrome SVG silhouettes: front-view car, palette, car/droplet, wrench and trophy. The consistent 40px optical size uses 4x rasterisation and mipmaps, existing gold selection states and tooltips. The shared general menu image remains visible around the showroom. Workshop detail adds shelving and supply containers, brackets, utility cabinets, conduit and a finned compressor. The former black torus tyres are replaced by four complete spare wheels with profiled flattened tread/sidewalls, shoulder transitions, rim lips, brake discs, five spokes, lug nuts and tread blocks. Geometry is prepared in the existing material batches and full/thumbnail caches; thumbnails still use actual car models and render only on demand.

Changed runtime files: `game/ui/garage_page.gd`, `car_showroom.gd`, `garage_environment.gd`, `garage_mode_icons.gd`; added `game/ui/garage_details.gd` (+UID). Updated `game/tests/test_garage_carousel.gd` adds actual camera, rapid-switch and condition-preservation checks plus optional motion recording, retaining prior navigation/paint/wash/model assertions. Documentation: this file, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands on pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -TestArgument '--capture-gallery-motion=res://../docs/evidence/garage-trophy-wall-2026-10-12'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-trophy-wall-2026-10-12/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/encode_garage_trophy_motion.py
python build/checkpoint_garage_trophy_wall.py
```

Compatibility camera/carousel **295 checks** (including 120 actual saved frames), desktop Mobile/Vulkan **175**, view controls **59**, manual washing/local persistence **1,402**, exact native model/glazing/render regression **80**: zero failures. Import passes. Shared menu swipes **268 checks**, zero failures. Cold page construction measured 425.678ms on RTX 3090; isolated Compatibility studio viewport CPU median/p95 0.704/1.033ms, GPU median/p95 0.304/0.317ms. Those desktop samples do not establish phone performance. Native car remains 64 meshes/104,558 triangles with exact baked/source geometry and glazing equality.

Fresh captures include browsing, selected-car menus and trophy close-up at 960x540, 1280x720 and 1600x720 on both renderers. Inspected [main garage](evidence/garage-trophy-wall-2026-10-12/cars-1280.png), [right wall close-up](evidence/garage-trophy-wall-2026-10-12/trophy-wall-1280.png), [Customise](evidence/garage-trophy-wall-2026-10-12/customise-1280.png) and [actual camera movement](evidence/garage-trophy-wall-2026-10-12/trophy-camera-motion.png). Motion is a lossless APNG assembled with Python stdlib from 120 actual Godot frames at 960x540; 30fps playback/4 seconds is for review, not a capture-performance measurement. Raw frames are in `build/garage-trophy-motion-2026-10-12`; the animation is approximately 35MB.

Initial rear-wall placement and workbench occlusion were corrected after inspection and the owner's right-side instruction. The final camera is pulled back enough to include the cabinet sign. An earlier combined CLI argument produced a separate intermediate evidence folder without motion; the final single capture argument above produced the verified 120 frames. No assertion was removed or weakened.

Task-only two-commit Git checkpoint: `build/garage_trophy_wall/checkpoint-repo`; baseline sources, patch, hashes and actual logs: `docs/evidence/garage-trophy-wall-2026-10-12`. The main branch/index and concurrent unrelated work are preserved.

Doctor found no attached Android device. No phone test, export/install, full Validate, physics merge/regression, backend operation or deployment was performed. Owner visual/icon-recognition review, all-five-car framing, moving-camera inspection and physical-device input/readability/performance remain acceptance checks. Future race award storage, award models and population of the wall remain outside this presentation slice.
