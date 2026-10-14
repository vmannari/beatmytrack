# Winter road reflections — 2026-10-12

Owner request: try subtle reflections on the Winter road. This is a local presentation change; owner visual acceptance and physical-device performance acceptance remain open.

## Requirements and files

- WE38: `game/track/winter_reflection_sky.gdshader` adds an original static blue sky with broad soft cloud shapes. `game/track/track_theme.gd` uses it only for Winter reflections, retaining the 128px radiance map, solid background, existing ambient colour/energy, sunlight and fog. Quality processing builds a static map; no TIME, live probes, scene captures or external art.
- WE39: `game/track/winter_ice.gdshaderinc` supplies a common ground/deck finish response. Exposed ice is glossier, while the existing packed abrasion channel and white edge frost increase roughness and reduce specular strength. `creator_road.gdshaderinc` and `bridge_road.gdshaderinc` use that helper. Existing blue pigment, artwork, pale scuffs, normals, footprints and canonical simulation are retained. The sky can also reflect on existing glossy car materials.
- V04/V05/G01/R01: no camera, handling, surface, scoring, collision, snowbank, terrain, particle or car-condition contract changes. `native_track_visual.gd` advances presentation kit166→167 so cached materials are rebuilt. No new road texture samples, geometry or draw calls.
- Q01: `game/tests/test_winter_environment.gd` accepts an evidence output directory and an optional actual-render reflection test. It disables/re-enables the reflection source with fixed scene/camera, verifies a visible contribution and exact restoration within the stated pixel tolerance. Delivery records: this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

## Actual commands and results

All engine runs use pinned Godot 4.7.2 through `scripts/dev.ps1`. PowerShell is launched with `-NoProfile -ExecutionPolicy Bypass`; multiple TestArgument values are passed through `-Command "& './scripts/dev.ps1' ... -TestArgument @(...)"`. Graphical tests require normal Windows graphics/log access. Desktop GPU: RTX3090.

| Arguments after scripts/dev.ps1 | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/capture_winter.gd -Graphical -TestArgument @('--output-dir=res://../docs/evidence/winter-reflections-2026-10-12/before')` | Before capture:168 checks,0 failures |
| Same capture with `@('--ice-scuff-preview','--output-dir=res://../docs/evidence/winter-reflections-2026-10-12/after')` | Final Compatibility:170 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--video','--reflection-proof','--output-dir=res://../docs/evidence/winter-reflections-2026-10-12/compatibility')` |104 checks,0 failures;155481 changed pixels;0 unstable pixels;314 draws/402255 primitives |
| Same environment script with `-RenderingMethod mobile -TestArgument @('--capture','--fresh-roads','--bank-detail','--video','--output-dir=res://../docs/evidence/winter-reflections-2026-10-12/mobile')` |101 checks,0 failures;330 draws/402255 primitives; actual driving preview |
| Same Mobile script with `@('--capture','--fresh-roads','--reflection-proof','--output-dir=res://../docs/evidence/winter-reflections-2026-10-12/mobile-proof')` |103 checks,0 failures;183138 changed pixels;0 unstable pixels |
| `-Action TestScript -ScriptPath res://tests/capture_winter_bridge.gd -Graphical -TestArgument @('--fresh-roads','--approaches')` |Exit0;four bridge views saved;collision-cell preservation assertion passed |
| `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--4k','--seconds=5','--modes=full','--profile-dir=res://../docs/evidence/winter-reflections-2026-10-12/performance')` |3840×2160,600 driving ticks;frame median3.350ms/p955.594ms/max8.048ms;0 frames over16.667ms;GPU median2.402ms/p953.024ms |
| `-Action Doctor` with normal Windows access |Pinned engine/templates found;attached DN2103 device |
| `-Action Import` with normal Windows access |Exit0;engine scan/import completed |

Initial restricted graphical launch could not open Godot user logs; normal-access rerun passed. An initial comma-joined native PowerShell TestArgument attempt passed168 checks but did not select the requested capture directory; corrected array invocation produced the final170-check capture. Initial restricted Doctor could not access ADB configuration; normal-access rerun found the phone. No failed assertions were weakened.

## Evidence and limitations

- [Before bend](evidence/winter-reflections-2026-10-12/before/frost/bend-detail.png), [after bend](evidence/winter-reflections-2026-10-12/after/frost/bend-detail.png), [enabled reflection](evidence/winter-reflections-2026-10-12/compatibility/reflection-enabled.png), [disabled reflection](evidence/winter-reflections-2026-10-12/compatibility/reflection-disabled.png).
- [Compatibility driving motion](evidence/winter-reflections-2026-10-12/compatibility/driving-motion.html), [Mobile driving motion](evidence/winter-reflections-2026-10-12/mobile/driving-motion.html). These retain actual sequential Godot render frames. Captures were visually inspected; the sheen is restrained, and the blue road/white scraping remain readable. Desktop renderers retain their existing different overall colour/lighting response; identical renderer output is not claimed.
- Reflections represent the static sky, not moving cars or nearby props. The pixel restoration tolerance is summed RGB difference≤0.015. The changed-pixel count measures the actual scene contribution, not a road-only mask.
- The five-second desktop profile is a whole-scene sample, not a before/after cost comparison or a phone benchmark. No Android export/install, physical-device visual/performance/thermal test, full Validate, physics regression, backend change/deployment or live competitive write was performed. A phone is attached but was not tested.
- Review the road in normal driving on the owner's device. Adjust strength only after that review. Task-only isolated Git checkpoint and source patch are under `build/winter_reflections`; the shared index/branch remain unchanged.

## Owner-authorized phone deployment

Following the owner's explicit request to deploy to phone, ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG` with normal Windows build/ADB access. Import/startup passed; driving72/catalog21/menu48 checks passed. Fresh Android Debug export completed with the pinned engine/templates; `adb install -r` returned Success and launch returned Status:ok, COLD,983ms. APK: `build/android/circuit01-debug.apk`; actual logs: `build/logs/DeployAndroid-2456/`. This deploys the current workspace build. Physical-phone visual/performance acceptance and full regression remain unperformed; desktop evidence above remains separate. No backend deployment.
