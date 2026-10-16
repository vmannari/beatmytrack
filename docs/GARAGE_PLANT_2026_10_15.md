# Garage plant model refinement — 2026-10-15

Requirements GPL01–GPL03 / GC26 / V06 / G01 / R01 / Q01: replace the owner's rejected Garage plant with a more believable, carefully finished native model. AAA is the requested art target; subjective owner and physical-phone acceptance remain open.

The former square block planter and nineteen narrow blades are replaced by an original rubber-fig interpretation: three unequal curved leaders, twenty-five broad leaves attached by petioles, three small terminal leaves, pointed ends, asymmetric camber/twist, real tapered thickness, darker undersides and filtered midrib/secondary-vein shading. The turned stoneware planter has a recessed foot, rounded shoulder/lip, actual inner wall, recessed soil and seated bark/mineral chips. A soft existing contact shader grounds the pot. Existing room lighting and reflection views render the prop at its original `(-9.55, 0, -2.1)` position.

All geometry and shaders are original code-authored work; no imported/generated images, external asset licenses, AI services or dependencies. No camera, car, cosmetics, washing, LP, canonical driving, backend or contract changes belong to this slice. Concurrent menu rendering changes are preserved.

Runtime files: `game/ui/garage_workshop.gd`, `garage_plant.gd`, `garage_plant_leaf.gdshader`, `garage_plant_ceramic.gdshader` (the latter three under `game/ui/`). Verification: `game/tests/capture_garage_plant.gd`, `test_garage_plant.gd`, `test_garage_plant_baseline_reflections.gd`, their generated UIDs, this report, and the GPL entries in `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

The whole prop uses **14,737 triangles**, five shared opaque mesh/material groups, plus one existing contact-shader plane. Its local extent is approximately 1.00 × 2.13 × 1.06 m. The leaf mesh contains 10,192 triangles. Static resources prepare once and join the existing packed architecture/material batches; repeated showrooms reuse the original resources. There are no plant frame callbacks, textures, alpha foliage layers, additional lights or viewports. This deliberately adds geometry and material groups over the old prop; no phone-memory, GPU-time or FPS improvement is claimed.

Native evidence:

- [Original plant, Compatibility](evidence/garage-plant-2026-10-15/before/gl_compatibility/plant-front.png)
- [Final plant, Compatibility](evidence/garage-plant-2026-10-15/final/gl_compatibility/plant-front.png)
- [Final plant, Mobile Vulkan](evidence/garage-plant-2026-10-15/final/mobile/plant-front.png)
- [Leaf inspection](evidence/garage-plant-2026-10-15/final/gl_compatibility/leaf-detail.png), [planter inspection](evidence/garage-plant-2026-10-15/final/gl_compatibility/planter-detail.png), [normal trophy view](evidence/garage-plant-2026-10-15/final/mobile/trophy-view.png)

Final native captures also include reverse and normal Garage views on both renderers. These are actual Godot viewport captures, with isolated local preferences. Inspection views temporarily move only the test camera.

Actual verification on pinned `4.7.2.stable.official.ed1daf0bf`:

| Check | Outcome |
| --- | --- |
| Plant geometry/resources | 34 checks, zero failures; finite unit normals/UVs, correct winding, zero degenerate faces, bounded extent, shared resources, upward soil-chip normals |
| Final native plant captures | Compatibility 9 / Mobile Vulkan 9 checks, zero failures |
| Existing full-app car transitions | Compatibility 23 / Mobile Vulkan 23 checks, zero failures; actual camera, local condition, replacements and trophy return |
| All project GDScript compilation | 773 scripts, zero failures at final run |
| Existing reflection suite | Both renderers: 25 checks, **one failure each**, reproduced with the original plant |

The reflection failure is `visible garage resumes live reflections`: the historical test requires `UPDATE_ALWAYS`, while current `GarageReflections.request_draw()` uses `UPDATE_ONCE` and the current showroom requests draws on changes. The unchanged test has the same failure with only the old plant builder restored **inside its process**, without editing runtime files or weakening assertions. Baseline and final reflection pixel counts are identical: Compatibility deck 14,129 / floor 25,344; Mobile deck 14,013 / floor 25,343. The other 24 assertions, including visible native reflection pixels, shared worlds, caps, face winding, car rotation/replacement and hidden cleanup, pass. This is not reported as a clean reflection-suite pass.

Retained initial work includes the first coarse planter finish and red stem tint, corrected before final captures; geometry diagnostics initially found 21,041 triangles, inverted leaf pole faces and 256 collapsed lathe faces. Lower leaf tessellation, tapered end thickness and omitted pole triangles corrected those findings without relaxing the checks. Soil-chip outward normals were corrected in the final pass. An initial restricted Godot launch failed certificate-store access; native runs used approved normal startup access. An optional Python image-comparison attempt lacked Pillow and produced no pixel-equivalence result; none is claimed.

Commands actually run, with per-run `APPDATA` directories beneath `build/garage-plant-2026-10-15/` and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` as the common launcher:

```powershell
-Action TestScript -ScriptPath res://tests/test_garage_plant.gd -CommandTimeoutSeconds 90
-Action TestScript -ScriptPath res://tests/capture_garage_plant.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/final/gl_compatibility' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/capture_garage_plant.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/final/mobile' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/reflections/gl_compatibility' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/reflections/mobile' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_plant_baseline_reflections.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/baseline-reflections/gl_compatibility' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_plant_baseline_reflections.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/baseline-reflections/mobile' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/transition/gl_compatibility' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-plant-2026-10-15/transition/mobile' -CommandTimeoutSeconds 120
-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
```

The native capture script was also run before replacement and during refinement with evidence roots `before/gl_compatibility` and `initial/gl_compatibility`. Logs, original source, hashes and a task-only patch are under `docs/evidence/garage-plant-2026-10-15/`. The isolated Git checkpoint is `build/garage-plant-2026-10-15/checkpoint-final`; the task does not stage or commit the shared main index. The initial checkpoint attempt treated CRLF as trailing whitespace; the final isolated checkpoint normalizes its text copies to LF without changing workspace line endings.

No physical-phone test, device interaction, APK/export/install, backend action, deployment, general performance benchmark or full Validate was performed. Remaining acceptance is the owner's appearance review, in-motion leaf readability and physical-phone brightness/aliasing/performance.
