# More apparent Winter reflections — 2026-10-12

Owner feedback: the first phone build's reflections were not noticeable. WE40 supersedes that restrained strength. Owner/device visual acceptance remains open.

## Changes

- `game/track/winter_ice.gdshaderinc`: exposed-ice roughness now0.09–0.28 before abrasion; stronger dielectric specular1.0 before abrasion; packed scrape damping0.65→0.25. White edge frost retains roughness0.86/specular0.22. Ground roads and bridge decks share the helper.
- `game/track/winter_reflection_sky.gdshader`: stronger contrast between blue sky and broad white cloud reflections. Changes cloud direction frequencies and bright-cloud energy; keeps static128px radiance, no TIME/live capture/new road texture samples. An intermediate brighter-blue pass was reviewed and replaced because it mostly brightened the road uniformly.
- `game/track/surface_detail.gdshaderinc`: shared ground/deck ice normals add shallow world-continuous undulations (0.075 slope per axis), making sky reflection vary visibly across the overhead view. Geometry and collision remain flat/canonical; snow terrain normals are unaffected.
- `game/track/native_track_visual.gd`: presentation kit169→170 invalidates existing caches. Concurrent unrelated Desert work subsequently advanced the shared version to171; those Desert edits are preserved and excluded from the task-only checkpoint.
- V04/V05/G01/R01/Q01: current blue pigment, white scrapes, camera, handling/scoring, contact geometry and local cosmetic condition retained. Delivery records: this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. Task-only checkpoint under `build/winter_reflections_stronger`.

## Actual verification

Pinned Godot4.7.2 through `scripts/dev.ps1`, RTX3090 desktop. Commands launched through PowerShell `-NoProfile -ExecutionPolicy Bypass -Command` with separate TestArgument array elements and normal Windows graphics/log access.

- `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--video','--reflection-proof','--output-dir=res://../docs/evidence/winter-reflections-stronger-2026-10-12/final')`:104 checks,0 failures;330368 reflection-contribution pixels,0 unstable pixels;314 draws/402255 primitives; actual driving frames retained.
- Same script with `-RenderingMethod mobile -TestArgument @('--capture','--fresh-roads','--reflection-proof','--output-dir=res://../docs/evidence/winter-reflections-stronger-2026-10-12/final-mobile')`:103 checks,0 failures;382801 contribution pixels,0 unstable pixels;330 draws/402255 primitives.
- Intermediate brighter pass:Compatibility104/Mobile103 checks,0 failures; captures retained under `compatibility`/`mobile`. These are not the final shipped look.
- [Final reflection](evidence/winter-reflections-stronger-2026-10-12/final/reflection-enabled.png), [disabled reflection](evidence/winter-reflections-stronger-2026-10-12/final/reflection-disabled.png), [actual driving motion](evidence/winter-reflections-stronger-2026-10-12/final/driving-motion.html). Final stills visually inspected: distinct pale reflected patches cross the blue ice; fine scraping remains visible. The reflection remains sky-only, not a reflection of cars/props.

No new desktop frame-time benchmark or physical-device race/performance/thermal acceptance was performed for this revision. Desktop Mobile Vulkan is not a device test. Full regression, backend deployment and live competitive writes are outside this cosmetic revision.

## Phone update

Ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG` under the existing phone-deployment authorization. Import/startup passed;driving72/catalog21/menus48 checks passed. Fresh Android Debug export succeeded;install returned Success;launch Status:ok,COLD,1067ms. APK:`build/android/circuit01-debug.apk`;logs:`build/logs/DeployAndroid-27128/`. The current workspace build is installed. Owner driving review remains required to accept the stronger reflection appearance.
