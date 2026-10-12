# New-tablet deployment — 2026-10-08

Requirements: **R01/G01/V03/V05/Q01/B01/B07**. The current game was rebuilt, installed and launched on the owner's OnePlus Pad 2. Its missing cloud-server configuration was corrected after the owner reported that sign-in failed. A saved cloud sign-in session and visible live gameplay were verified.

## Completed deployment and sign-in repair

The owner accepted the tablet's USB debugging prompt. `scripts/dev.ps1 InstallAndroid -DeviceSerial f0ba474a` returned **Success**; `LaunchAndroid` returned **Status: ok**, **LaunchState: COLD**. The tablet reports **OPD2403 / Android 15 / API 35 / arm64-v8a**, physical portrait resolution **2120×3000**, with the game rendered at **3000×2120 landscape**. Its initial game process reached `APP_READY`.

The first screen capture was black because the tablet was asleep and the notification/lock screen covered the game. Waking the tablet, requesting normal keyguard dismissal and collapsing the notification shade produced the inspected sign-in screen. Initial logs contain OEM/audio and abandoned-surface warnings around sleep; this was not counted as a crash-free or performance test. No PIN, password or device security setting was changed.

The rendered sign-in screen reported an unreachable game service: a new debug installation defaults to `http://127.0.0.1:18181`, while the owner's existing PC configuration uses `https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app`. A read-only `/v1/bootstrap` check confirmed service `beat-my-track` and configured Google browser sign-in. The tablet received an app-private `files/backend.cfg` containing **only that existing HTTPS URL**, using staged copy/rename and preserving any pre-existing configuration before replacement. No development key, access/refresh token, PC session or player data was copied. The game was restarted to reload the configuration; no backend service, cloud resource, schema or server configuration was changed.

After the owner resumed interaction, the inspected [tablet gameplay capture](evidence/tablet-deployment-2026-10-08/tablet-cloud.png) showed a live five-lap race. A read-only marker check confirmed `files/account_session.cfg` exists, its `.signed_out` fence does not exist, and its saved **URL only** matches the cloud origin. Credentials and player identity were not read. This verifies a saved cloud session; the owner performed the interactive account flow. No agent-driven Google authentication, completed race, timing verification, audio listening or sustained performance test is claimed.

Actual deployment commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid -DeviceSerial f0ba474a
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid -DeviceSerial f0ba474a
# ADB: getprop model/Android/API/ABI, wm size, pidof, process-filtered logcat,
# screencap/pull, normal wake/dismiss-keyguard/statusbar collapse.
# Sign-in repair: validate existing PC URL; GET /v1/bootstrap; adb push URL-only
# config, run-as backup/copy/rename, force-stop, LaunchAndroid.
# Verification: run-as test saved-session/fence; grep its URL only.
```

[Device metadata](evidence/tablet-deployment-2026-10-08/device.json), [sign-in verification](evidence/tablet-deployment-2026-10-08/sign-in-verification.json), [public server summary](evidence/tablet-deployment-2026-10-08/server-bootstrap-summary.json), [native startup log](evidence/tablet-deployment-2026-10-08/startup-device-final.log), [initial sign-in capture](evidence/tablet-deployment-2026-10-08/tablet-final.png) and the gameplay capture retain the actual evidence. The initial black capture and earlier failed/pending connection observations remain as history.

## Build and authorization retry history

New audio/runtime files appeared after the initial build. A new pinned `ExportAndroid -QuickValidation -CommandTimeoutSeconds 600` run passed import/startup, driving **72**, catalog **21** and menus **48** checks, then completed export. The current APK is **241,058,074 bytes**, SHA-256 `BDBA4FD0340D58318375C14A351C420BDC657708FDA74575A2C0C238D2C0C09F`. [Retry metadata](evidence/tablet-deployment-2026-10-08/deployment-retry.json) and [retry export log](evidence/tablet-deployment-2026-10-08/export-retry/android-export.log) preserve this build separately from the initial one below.

The owner enabled USB debugging after an all-USB scan found the tablet exposing only MIDI (`USB\VID_18D1&PID_4EE8\F0BA474A`). The earlier vendor-specific scans missed this mode; their inference that the tablet had disconnected was incorrect. Windows now sees `USB\VID_22D9&PID_2769\F0BA474A`, and ADB lists `f0ba474a unauthorized`. The owner was asked to unlock the tablet and accept its Allow USB debugging prompt. No Windows driver/registry changes were needed. An initial authorization waiter ended with a connection-reset error around export completion; a new targeted waiter was started after the build, then stopped without a connection. Retrying the handshake and refreshing the ADB server again confirmed the unauthorized state. Shell property reads were rejected by Android authorization and are not passing device tests.

## Actual build and checks

The project entry point used pinned Godot `4.7.2.stable.official.ed1daf0bf` and its matching `4.7.2.stable` Android Gradle template. Import and startup passed (`APP_READY`); driving **72**, catalog **21** and menu presentation **48** checks passed, with zero failures. The driving fixture reported its existing 31-instance shutdown leak warning. Full regression validation was not run.

Export completed successfully to `build/android/circuit01-debug.apk`: **241,058,546 bytes**, SHA-256 `58D29AD6F0AD626058EAC266099BB1246BC565C5E9405EEC9EB8F1FB8D6171FA`. APK metadata confirms package `org.circuit01.handlinglab`, version code `2`, version name `0.2.0-handling`, minimum Android API **24**, target API **36**, and **arm64-v8a/x86_64** libraries.

Actual primary commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
$adbExecutable = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
& $adbExecutable server-status
& $adbExecutable reconnect offline
& $adbExecutable devices -l
```

