# Performance update deployed to OnePlus Pad 2 ? 2026-11-06

The requested update is installed and running on the OnePlus Pad 2 (`OPD2403`, Android 15, serial `f0ba474a`). The installed version is **`0.3.0-creator.9d328fb6e64cdf51f72c95abc68c1d5f`**, replacing `0.3.0-creator.7d30296e6932663c4577ef390f74e988`. The [inspected tablet screen](evidence/tablet-performance-deploy-2026-11-06/tablet.png) shows the restored signed-in Weekly Rivalry page, existing custom car and standings.

## Requirements and outcomes

- **TPD01 ? Fresh validated build:** The pinned Godot `4.7.2.stable.official.ed1daf0bf` and existing matching templates/signing configuration produced a fresh `Android ARM64` APK through `scripts/dev.ps1`. Build tests used an isolated offline PC profile. Export exited 0 in 219.266 seconds. Runtime/visual sources and generated identity remained unchanged across export; independent post-export identity calculation still matches the installed build.
- **TPD02 ? Preserve the tablet's data:** Standard `adb install -r` succeeded. All **760 existing files under the app's `files/` directory** had identical SHA-256 manifests immediately before and after installation, before first launch. The original first-install timestamp (`2026-10-08 22:15:46`) is unchanged. No uninstall, clear-data, track sync or account/configuration replacement was performed. Normal startup may write its ordinary caches/session state afterwards.
- **TPDQ01 ? Verify the installed result:** Every APK ZIP checksum passed, actual native libraries are ARM64-only, package/version matches, and the installed APK's SHA-256 matches the exported file exactly. After the owner unlocked the secure keyguard, the existing process resumed, reached `APP_READY` and held the actual current window focus. The sampled logs contain no matched script/parser/native-load/fatal errors. The settled native screen was inspected.

## Artifact and checks

APK: `build/android/circuit01-arm64.apk`, **323,430,586 bytes** (308.45 MiB), SHA-256 **`693a83b463717cf41ae209d23012a178a22791555e99fe11bfe6ee54ca302ac0`**, **8,917 ZIP entries**. The previous two-architecture APK is 407,041,136 bytes, so this artifact is 83,610,550 bytes (about 84 MB/20.5%) smaller. This is an artifact-size comparison across the two versions, not a runtime RAM/performance measurement.

Prepared assets: 468 resources/1925 checks/0 failures; five exact packaged Garage photographs and 156 source hashes. Import/startup and focused driving 72/0, catalogue 21/0 and menus 41/0 passed. This deployment uses the prior implementation's extensive desktop tests; a full regression suite was not rerun for export. The existing catalogue anchor warning and embedded text-server-data export warning remain in the logs.

The rollback APK remains at `build/android/circuit01-debug.apk`, SHA-256 `7e4b14015b5d6eb217074d75a67b3d7590aa3ac50b8973e02d3d5491d6ad0640`. It was hash-matched to the previously installed package before replacement. No rollback was needed.

## Initial verification recovery

The first sandboxed ADB invocation could not create its Android user directory. The existing toolchain was then run with the authorized device access. The first launch returned `Status: ok` but the tablet's secure keyguard held `NotificationShade` focus; the startup check timed out with no app error. Its initial foreground check was insufficient because a focused application can still sit behind that window. The retained [initial receipt](evidence/tablet-performance-deploy-2026-11-06/deployment-initial-locked.json) therefore does not establish visible readiness.

Android reported `secure=true`, so the owner was asked to unlock the tablet. No PIN/password was read or entered. After manual unlock, startup and current-window focus passed. The first immediate capture still showed account/Rivalry loading; a later settled capture confirms the actual usable page. The resumed process kept the same PID. No reinstall or runtime patch was needed.

## Commands, evidence and scope

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -AndroidPreset "Android ARM64" -QuickValidation -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action InstallAndroid -AndroidPreset "Android ARM64" -DeviceSerial f0ba474a -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action LaunchAndroid -AndroidPreset "Android ARM64" -DeviceSerial f0ba474a -CommandTimeoutSeconds 300
```

The isolated helpers additionally supplied the existing ADB executable path, checked package/model/ABIs, compared private file manifests, read process-filtered logs, queried actual current-window focus and captured the screen. Full commands/logs and private file hashes are retained in `build/tablet-performance-deploy-20261106`; private account/file manifests and lock-screen captures are excluded from public evidence. Standard build logs are under `build/logs/ExportAndroid-34196`.

[Export receipt](evidence/tablet-performance-deploy-2026-11-06/export-result.json), [deployment receipt](evidence/tablet-performance-deploy-2026-11-06/deployment.json), [startup sample](evidence/tablet-performance-deploy-2026-11-06/startup-filtered.log) and the [source implementation report](MOBILE_PERFORMANCE_IMPLEMENTATION_2026_11_06.md) retain the actual boundaries. A checked task-only documentation patch is at [task.patch](evidence/tablet-performance-deploy-2026-11-06/task.patch), with [verification receipt](evidence/tablet-performance-deploy-2026-11-06/checkpoint.json). The main Git index is untouched and concurrent work is preserved.

Deployment and physical-tablet startup/UI smoke are complete. Driving FPS, sustained thermals, memory, Garage/Profile interactions and owner touch/audio acceptance were not measured in this deployment. This is the stock Compatibility engine; the separate custom Android shader engine remains unqualified. The launched app used its saved account and ordinary service behavior; no race, purchase, authentication flow, direct backend/admin action or backend deployment was performed.
