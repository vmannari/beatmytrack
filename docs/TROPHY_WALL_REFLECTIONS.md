# Trophy stone wall reflections ? 2026-10-13

GWR01: owner requests some reflections on the trophy alcove walls. Preserve GC27?GC29/GRD01?GRD03/V06/G01/R01/Q01.

Changed `game/ui/garage_display_stone.gdshader`: polished dielectric roughness 0.18?0.25, native environment radiance and bounded angle-dependent analytic reflections of the three round alcove lights and three actual ceiling strips. World position/normal and live camera determine highlights. Existing stone/veins remain. No extra viewport, texture sampling, scene capture, external dependency or canonical change. This is lighting reflection, not a live car/workshop mirror; floor and deck retain their existing planar scene captures. No additional draw or geometry. Incremental GPU cost was not benchmarked.

Added `game/tests/capture_trophy_wall_reflections.gd` (+UID), derived from the established reference fixture, adding material discovery and on/off pixel evidence.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_trophy_wall_reflections.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/trophy-wall-reflections-2026-10-13/gl_compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_trophy_wall_reflections.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/trophy-wall-reflections-2026-10-13/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Pinned 4.7.2 Import passes. Final Compatibility28 + Mobile/Vulkan28 checks, zero failures. On/off changed pixels in the alcove region: 54,231 / 38,010 respectively; comparison includes native radiance/specular change and analytic highlights, not solely the light silhouettes. Four screen sizes/all five cars/empty award spaces/local cosmetic state covered. First proof missed batched meshes because it searched only the wall hierarchy; corrected discovery to prepared room active materials, no weakened assertion.

[Compatibility](evidence/trophy-wall-reflections-2026-10-13/gl_compatibility/trophy-wall.png), [Mobile](evidence/trophy-wall-reflections-2026-10-13/mobile/trophy-wall.png), paired off views in the same folders. Captures inspected. Baseline shader in evidence/before. Scoped two-commit Git checkpoint `build/trophy-wall-reflections-checkpoint`; main index and concurrent work retained.

Doctor detects DN2103. No phone test/export/install, performance benchmark, full regression, backend action or deployment. Owner sheen/readability acceptance and physical-device appearance/frame pacing remain open.
