# Tablet loading update deployment — 2026-11-04

Installed and launched on OnePlus Pad 2 / OPD2403, serial `f0ba474a`.
Build: `0.3.0-creator.63ebd511a08176a6966e6ca73cbdc444`.

The update includes the prepared-asset repair and the current shared workspace changes.
Frozen source and APK: `build/tablet-loading-deployment-2026-11-04/source`.
The private snapshot repository leaves the main Git index untouched.
`build-before.json` and `build-after.json` have identical source/build hashes.

## Validation and installation

- Pinned Godot `4.7.2.stable.official.ed1daf0bf`.
- Prepared pipeline `--verify`: dependency audit, all prepared resources and image provenance pass.
- Five bundled Garage pictures and 156 source hashes pass.
- Import and startup (`APP_READY`) pass; driving 72/0, catalogue 21/0, menu presentation 41/0.
- Snapshot export: `scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 900` with the pinned `-GodotPath`. See copied export/test logs.
- `adb -s f0ba474a install -r <snapshot>/build/android/circuit01-debug.apk`: Success.
- `adb -s f0ba474a shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p org.circuit01.handlinglab`: status ok.
- `python docs/evidence/tablet-loading-deployment-2026-11-04/verify_device.py`: pass. Installed and local APK SHA256 match; original October 8 installation time retained; process reaches APP_READY with no matched fatal/script errors.
- Screenshot reviewed: existing Ville profile and weekly Rivalry screen restored. No taps or races run.

## Retained findings and limits

Initial sandbox import was denied access; running the Android toolchain outside the sandbox resolved it. The first successful workspace export was **not installed** because its source identity changed during concurrent work. A frozen copy was rebuilt; its before/after identity matches. Private snapshot ownership initially needed a process-local Git safe-directory exception, and its pinned Android source ZIP was copied before retry. No global Git configuration was changed. The catalogue anchor warning and export ICU advisory remain in logs.

App data was preserved using an in-place update; no uninstall, data clear, track sync, backend deployment or main-index write. This is deployment/startup verification, not an Android loading-time, touch, driving, visual-equivalence or thermal benchmark.
