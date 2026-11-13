# Electric model review fixes — 2026-10-25

The owner authorizes fixing the three findings in the [native model review](evidence/electric-model-review-2026-10-25/review.json). The corrected original model retains the sportback identity, continuous narrow front light, existing paint/material system, wheel articulation and electric-3 driving behavior.

| Requirement | Change and evidence |
| --- | --- |
| EMF01 / review F01: sharp body joins | Shared rolled shoulder and end profiles replace abrupt slab edges. Front/side and rear/side skins use common height stations and boundary normals in both detail levels. Every one of 138 tested end-edge vertices has a matching side position; maximum normal difference is 0.0083°. Native optics/side/rear views show the smoother transitions. |
| EMF02 / review F02: incomplete rear-door seam | Both doors use closed authored outlines and share one vertical gap. The rear bottom edge joins it at Z=0.26 instead of starting at 0.405. The paint itself forms a shallow channel with thin dark trim inside it. Actual mesh rays sample the formerly missing span on both sides and both detail levels, reaching approximately 0.00324–0.00325 model units below the surrounding skin. |
| EMF03 / review F03: flat rear overlays | Rear skin cells leave openings for rounded plate and optical pockets. Rolled painted entry rims, inner returns and inset backs provide real depth. Rays reach the plate insert 0.052 model units inward, plate back 0.060 inward and rear light 0.026 inward. Outer neighboring skin remains intact. |

The implementation is confined to `game/vehicle/electric_coachwork.gd`. Prepared v4 resources replace v3 after an exact local backup and a runtime-reference check. The bake contains 519 prepared full/simple meshes. Full/simple model counts are **164,776 / 64,796 triangles**, up from 154,276 / 55,700, within the unchanged 170,000 upper bound. These counts are not a phone performance measurement. Catalogue artwork and all 49 appearance photos were regenerated from the production model and imported.

R01 preserves exact task-start hashes for `electric.tres`, `vehicle_simulation.gd`, `car_visual.gd` and `electric_car_model.gd`. The independent local verifier still reports physics `arcade-planar-0.68`, handling `electric-3` and config hash `866d2886bdd38f3f75865b8fc10be838ad644a6b3bd0ea06f93321823e2b3cc7`. No physics or competitive-record migration is required. One pedal, no handbrake, brake-position D/R, faster launch, calmer rear slip and complete-stop regeneration remain as accepted in the preceding tuning task.

## Actual validation

From the repository root, use pinned Godot 4.7.2 via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_electric_model.gd` | 519 prepared resources. |
| `-Action TestScript -ScriptPath res://tests/test_electric_surface_finish.gd` | 34 checks, zero failures: actual baked edge positions/normals, mesh-ray pocket depths and continuous recessed lower door gaps. |
| `-Action TestScript -ScriptPath res://tests/test_electric_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-model-fixes-2026-10-25/model` | 34 checks, zero failures; finite geometry/normals, unchanged budget, batching, Compact finish, calipers and native day/night light continuity. |
| Same model test with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-model` output | 34 checks, zero failures on desktop Mobile. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --bake-art` | Refreshed native catalogue illustration. |
| `-Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --vehicle=electric` | 49 actual appearance photos. |
| `-Action Import` | Normal pinned resource import; native log retained. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car.gd -TestArgument --evidence-root=res://../docs/evidence/electric-model-fixes-2026-10-25` | Existing 60 checks, zero failures, including replay/rewind; 72 km/h in 0.733 seconds and release stop in 1.8 seconds / 17.842 metres. |
| Same output argument with `res://tests/test_electric_one_pedal.gd` | Existing 63 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-model-fixes-2026-10-25/native` | Actual Garage/race 59 checks, zero failures. |
| Same UI test with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-native` output | Actual Garage/race 59 checks, zero failures on desktop Mobile. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 1,161 scripts, zero failures. |

The existing 34-check model suite and 170,000 triangle threshold were retained. The new regression checks operate on the baked meshes, including ray intersections, rather than merely checking authored parameter values. Headless server manifest validation reads the current project through `GodotVerifier.manifest()`; no live service request or upload occurs.

## Retained corrections and limits

The first bake encountered a typed-array conditional-return error; using a typed local outline corrects it. The first revised native view exposed thin join/shading lines despite passing the established tests. Its images remain in `initial-model/`; shared boundary stations/normals and the new mesh checks correct the defect. The first regression probe assumed unsanitized node names containing decimal points; prefix/geometry lookup corrects the fixture without reducing an assertion.

Concurrent localization then introduced an unimported Noto Symbols font. Initial artwork, appearance-photo and replay test processes failed at that preload. A diagnostic pinned recovery import populated the font cache, followed by the normal pinned import and successful reruns. Recovery output includes errors and is not counted as a clean import. No localization source or established assertion was changed. All these error logs remain in the evidence bundle.

[Before/after native views](evidence/electric-model-fixes-2026-10-25/gallery.html), [surface measurements](evidence/electric-model-fixes-2026-10-25/surface-finish.json) and [report/checkpoint](evidence/electric-model-fixes-2026-10-25/report.json) retain requirements, commands, hashes, results and an exact task-only Git-checkable patch. Concurrent kart, forklift, Garage, localization, website and backend work is preserved.

Reloading the client and owner/device appearance, motion and frame-pacing acceptance remain. Desktop Mobile is a Vulkan renderer check, not a physical-device test. No phone/tablet attachment check or device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Native manual-stepping hitch diagnostics are not a performance benchmark. This closes the three scoped construction findings; it does not declare general AAA or device acceptance.
