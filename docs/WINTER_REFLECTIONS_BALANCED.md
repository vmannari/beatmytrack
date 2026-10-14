# Reduced Winter reflections — 2026-10-12

WE41: owner rejects the stronger phone pass as excessive. This revision reduces cloud brightness2.20→1.05 and blend1.0→0.70, exposed-ice specular1.0→0.82, shallow cosmetic normal slope0.075→0.045; roughness floor0.09→0.13 and scrape damping0.25→0.45 soften highlights. Frost response, blue pigment, white scuffs, camera, handling, collision and scoring remain unchanged (V04/V05/G01/R01). Reflections remain static sky-only.

Changed files: `game/track/winter_ice.gdshaderinc`, `winter_reflection_sky.gdshader`, `surface_detail.gdshaderinc`, `native_track_visual.gd` (kit172→173), this document and the two delivery records. Concurrent unrelated kit172 work is preserved and excluded from the review checkpoint.

Actual pinned Godot4.7.2 command: `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--reflection-proof','--output-dir=res://../docs/evidence/winter-reflections-balanced-2026-10-12')`, launched via PowerShell NoProfile/ExecutionPolicy Bypass with normal graphics/log access. Compatibility103 checks,0 failures;184278 contribution pixels,0 unstable pixels;314 draws/402255 primitives. [Inspected final capture](evidence/winter-reflections-balanced-2026-10-12/reflection-enabled.png). Highlights are much softer than the previous strong pass. No fresh Mobile Vulkan test, frame-time benchmark, full regression or physical-device race/performance acceptance is claimed.

Owner/device appearance acceptance remains open. Task-only isolated Git checkpoint and source patch: `build/winter_reflections_balanced`. No backend deployment or competitive writes.

Phone update: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`. Import/startup passed;driving72/catalog21/menus48 checks passed. Fresh Android export succeeded,install Success,launch Status:ok,COLD,933ms. Logs:`build/logs/DeployAndroid-40676/`;APK:`build/android/circuit01-debug.apk`. Current workspace installed;physical-device visual/performance acceptance remains open.
