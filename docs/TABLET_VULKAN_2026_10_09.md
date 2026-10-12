# Android Mobile/Vulkan trial - 2026-10-09

Requirements V03/V04/V05/Q01/R01. Owner explicitly requests trying Vulkan Mobile after unsatisfactory tablet shadows and dust/bridge leakage. Android/mobile rendering override now selects Mobile; desktop remains Compatibility. Vulkan is Godot's Android RenderingDevice default, verified from the [ProjectSettings documentation](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-driver-android). The existing world1.5MP budget, MSAA2x, HUD, camera, dust and shadows remain matched for the first comparison; no canonical simulation or player-data change.

Pinned4.7.2 engine/templates. Actual desktop Mobile/Vulkan scene boot prints Vulkan1.4.351/ForwardMobile/RTX3090, no shader errors and zero frozen material/state witness failures. Camera1499 checks pass both headless and actual graphical Mobile/Vulkan. These PC checks do not establish tablet performance or bridge leakage acceptance.

Tooling: scripts/dev.ps1 exposes validated renderer/driver overrides and inserts them before user-argument separators; game/diagnostics/mobile_race_probe.gd reports the actual driver as well as renderer; scripts/profile-tablet.ps1 can reject unintended fallback. The frozen capture supports an explicit output directory. An initial Vulkan capture used the old report directory; it was copied to this trial's desktop folder and the prior Compatibility witness was regenerated. No historical exact-image equality is claimed for that regenerated witness.

Before sources and a rollback APK are retained under build/tablet-vulkan-2026-10-09/. Native export/profile/install and final visual/performance acceptance are in progress. No runtime UI options, asset generation, backend or production deployment are introduced.

Native Vulkan trial installed Success and completed two desert driving stages: actual renderer mobile, driver vulkan, Adreno(TM)750, MSAA2x, shadows enabled, zero paused frames. Medians19.974/19.992ms, p9522.979/22.671ms versus prior Compatibility19.866/19.857ms and p9524.570/24.920ms on this fixture. Approximately50FPS median, modestly better tail, not a locked60FPS or same-pose visual parity claim. First image captured shader-loading and is not driving evidence; second shows smooth dust. Shader loading/cross-biome appearance need review.

Subsequent Pine drive was rejected before marker creation because secure keyguard showed. Owner unlock requested; no final native bridge-leakage acceptance yet. A debug-only bridge_review pose and unique readiness marker now support explicit under-deck screenshots after scene initialization; review-only reports are flagged visual_only and must not be compared as ordinary racing timings. No player-facing label or authored-track write.

## Installed trial and limits

Final debug APK **246,693,145 bytes**, SHA-256 **FAE29FF633629D62612EBC9E70177100796BDB48A7264372C941B1F7C0F158EC**. Finalized Vulkan trial installation succeeded and ordinary launch is restored. Earlier native desert measurements are the tested renderer build; the final packaging adds debug readiness/bridge-witness support and includes concurrently authorized workspace updates. Secure keyguard still prevents final foreground/bridge and Pine review. No bridge-leakage or shadow-quality fix is claimed from the renderer switch alone; the particle/bridge clipping issue remains acceptance work. Owner was asked to unlock the tablet. No diagnostic marker/player files were changed by the rejected Pine attempt.

[Native timing data](evidence/tablet-vulkan-2026-10-09/desert/results.json), [native driving view](evidence/tablet-vulkan-2026-10-09/desert/driving-1.png), [deployment metadata](evidence/tablet-vulkan-2026-10-09/final-installed/deployment.json). Vulkan first-launch shader loading was captured and retained separately; that image is not a driving/visual pass. Desktop Mobile/Vulkan camera1499 and frozen scene/state/material checks pass; final focused export import/startup/driving72/catalog21/menus48 passes. No full Validate/full replay/thermal soak/other-device acceptance. Canonical simulation/rules/camera/world budget remain unchanged.

