# Garage car selection: retained zoom and dissolve

Owner request, 2026-10-12. GC20: selecting a car retains zoom. GC21: disappear/appear effect for vehicle changes. Preserve GC06–GC19/CW13/CW15/CW16/V06/G01/R01/Q01.

Previously car previews deleted the entire showroom, restoring its default zoom/tilt/rotation. Garage now replaces only the actual car and its correctly sized pedestal inside the existing viewport/world. The showroom, garage architecture and camera persist. The camera's base distance is retained as well as zoom, tilt and turntable yaw, so switching differently sized cars does not silently reframe the room. Select car confirms the current preview without restarting its effect or resetting the view. Explicit Reset still fits the currently displayed car. A larger car can occupy more screen space at the retained camera position; the existing zoom controls remain available.

Vehicle changes dissolve the outgoing model over 0.18s, exchange at disappearance, then reveal the incoming model over 0.24s. This uses an original opaque ordered pixel dissolve, preserving depth and avoiding transparent body/glass sorting. Contact shadows participate; the garage and camera do not fade. Shader finishes retain their original code and parameters in temporary material copies; standard surfaces carry their base colour, roughness, metal/specular/emission and vertex-colour properties during the brief effect. Original material references are restored on completion/cancellation. No gameplay mesh, shader, handling, collision, PB, score or reward contract is modified.

Rapid previews cancel the prior effect and retain only the latest car. Outgoing pedestals and their contact geometry are released together. Starting washing or changing paint settles the incoming car before interaction; trophy navigation and page hiding also settle the effect. Local per-car dirt and paint remain separate, car preview remains unconfirmed until Select car, and carousel thumbnails keep their existing materials and one-shot renders.

Changed files: `game/ui/garage_page.gd`, `car_showroom.gd`, `garage_environment.gd`. Added `game/ui/garage_car_reveal.gd` (+UID), `game/tests/test_garage_car_transition.gd` (+UID), this document. Updated `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands on pinned `4.7.2.stable.official.ed1daf0bf`, isolated local test records:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -TestArgument '--capture-motion'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-car-transition-2026-10-12/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/garage-car-transition-2026-10-12'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-car-transition-2026-10-12/mobile/carousel'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/encode_garage_car_motion.py
python build/checkpoint_garage_car_transition.py
```

Final transition passes: Compatibility **143 checks including 120 actual rendered motion frames**, desktop Mobile/Vulkan **23**, zero failures. Tests cover actual camera equality after preview/confirmation, existing viewport/room identity, outgoing/incoming phases, cleanup, repeated rapid previews, last-car confirmation, unchanged thumbnail materials, per-car dirt, trophy-camera return, page hiding and explicit Reset. Existing carousel passes **175 checks on each renderer**, view controls **59**, manual washing/local condition **1,402**; zero failures. Import passes. Initial attempted `Material.get_shader_rid` access was unavailable in the pinned engine; that approach was removed and replaced with native authored shader copies. An initial timing check hit the exact floating-point segment boundary, and repeated pedestal names were auto-renamed; the fixture advances 1ms beyond the boundary and the outgoing pedestal now has an explicit separate name. Original invariants remain intact.

Evidence: [before](evidence/garage-car-transition-2026-10-12/before-switch.png), [disappearing](evidence/garage-car-transition-2026-10-12/disappearing.png), [empty pedestal](evidence/garage-car-transition-2026-10-12/empty-pedestal.png), [appearing](evidence/garage-car-transition-2026-10-12/appearing.png), [motion](evidence/garage-car-transition-2026-10-12/car-transition-motion.png), matching Mobile stills and existing three-width carousel captures. The 960x540 lossless APNG contains 120 actual Godot renders, with the production tween stepped at 1/30s for deterministic review capture; its four-second playback is not a performance measurement. Python stdlib assembly verifies each source PNG's CRC and format. Raw frames are in `build/garage-car-motion-2026-10-12`; animation is approximately 43MB.

Task-only two-commit Git checkpoint: `build/garage_car_transition/checkpoint-repo`; baseline sources, scoped patch, hashes and actual logs: `docs/evidence/garage-car-transition-2026-10-12`. Main branch/index and concurrent unrelated changes are preserved. Godot's documented [ShaderMaterial](https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html) and [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) resources support the menu-only material handling; the actual pinned engine runs above establish behavior.

Doctor reported no attached Android device. No phone test, APK export/install, full Validate, physics merge/regression, backend operation or deployment was performed. Owner effect/style review and physical-device frame pacing/readability remain acceptance checks; no desktop result establishes AAA or phone acceptance.
