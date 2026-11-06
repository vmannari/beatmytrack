# Startup update deployed to the tablet — 2026-11-05

The owner's requested update is installed and running on the OnePlus Pad 2, `OPD2403`, Android 15, serial `f0ba474a`. The installed package is `org.circuit01.handlinglab`, version **`0.3.0-creator.7d30296e6932663c4577ef390f74e988`**, replacing `0.3.0-creator.307f1d5c6726377d85c73e6cf9eacf00`.

**TSD01:** A fresh Android Debug APK was exported through `scripts/dev.ps1` with pinned Godot `4.7.2.stable.official.ed1daf0bf` and matching Android templates. An isolated offline desktop profile kept build tests away from the owner's PC saves; existing SDK/JDK, template and signing setup were reused. The only shipping-file changes during export were generated `game/core/build_identity.gd` and `game/project.godot`. No gameplay/runtime source changed during this deployment.

The prepared-asset preflight loaded 468 resources and passed **1925 checks, zero failures**. All five packaged Garage photographs matched 156 source hashes. Import and startup passed (`APP_READY`); focused driving **72/0**, catalogue **21/0** and menu **41/0** checks passed. The full regression suite was not run. The catalogue retains an existing unequal-anchor warning; export reports use of embedded text-server data with the matching pinned templates. Export exited 0 in 207.25 seconds.

**TSD02:** `InstallAndroid` used `adb install -r` and returned `Success`. No uninstall, clear-data, track synchronization or account/configuration replacement was performed. Android's original first-install timestamp remained unchanged. `LaunchAndroid` returned `Status: ok` and `LaunchState: COLD`. Android's reported 458 ms activity-launch time is not complete game startup or a performance benchmark.

**TSDQ01:** APK package/version and ARM64 contents were verified before installation; all 8,903 ZIP-entry checksums passed. Installed version matches the exported build. The new app process logged the expected Godot engine, Compatibility/OpenGL ES renderer on Adreno 750, and `APP_READY`, with no matched script/parser/native-load/fatal error in the filtered startup sample. Window focus confirmed the game's activity. The [inspected tablet screen](evidence/tablet-startup-deploy-2026-11-05/tablet.png) shows the restored signed-in Rivalry menu and the new missing-header silhouette.

APK: `build/android/circuit01-debug.apk`, **407,041,136 bytes**, SHA-256 **`7e4b14015b5d6eb217074d75a67b3d7590aa3ac50b8973e02d3d5491d6ad0640`**. [Deployment receipt](evidence/tablet-startup-deploy-2026-11-05/deployment.json), [export receipt](evidence/tablet-startup-deploy-2026-11-05/export-result.json) and [filtered startup log](evidence/tablet-startup-deploy-2026-11-05/startup-filtered.log) retain the actual results.

The sandboxed ADB attempt could not create its Android user directory; the existing Android toolchain was then used outside that sandbox under the explicit deployment request. The first focus probe used `dumpsys window windows`, which returns no focus fields on this tablet; the corrected `dumpsys window` query verified foreground state. These were tooling/probe limitations, not failed app startup. Initial receipts remain in `build/tablet-startup-deploy-20261105`.

Actual commands were the following, invoked by the task's isolated export/verification helpers:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action InstallAndroid -DeviceSerial f0ba474a -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action LaunchAndroid -DeviceSerial f0ba474a -CommandTimeoutSeconds 300
# ADB: device/model/version, package first-install/version checks, normal wake,
# keyguard dismissal, process-filtered logcat, window focus and one screencap.
```

Original export/check logs remain under `build/logs/ExportAndroid-21204`; isolated helpers/profile and source hashes remain under `build/tablet-startup-deploy-20261105`. The [source checkpoint](evidence/tablet-startup-deploy-2026-11-05/task.patch) covers generated build metadata and this deployment's documentation only; the main Git index is untouched. Concurrent edits are preserved.

This completes deployment and a physical-tablet startup/UI smoke check for the [startup-thumbnail change](STARTUP_THUMBNAIL_2026_11_05.md). It does not measure tablet startup improvement, Garage regeneration, driving FPS, thermals or memory, and no race, purchase or authentication flow was driven. No backend deployment or administrative mutation was performed; the launched app used its existing saved session and normal service behavior. Owner touch/audio/gameplay and sustained performance acceptance remain.
