# First physical-phone deployment — 2026-09-18

Requirements: R01 (local application), G01 (driving/input smoke coverage), V03/V05 (device presentation), Q01 (device gate; performance acceptance remains pending).

## Build and installation

Installed the ARM64 debug APK on the owner's authorized DN2103 phone running Android 13. Pinned engine and Android templates: `4.7.2.stable.official.ed1daf0bf` / `4.7.2.stable`. Package: `org.circuit01.handlinglab`, launcher label `CIRCUIT / 01`. APK: `build/android/circuit01-debug.apk`; SHA256 `FE70A4F3702D29BE73A02522707BC90314B1095AB53306FE6E7CF75B991769BE`.

The APK retains the existing debug version code 2 / name `0.2.0-handling`. The prebuilt template reports minimum SDK 24 and target SDK 36. Godot warns that installed build-tools 35.0.1 do not match target SDK 36, then successfully signs and verifies the APK. This is local debug installation, not Play distribution.

## Changes

- `scripts/dev.ps1`: explicit `-QuickValidation` deployment mode runs import, startup, driving, catalog and menu checks. Default full validation is unchanged. ADB device enumeration tolerates normal daemon-start stderr while checking its exit status. Launch resolves the package's launcher intent instead of invoking a non-exported activity directly.
- `game/project.godot`: enable Android ETC2/ASTC texture imports and specify a launcher icon.
- `game/export_presets.cfg`: clear the unsupported Gradle-only minimum SDK override for the prebuilt APK workflow.
- `game/assets/app_icon.svg` and its Godot import descriptor: original editable navy/yellow circuit mark drawn for this deployment, with no external source asset or third-party logo.
- Deployment documentation and status/phase notes. No simulation, handling or gameplay camera changes.

## Machine setup and actual commands

Initial `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` failed: Android templates, SDK/ADB/build-tools and Java were absent. Installed matching official Godot templates, Adoptium OpenJDK 17.0.20.1, Google platform-tools and Android build-tools 35.0.1/platform 35 under the user's local application-data directories. Updated Godot's Java setting; the existing SDK setting already pointed to this SDK directory. The previous settings file is backed up under ignored `build/android-tools/`.

Downloads used `curl.exe -fL`/`-fsSL --retry 2` and `Expand-Archive`; Android templates were extracted using .NET ZipFile. Both current and older SDK-manager attempts failed to retrieve manifests. Downloaded build-tools/platform archives directly from Google's repository manifest and verified their SHA1 against that manifest before extraction. These are PC development tools, not runtime dependencies.

Official setup references: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [pinned release](https://godotengine.org/download/archive/4.7.2-stable/), [Google package manifest](https://dl.google.com/android/repository/repository2-1.xml), [Adoptium JDK](https://adoptium.net/temurin/releases/?version=17).

Actual project commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid
```

ADB checks also ran `devices -l`, Android version/ABI properties, `pidof`, process-filtered `logcat`, activity/window diagnostics and `screencap`/`pull`. `aapt dump badging` verified package, SDK and ARM64 metadata. `git diff --check` checked deployment source edits.

## Actual outcomes and limits

- Doctor passed after setup and USB debugging authorization.
- Full validation passed import, script parsing, startup and 25 domain suites through object-browser tests. It then stalled in `test_app.gd`; that specific test process was stopped. Its captured log reports `FAIL: Play exposes creator navigation`, null button access at line 112 and `get_global_rect` on null at line 59. Full validation **failed**, and later suites in that invocation did not run. This is consistent with the previously recorded integration-test problem in `DISCOVERY_MENU.md`.
- Final focused deployment checks passed startup plus 70 driving, 18 catalog and 11 menu checks, zero failures. No failed assertion was removed or relaxed.
- Initial exports failed on unsupported minimum-SDK override, missing Android texture import, then missing launcher icon. Corrected each configuration error; final export signed and verified successfully.
- Initial combined deployment stopped when ADB daemon startup wrote to stderr. Separate `InstallAndroid` returned `Success`. Initial direct activity launch was rejected because the activity is not exported. Corrected launcher resolution; `LaunchAndroid` returned `Status: ok`, and the package process was present.
- The initial screenshot was black because the phone had locked/dozed during the build. Owner was asked to unlock it for visual startup verification. A black capture is not proof of a rendered game.

Logs are under ignored `build/`: `android-validation.log`, `app-tests.log`, `android-deployment.log`, `android-export.log`, `adb-install.log`, `adb-launch.log`, `android-process.log` and SDK setup logs. The workspace already contained extensive unrelated edits; deployment before/after files are isolated under `build/android-deploy-checkpoint/`.

Remaining acceptance: visible device startup, real simultaneous touch driving, safe-area/readability, complete human-driven laps, editor use, background/resume and sustained frame-time/thermal measurement. Installation alone does not satisfy these gates.
