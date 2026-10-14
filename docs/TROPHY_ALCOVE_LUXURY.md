# Trophy alcove luxury finish ? 2026-10-13

Requirements GC27: correct decoration around the brand lettering; GC28: prestigious finish on both side returns, soffit, shelf and lower fascia; GC29: round refined gallery fixtures. Preserve GC15?GC26, local cosmetics and canonical handling/scoring. AAA remains a visual-quality acceptance target.

Runtime changes: `game/ui/garage_details.gd` reshapes the laurel into symmetric elliptical branches with open top, continuous stems and narrower tangent-oriented paired leaves; positions the lettering inside the wreath; uses brushed champagne metal edging and round five-layer cylindrical light housings with recessed warm circular lenses. Six award bases remain empty. `game/ui/garage_display_stone.gdshader` (+UID) is an original opaque dark mineral finish with soft cloud variation and antialiased irregular warm veins, dielectric satin reflectance; applied to side returns, top, bottom shelf and fascia. No texture assets, external dependencies or generated reference media. Existing batching/cache, light count, showroom/reflections and car transitions retained.

Actual commands using pinned Godot 4.7.2:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_reference.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-luxury-2026-10-13/compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_reference.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/trophy-luxury-2026-10-13/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-luxury-2026-10-13/transition'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Import passes. Final Compatibility25 + desktop Mobile/Vulkan25 layout/capture checks, transition23: 73 checks, zero failures. Four window sizes/all five cars/empty six slots/side-wall location and clean local state covered. Final trophy captures inspected on both renderers. Initial regular stone stripes were replaced with quieter distorted veins before final reruns. No assertion weakened. Mobile's reflected stone response is visibly brighter than Compatibility; both captures are provided for owner acceptance rather than claimed pixel equality.

[Compatibility trophy wall](evidence/trophy-luxury-2026-10-13/compatibility/trophy-wall.png), [Mobile trophy wall](evidence/trophy-luxury-2026-10-13/mobile/trophy-wall.png). Baseline source in evidence/before. Scoped two-commit Git checkpoint: `build/trophy-luxury-checkpoint`, main index/unrelated work preserved.

Doctor detected a OnePlus DN2103. No physical-device visual or performance test was performed for this change; no APK export/install, full Validate, backend/deployment or physics change. Remaining: owner wreath/material/fixture acceptance toward AAA, actual phone brightness and stable frame pacing, future earned-award population. No new trophy ownership or grants.
