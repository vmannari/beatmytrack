# Trophy wall final visual pass ? 2026-10-13

Owner request: review the existing trophy wall and refine where needed. GVP01: coherent materials without distracting fine patterns; GVP02: readable dimensional brand/laurel; GVP03: controlled light/edge presentation. Preserve GC27?GC29/GWR01/GRD01?GRD03/V06/G01/R01/Q01. AAA remains an owner and physical-device visual acceptance target.

Review of both prior renderer captures found a periodic backing pattern, flat-normal leaves, much brighter stone in Mobile/Vulkan, and speckled thin metal edging. The pass keeps the established composition, original laurel silhouette, round fixtures, six empty award bases and local vehicle behavior.

`game/ui/garage_details.gd` now uses folded face normals for the existing relief leaves, rounded stems/midribs and a warmer satin gold finish. Existing wording is generated once as shallow 24mm 3D lettering from the project's cleared display font, with the same established two-line content and a small readability adjustment. Tiny empty plaques align with the bases' front edges. Perimeter emission is lower/warmer; three existing spots use a softer less-yellow wash. Metal edging uses smooth satin response instead of a high-frequency brushing normal that speckled in larger captures. The original room batching and architecture cache still prepare this geometry.

`game/ui/garage_display_stone.gdshader` binds its three pigments through source-colour uniforms, so both rendering paths use the intended colour. Existing satin reflection response and bounded actual-light highlight approximation remain; this adds no scene capture or texture sample. `game/ui/garage_display_backing.gdshader` (+UID) provides a smooth charcoal upholstery finish with only restrained broad variation, avoiding the periodic weave and tiny perturbed normals on the backing. `game/tests/capture_trophy_wall_reflections.gd` additionally captures trophy view at 960x540, 1600x720 and 1720x914 alongside the retained 1280x720 view and on/off reflection proof.

Actual pinned engine: 4.7.2.stable.official.ed1daf0bf. Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_trophy_wall_reflections.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-visual-pass-2026-10-13/compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_trophy_wall_reflections.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/trophy-visual-pass-2026-10-13/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-visual-pass-2026-10-13/transition'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-visual-pass-2026-10-13/floor-deck'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Final results: Import passes; trophy/reference/layout/reflection proof **32 Compatibility + 32 desktop Mobile/Vulkan**, car-transition/retained-zoom/trophy-camera return **23**, floor/deck reflection lifecycle and pixel proof **25**: **112 checks, zero failures**. Existing assertions retained. Stone on/off region changes **31,990 Compatibility / 41,012 Mobile pixels**; floor/deck fixture reports **25,647 / 14,554** changed pixels. These pixel counts establish visible contributions, not quality or performance scores. Final trophy captures at four sizes and renderer comparisons were inspected. Native scene illumination can still differ between renderers; no pixel-identical renderer claim.

[Final Mobile trophy view at 1720](evidence/trophy-visual-pass-2026-10-13/mobile/trophy-wall-1720.png), [Compatibility at 1280](evidence/trophy-visual-pass-2026-10-13/compatibility/trophy-wall.png), [small window Mobile](evidence/trophy-visual-pass-2026-10-13/mobile/trophy-wall-960.png). Normal garage/car views, on/off stone and existing floor/deck proof are in the same evidence folder. Raised lettering was initially too dark and was adjusted before final captures; long edging speckle was removed after large-window review.

Source geometry for the lettering follows official [TextMesh documentation](https://docs.godotengine.org/en/stable/classes/class_textmesh.html); font size is bounded at 48 and the mesh is prepared once in the existing cache. No generated bitmap/reference media, external dependency, backend, ownership grant or canonical contract change. Runtime changes are confined to the trophy presentation; optional manual washing, local dirt/paint, retained zoom, fixed room/platform and car confirmation remain.

Baseline snapshots, actual logs and scoped patch/ledger: `docs/evidence/trophy-visual-pass-2026-10-13`. Reviewable two-commit Git checkpoint: `build/trophy-visual-pass/checkpoint-repo`; main branch/index and unrelated edits preserved.

Doctor found an attached OnePlus DN2103. No phone visual/performance test was performed; no APK export/install, benchmark, full Validate, physics regression/merge, backend operation or deployment. No added live view or light; lettering/rounded stems do change prepared geometry, so no claim of equal total triangle cost. Remaining acceptance: owner review of crest/gold/lighting/stone toward AAA and actual-device brightness, antialiasing and frame pacing. Trophy spaces intentionally remain empty until earned-award integration.