## Actual commands and changed files

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_dust_depth_candidates.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--output=res://../docs/evidence/tablet-vulkan-2026-10-09/desktop' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCameraModes -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_camera_modes.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/dust_cloud.json -Seconds 18 -Features baseline,baseline -CaptureDriving -RequiredRenderer mobile -RequiredDriver vulkan -Output docs/evidence/tablet-vulkan-2026-10-09/desert -Install
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 -DeviceSerial f0ba474a -DocumentPath game/tests/fixtures/ajorata.json -Seconds 12 -Features baseline -CaptureDriving -RequiredRenderer mobile -RequiredDriver vulkan -Output docs/evidence/tablet-vulkan-2026-10-09/pine
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action InstallAndroid -DeviceSerial f0ba474a
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action LaunchAndroid -DeviceSerial f0ba474a
```

The TestCameraModes convenience action remained headless despite Graphical; actual GPU coverage comes from the following TestScript invocation, whose startup prints Vulkan/Forward Mobile. The Pine command failed the unlock precheck and is not a test pass. Renderer/driver arguments now precede the user-argument separator. Added bridge review is visual-only with physics disabled and is flagged in its reports, so its frame times must not be treated as ordinary racing performance.

Owned files: game/project.godot (Android/mobile renderer only), scripts/dev.ps1 (explicit test renderer/driver flags), game/diagnostics/mobile_race_probe.gd (driver reporting, debug bridge pose/readiness), scripts/profile-tablet.ps1 (reject fallback, wait for readiness and clean unique state file), game/tests/capture_dust_depth_candidates.gd (output and bridge pose checks), docs/status/phase notes and evidence. Review patch/source/binary hashes plus a preserved Compatibility rollback APK are under build/tablet-vulkan-2026-10-09/. Concurrent edits are preserved; no combined Git commit/merge or backend/production rollout.

## Completed checks after unlock

The tablet subsequently unlocked, and both remaining checks completed on the **final installed APK**:

- Pine/Ajorata ordinary unscored drive: actual mobile/vulkan, MSAA2x, zero paused frames; median **19.775ms**, p95 **28.416ms**. This is approximately50FPS median, with a worse tail than the earlier Pine Compatibility sample. Vulkan therefore has mixed frame-pacing results, not a universal performance improvement. Native view inspected: [Pine](evidence/tablet-vulkan-2026-10-09/pine-final/driving-0.png), [raw report](evidence/tablet-vulkan-2026-10-09/pine-final/results.json).
- Frozen under-deck witness: actual mobile/vulkan/MSAA2x, visual_only=true, physics disabled. **Dust still crosses the bridge deck** while the car is occluded. [Native bridge witness](evidence/tablet-vulkan-2026-10-09/bridge-review/driving-0.png). Its timings are not driving benchmarks. The renderer switch does not constrain expanding dust cards to the underside of a bridge; bridge-aware clipping/particle constraints remain required. Shadow resolution remains1024 for this matched trial, and shadow-quality acceptance remains with the owner.

Actual additional commands used scripts/profile-tablet.ps1 with the same serial/required renderer+driver, `-DocumentPath game/tests/fixtures/dust_cloud.json -Seconds 12 -Features baseline -BridgeReview -CaptureDriving -Output docs/evidence/tablet-vulkan-2026-10-09/bridge-review`, then `-DocumentPath game/tests/fixtures/ajorata.json -Seconds 12 -Features baseline -CaptureDriving -Output docs/evidence/tablet-vulkan-2026-10-09/pine-final`. Both removed their private diagnostics and restored ordinary play. Final ADB check confirms no mobile_probe.json and a running ordinary app process. Player records, sessions and authored tracks retained.

The Vulkan trial is left installed for owner review; the previous Compatibility APK remains available for rollback. This completes the requested renderer experiment without claiming that it fixes bridge leakage or guarantees better shadows/performance on every track.

2026-10-10: owner rejected Vulkan appearance. Compatibility restored, and the separate bridge clipping fix was implemented and installed. See [bridge dust correction](BRIDGE_DUST_2026_10_10.md) for the current verified device build.
