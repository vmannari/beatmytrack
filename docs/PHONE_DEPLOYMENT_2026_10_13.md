# Requested phone deployment, 2026-10-13

Requirements: PD01 install the current debug build; PD02 launch on the connected phone; V03/V05/Q01 preserve data and report actual physical evidence. Both deployment requirements completed. No gameplay code or contracts changed.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG -CommandTimeoutSeconds 600
```

Godot 4.7.2.stable.official.ed1daf0bf and matching Android templates verified. Supported focused checks passed: import, APP_READY startup, driving 72, catalog 21, menu presentation 48, all zero failures. Full regression was not run; earlier full-gate road-material failures remain recorded in docs/PHONE_KEYBOARD.md. Startup fixture emitted a thread-completion warning; not suppressed. Export succeeded to a fresh APK before replacing the standard debug path, preventing stale deployment.

ADB install -r returned Success and preserved existing private app data. Launch returned Status ok, COLD, TotalTime 1087ms / WaitTime 1150ms. On actual OnePlus DN2103, app process 19520 emitted APP_READY; a 2400x1080 sign-in screen was captured and inspected. It reports that the game service could not be reached; backend/network configuration was not changed. No desktop tracks were synced and no backend was deployed.

Actual device commands also used SDK adb.exe: shell pidof org.circuit01.handlinglab, shell screencap -p /data/local/tmp/bmt-deploy-2026-10-13.png, pull to evidence/phone-launch.png, and logcat -d --pid=19520 -v brief. The phone disconnected before a subsequent optional Guest tap/capture; those commands returned device not found, and a final adb devices confirmed zero connected devices. Therefore no Guest/garage/reflection interaction, race or device performance test is claimed. Owner visual/touch/performance acceptance remains outstanding.

APK: build/android/circuit01-debug.apk, 230489272 bytes, SHA256 deec89052457d45b94e1b9341f27e2fb1e049cee1dffda636f2a44d2d905db54.

Changed documentation: DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and this report. Evidence: [phone screenshot](evidence/phone-deploy-2026-10-13/phone-launch.png), copied actual export/check/install/launch logs in the same folder. Review checkpoint: build/phone_deploy_2026_10_13/checkpoint-repo. Main Git index/HEAD remain unchanged; existing unrelated workspace edits preserved.

The hash/size above were read immediately after this deployment. Another workspace build subsequently replaced the shared APK path while this report was being written; that later file is not evidence of the installed APK. Actual deployment logs and screenshot are retained.
