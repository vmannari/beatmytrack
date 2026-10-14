# Winter crack/seam glints — 2026-10-12

The owner clarifies that reflections should follow cracks and seams, then reports no change. The preceding acknowledgement did not edit files. This delivery implements localized glints on the existing thin directional ridges in the ice artwork. Owner/device appearance acceptance remains open; this does not add a new network of large branching cracks.

## Requirements and changes

- WE42: `game/tests/bake_winter_seam_finish.gd` extracts elongated positive ridges from the original `winter_ice_v1.png`:25-pixel along-line average, six transverse neighbours, bounded smooth threshold. It retains the previous packed RG slopes/B frost byte-for-byte and writes the seam mask into A of original derived512px `game/assets/textures/winter_ice_seam_finish_v4.png`.13% of pixels have mask>0.5. This is an offline numerical bake; no runtime image loading/generation or external art. Original source/provenance is retained.
- `winter_ice_seam_finish_v4.png.import`:lossless numeric data,mipmaps,512px cap,no alpha-border repair or premultiplication (A is data, not transparency).
- `game/track/winter_ice.gdshaderinc`:surrounding ice roughness0.88/specular0.08;seam facets approach roughness0.12/specular1.0. Frost suppresses glints. A seam-only reflected-radiance helper evaluates the existing static sky directions with higher contrast at the facets, leaving pigment unchanged. This uses Godot's reflected-light output, without emission. [Godot RADIANCE reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
- `game/track/creator_road.gdshaderinc` and `bridge_road.gdshaderinc`:apply the same seam radiance on ground/deck ice only. `game/track/surface_detail.gdshaderinc`:removes the broad sinusoidal normal undulations from the earlier cloud-reflection pass;original road-aligned slopes retained.
- `game/track/native_track_visual.gd`:uses new packed map;kit174→175 invalidates presentation caches. Concurrent earlier kit174 changes preserved. No new road texture samples, geometry, draw calls or canonical contract changes (V04/V05/G01/R01). Blue pigment,pale tire scrapes,snowbanks,camera,handling/scoring/local condition retained.
- Q01:`game/tests/test_winter_environment.gd` adds seam-only actual-render toggle,checks exact packed RGB preservation,bounded mask coverage,visible seam contribution and paused restoration. Existing assertions retained. Records:this document,`DEVELOPMENT_STATUS.md`,`docs/PHASE_0_PLAN.md`.

## Actual verification

Pinned Godot4.7.2 through `scripts/dev.ps1`,normal Windows graphics/log access,PowerShell NoProfile/ExecutionPolicy Bypass. Multiple TestArgument values passed as an array via PowerShell Command. GPU:RTX3090 desktop.

| Arguments after scripts/dev.ps1 | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_winter_seam_finish.gd` |Final bake:mask>0.5 coverage0.12953949/mean0.13697913;offline source-image loading warnings expected (tool is not a shipping runtime path) |
| `-Action Import` |Exit0,new packed texture imported |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--seam-proof','--video','--output-dir=res://../docs/evidence/winter-seam-reflections-2026-10-12/final')` |Compatibility106 checks,0 failures;52923 seam-contribution pixels,0 unstable;33859 active mask pixels;314 draws/402255 primitives |
| Same script with `-RenderingMethod mobile -TestArgument @('--capture','--fresh-roads','--seam-proof','--output-dir=res://../docs/evidence/winter-seam-reflections-2026-10-12/mobile')` |Mobile Vulkan105 checks,0 failures;36171 seam-contribution pixels,0 unstable;330 draws/402255 primitives |
| `-Action TestScript -ScriptPath res://tests/capture_winter.gd -Graphical -TestArgument @('--ice-scuff-preview','--output-dir=res://../docs/evidence/winter-seam-reflections-2026-10-12/scuffs')` |170 checks,0 failures;actual pale scuffs/contact presentation retained |
| `-Action TestScript -ScriptPath res://tests/capture_winter_bridge.gd -Graphical -TestArgument @('--fresh-roads','--approaches','--output-dir=res://../docs/evidence/winter-seam-reflections-2026-10-12/bridges')` |Exit0;four actual bridge views;canonical collision-cell assertion passed |

An intermediate mask-only pass passed106 checks but remained visually faint;the final seam-radiance helper improves visible line highlights. Its captures are separately retained under `compatibility`. Initial mask coverage23% was narrowed to13% before final verification. Concurrent kit-version changes caused initial patch matching to fail;current shared version was read before successful edits.

## Evidence and limits

[Seams enabled](evidence/winter-seam-reflections-2026-10-12/final/seams-enabled.png),[seams disabled](evidence/winter-seam-reflections-2026-10-12/final/seams-disabled.png),[Mobile](evidence/winter-seam-reflections-2026-10-12/mobile/seams-enabled.png),[actual driving motion](evidence/winter-seam-reflections-2026-10-12/final/driving-motion.html). Final captures visually inspected:thin bright lines follow original texture direction,broad blue ice remains quiet. Test changes only the seam-strength uniform;the sky,camera and diffuse artwork stay fixed. Paused tolerance:sum RGB difference≤0.015.

Static sky reflection only;no moving-car/prop reflections. No new frame-time benchmark,physical-device race/performance/thermal acceptance,full regression or backend deployment/live competitive write. Desktop Mobile Vulkan is not a device test. Owner should review these thin glints in ordinary phone driving. Task-only isolated Git checkpoint/source patch under `build/winter_seam_reflections`;shared Git index/branch remain unchanged.

## Phone update

Existing phone-deployment authorization: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`. Import/startup passed;driving72/catalog21/menus48 checks passed. Fresh Android Debug export succeeded;install Success;launch Status:ok,COLD,940ms. Actual logs:`build/logs/DeployAndroid-18144/`;APK:`build/android/circuit01-debug.apk`. Current workspace installed. This is deployment evidence;owner's physical-device appearance/performance acceptance remains open.