The initial sandboxed Doctor failed because ADB could not create `\.android`. Retrying the installed toolchain with access to the existing Android setup passed the prerequisite check. Repeated ADB enumeration returned an empty device list, including after an offline-connection rescan. Windows reported an existing ADB USB interface but no identifiable tablet. No installation or launch command was issued against an unidentified device. The owner was asked to unlock the tablet, enable USB debugging and accept the authorization prompt; a data-capable cable is needed if no prompt appears.

## USB follow-up

After the owner confirmed readiness and identified a **OnePlus Pad 2 connected over USB**, Windows device properties confirmed tablet serial `F0BA474A`. Its tethering and File transfer ADB interfaces use Microsoft's `winusb.inf` but lack the Android interface registration. The tablet's already registered charging-only interface (`USB\VID_22D9&PID_2769\F0BA474A`) has `DeviceInterfaceGUID={F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}`; that interface is currently disconnected. The owner was asked to select No data transfer / Charging only with USB debugging retained.

An empty-server restart and the documented `ADB_LIBUSB=1` alternate backend both still returned no devices. The normal backend was restored afterward. No Windows driver or registry value was modified. A targeted ADB USB waiter was started for the identified serial and stopped when no connection arrived; no persistent installation helper remains. The Windows token is not administrator-elevated. At that point no source file was newer than the prepared APK. The final scans in that retry filtered only vendor `22D9`, which missed the tablet's subsequent Google-vendor MIDI mode. The corrected all-USB diagnosis and necessary later rebuild are recorded above.

The backend selection follows [Android's ADB documentation](https://developer.android.com/tools/adb#adb-usb-backends); Windows interface discovery is documented by the [AOSP Windows USB implementation](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/client/usb_windows.cpp). Diagnosis rests on the local device/registry observations; these references alone do not establish tablet connectivity.

## Evidence and remaining acceptance

[Deployment metadata](evidence/tablet-deployment-2026-10-08/deployment.json), [export and validation logs](evidence/tablet-deployment-2026-10-08/export/android-export.log), [ADB device list](evidence/tablet-deployment-2026-10-08/adb-devices.txt) and [APK metadata](evidence/tablet-deployment-2026-10-08/apk-badging.txt) record the actual outcome. The failed sandbox Doctor log is also retained in the evidence directory.

**Deployment and the reported connection/sign-in issue are complete.** Physical-tablet install, native startup, rendered UI, saved cloud session and live gameplay were verified. Touch feel, audio mix, complete five-lap racing, verified results, browser/provider edge cases, editor use and sustained frame-time/thermal acceptance still require dedicated device evaluation. Full regression validation was not run.

Changed files are this document, the Android documentation link, development/phase status entries, deployment evidence, ignored `.tools/tablet-deployment-2026-10-08/backend.cfg` and the tablet's private backend configuration. Game source and canonical simulation were not changed by this task. Player records and sessions were preserved, and backend services/cloud resources were not changed. The task-only review patch and before snapshots are under ignored `build/tablet-deployment-2026-10-08/`; its projected before-state excludes concurrent documentation changes.
