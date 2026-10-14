# Frosted ice road and softer glints — 2026-10-13

WE43: owner asks for slightly weaker reflections and a more convincing icy/snowy road instead of the current blue. This supersedes the earlier blue pigment strength. Owner appearance/device acceptance remains open.

Changed files: `game/track/winter_ice.gdshaderinc` changes base pigment from `(0.40,0.51,0.63)` to paler cool grey `(0.50,0.56,0.60)`, retaining original texture with slightly stronger luminance detail. Seam radiance blend0.85→0.72 (about15% reduction in that blend, not a measured15% pixel-brightness reduction). `game/track/surface_detail.gdshaderinc` increases white fine-crystal detail0.35→0.55, strengthens broken powder coverage0.045→0.20 with a broader existing-noise threshold, and neutralizes the blue tint of powder/older frosted wheel paths. `game/track/native_track_visual.gd` kit175→176 invalidates presentation caches. Existing seam mask and slopes remain; ground/deck ice share the helpers. Delivery records: this file,`DEVELOPMENT_STATUS.md`,`docs/PHASE_0_PLAN.md`.

V04/V05/G01/R01: no new texture samples,draws,geometry,lighting,camera,handling,collision,scoring or local-car-condition change. Existing white scuffs/banks and thin reflective seams retained. No runtime generation or new assets.

Concurrent Desert shoulder/texture work in the shared files is preserved and excluded from this task's isolated checkpoint. The APK builds the current workspace.

## Actual commands and checks

Pinned Godot4.7.2 through `scripts/dev.ps1`,normal Windows graphics/log access,PowerShell NoProfile/ExecutionPolicy Bypass. Multiple TestArgument values passed as arrays using PowerShell Command. Desktop GPU:RTX3090.

| Arguments after scripts/dev.ps1 | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--seam-proof','--video','--output-dir=res://../docs/evidence/winter-frosted-road-2026-10-13/compatibility')` |106 checks,0 failures;46296 seam-contribution pixels,0 unstable;33859 mask pixels;314 draws/402255 primitives |
| Same script with `-RenderingMethod mobile -TestArgument @('--capture','--fresh-roads','--seam-proof','--output-dir=res://../docs/evidence/winter-frosted-road-2026-10-13/mobile')` |105 checks,0 failures;33358 contribution pixels,0 unstable;330 draws/402255 primitives |
| `-Action TestScript -ScriptPath res://tests/capture_winter.gd -Graphical -TestArgument @('--ice-scuff-preview','--output-dir=res://../docs/evidence/winter-frosted-road-2026-10-13/scuffs')` |170 checks,0 failures |
| `-Action Doctor` |Pinned engine/templates found;DN2103 attached |

Total381 scoped checks pass. An optional Python/Pillow texture-statistics inspection could not run because the default Python lacks Pillow;no dependency installed. Existing texture and actual render captures were inspected directly instead.

[Road close view](evidence/winter-frosted-road-2026-10-13/compatibility/seams-enabled.png),[normal driving](evidence/winter-frosted-road-2026-10-13/compatibility/driving.png),[actual motion](evidence/winter-frosted-road-2026-10-13/compatibility/driving-motion.html). Captures inspected:less saturated road colour,whiter broken frost/fine scraping,localized softer glints;road remains distinct from surrounding snow. Renderers retain their existing overall lighting difference;identical output is not claimed.

No fresh frame-time benchmark,full Validate,physics regression,physical-device race/thermal/performance acceptance or backend deployment/live competitive write. Owner should review the new ice/snow balance in ordinary phone driving. Task-only isolated Git checkpoint/source patch:`build/winter_frosted_road_2026_10_13`;main Git index/branch retained.

## Phone build and installation status

Ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`. Import/startup passed;driving72/catalog21/menus48 checks passed. Fresh Android Debug export completed and replaced `build/android/circuit01-debug.apk`. Phone disappeared before install;script exited1 at device selection. Follow-up `-Action Doctor` initially listed no devices. Actual deployment logs:`build/logs/DeployAndroid-23040/`. Asked owner to reconnect/unlock phone;later Doctor found it authorized again.

Then ran `-Action InstallAndroid -DeviceSerial PRQKU4U4PREQNRWG`:Success,exit0 (`build/logs/InstallAndroid-32624/`),followed by `-Action LaunchAndroid -DeviceSerial PRQKU4U4PREQNRWG`:Status:ok,exit0,WaitTime3040ms (`build/logs/LaunchAndroid-39724/`). Revised build is installed and launched. Physical-device appearance/performance acceptance remains open.
