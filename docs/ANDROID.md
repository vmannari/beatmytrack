# Android debug build and physical-phone gate

## Pixel 9 loading performance (2026-10-04)

Debug exports now include ARM64 and native x86_64 Godot/music libraries. Pixel 9 selects x86_64 instead of translating the ARM64 game. The owner's local AVD now uses host graphics, 4096 MB RAM and cold boot; its prior configuration is backed up under ignored `.tools/emulator-performance/`. Track-selection and visible race-load measurements, commands and remaining acceptance are in [EMULATOR_PERFORMANCE.md](EMULATOR_PERFORMANCE.md). Game data is retained; no physical phone was installed or tested for this change.

## Current AdMob development build (2026-10-04)

The owner subsequently authorized AdMob and Settings → Development → Show ads. Current exports use the matching Gradle source template and Google's pinned debug-only rewarded SDK; see [ADMOB_DEVELOPMENT.md](ADMOB_DEVELOPMENT.md) for behavior, actual commands/results, certificate diagnosis and evidence. The earlier Pixel 9 deployment below describes the pre-AdMob APK.

`scripts/dev.ps1 ExportAndroid` requires official `android_source.zip` from `%APPDATA%\Godot\export_templates\4.7.2.stable\` or `.tools/admob/android_source.zip`. It checks SHA-256 `A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3`, installs into ignored `game/android/build`, checks the paired `.build_version`, and attaches `native/admob/android.gradle`. A different/incomplete existing source directory is preserved and rejected. The official 4.7.2 template uses compile SDK 36/build tools 36.1.0; SDK installation requires accepted Android licenses. The SDK raises minimum Android to 24. ARM64 export architecture and the native music extension remain.

Windows Java downloads keep HTTPS verification using existing Windows roots unless a caller supplies a custom Java trust store. Local diagnostic Android CA resources require an explicit `BMT_ADMOB_DEBUG_CA_DIR`; the owner's approved Avast public root/configuration remains ignored and debug-only. Never treat a demo completion as proof for a production banked grant. Normal build/install/launch commands remain the same; specify `emulator-5554` to avoid selecting the attached phone.

## Pixel 9 emulator deployment and rewarded-ad next step (2026-10-04)

Requirements **R01/V05/Q01**: the owner's existing `Pixel_9` AVD was started, a fresh debug APK was validated/exported with pinned Godot 4.7.2, and installed/launched specifically on `emulator-5554`. **RW05/RW06/RW07** remain pending for actual rewarded-ad integration; no ads SDK, provider verification or reward behavior changed in this task.

The installed AVD is Android 17 / API 37 (`android-37.2` image), Google Play, x86_64 with 16 KB pages. Runtime reports `x86_64,arm64-v8a` and `libndk_translation.so`; the existing ARM64-only APK and native music extension can therefore launch on this image without changing export architectures. This is evidence for this particular AVD, not a guarantee for other x86 images or native performance acceptance.

Actual build/deployment commands, from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid -DeviceSerial emulator-5554
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid -DeviceSerial emulator-5554
# The debug app defaults to http://127.0.0.1:18181. Forward it to the PC backend:
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 reverse tcp:18181 tcp:18181
```

The last command routes Android's loopback port through ADB to the existing PC API; it preserves the client's loopback-only HTTP allowance. Run it again if the emulator/ADB connection resets. Relaunch the app or retry its connection after forwarding. The PC API already returned `ready`, schema `0011_weekly_rivalry`; no backend rebuild, restart, migration or deployment was performed. This forwarding supports the game API; browser-based Google sign-in and its redirect/origin configuration were not tested.

Actual outcomes: import/startup succeeded (`APP_READY`); driving **72**, catalog **21**, menus **48** checks passed with zero failures. Export signed/verified successfully, install returned `Success`, and both launches returned `Status: ok`, `LaunchState: COLD`. Final game-process log sample contains `APP_READY` and no matched script/native-load/error entries. APK SHA-256: `6C87FB130B10DF566FC21C31ABF7242840E81D729E1C45B77D26F999B737EC1C`. Existing build-tools fallback to 35.0.1 was reported. Full regression validation was not run.

Initial sandboxed `Doctor` failed because ADB could not create its Android user directory; the permitted toolchain invocation outside that sandbox enumerated the phone and emulator. The first emulator probe found it offline while booting; the later probe reported boot completion. Initial sign-in and Guest Race captures showed a missing backend connection/empty library. ADB forwarding removed the connection error; the final capture shows live five-lap gameplay. This was deployment/startup evidence, not a completed race, replay comparison or handling/performance test.

Inspected screenshots: [initial sign-in](evidence/pixel9-emulator-2026-10-04/launch.png), [initial disconnected Guest Race](evidence/pixel9-emulator-2026-10-04/guest-race.png), [connected sign-in](evidence/pixel9-emulator-2026-10-04/connected.png), [live gameplay](evidence/pixel9-emulator-2026-10-04/gameplay.png). Changed files: this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and these evidence images. No game-code change. A DN2103 physical phone was attached, but no physical-phone install or test was performed by this task. Manual controls, full-race completion, audio, Google sign-in, sustained emulator behavior and real-device performance remain acceptance checks.

For ads, the current button still uses the owner-authorized temporary free `ad_preview` resume; it does not display an ad or award banked credit. Recommended next slice:

1. Select the rewarded-ad provider (AdMob recommended), use a Godot Android adapter and the matching engine's Gradle build template, and pin the SDK dependency outside canonical simulation. [Godot 4.7 Android plugin integration](https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html).
2. Start with Google's sample app ID and rewarded demo unit, allowing an SDK test without first creating production placements. Google automatically recognizes Android emulators as test devices. [Sample app configuration](https://developers.google.com/admob/android/quick-start), [test ads](https://developers.google.com/admob/android/test-ads).
3. Verify ad loading, completion, early dismissal, failed/no-fill requests, background/return behavior and duplicate callbacks. Bind production rewards to server-verified, idempotent fulfillment before minting banked resumes. An SDK demo and backend reward verification are separate acceptance checks; Google provides a callback testing tool for the latter. [Rewarded server-side verification](https://developers.google.com/admob/android/ssv).
4. For the production path, configure the owner's AdMob app/unit and reachable HTTPS verification callback, then test reward ownership, one grant per verified transaction, retry recovery and the three-resumes-per-race rule. Keep test rewards isolated from production wallets. Live ad rollout remains a separate owner-authorized step.

## Deploy game and all saved PC tracks

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-phone.ps1
```

Uses pinned Godot through `scripts/dev.ps1 DeployAndroidWithTracks`. Runs focused import/startup/driving/catalog/menu checks, exports a fresh debug APK, installs it, copies saved tracks from `%APPDATA%/Circuit01Lab/tracks`, verifies SHA-256 hashes and launches the app. Optional `-FullValidation` selects the full regression gate; existing full-suite limitations still apply. `-DeviceSerial`, `-AdbPath`, `-GodotPath` and `-TracksPath` are supported. One authorized phone is required unless explicitly selected.

PC tracks win when the same ID exists on the phone. Every replaced phone JSON is backed up under app-private `files/track_sync_backups/<run-id>/`; phone-only tracks and records are preserved. Local source snapshots and a completed-file manifest live under `build/track-sync/<run-id>/`. Each track is staged, verified and renamed individually; a disconnect can leave a partial sync, recoverable by rerunning. Source filename/JSON IDs are checked before building. This copies top-level saved track JSON, excluding editor `wip/` autosaves, `.bak` and `.tmp` files. Save edits in the PC editor first. Missing/empty source folders stop without deployment.

Changed files: `scripts/deploy-phone.ps1`, `scripts/dev.ps1`, this document and status/phase notes. Requirements R01/T01/V05. Device testing and final outcome are recorded in the status entry. No gameplay behavior changed; no new screenshot is required for this command-line utility.

2026-09-18 update: Android tools and matching templates are installed; the debug APK has been installed on the owner's DN2103 / Android 13. See [actual deployment results and remaining acceptance](ANDROID_DEPLOYMENT_2026_09_18.md). The missing-tool/no-APK statements below describe the original bootstrap. For focused local deployment use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation`; omitting that switch retains full regression validation, currently failing in app navigation integration checks.

Bootstrap contains a standard APK export preset and deployment commands. At the initial inspection, matching export templates were absent; Godot's Android SDK path pointed to a nonexistent directory; its Java SDK path was empty; neither ADB nor Java was on PATH. Therefore APK export, install, launch and physical-phone handling are **not tested**. A phone cannot be enumerated until ADB is available.

## Toolchain setup

1. Use Godot **4.7.2 standard** and install matching **4.7.2.stable export templates** through Editor → Manage Export Templates. Expected Windows directory: `%APPDATA%\Godot\export_templates\4.7.2.stable\`, including `android_debug.apk`. Never substitute templates from another release.
2. Install JDK 17 and an Android SDK with platform-tools (ADB), build-tools, command-line tools and an Android platform compatible with the pinned engine. Use the pinned engine's export diagnostics to confirm versions before building. The current official Android export guide lists platform-tools 35+, build-tools 35.0.1 and platform 35; this is debug tooling guidance, not a Play submission target. The guide also lists NDK/CMake for builds that require them; bootstrap uses the prebuilt non-Gradle template and adds no native plugins.
3. In **Godot 4.7.2 → Editor Settings → Export → Android**, set `Java SDK Path` to the JDK root and `Android SDK Path` to the SDK root. The build script reads these same settings to avoid reporting environment-only paths as configured engine paths. Keep machine-specific paths and signing material out of Git.
4. Run `Doctor` below. Resolve its missing-tool messages. Run `ExportAndroid`; Godot's exporter performs final validation of SDK/template/signing compatibility. No release keystore is needed for this debug-only workflow.
5. On the phone enable Developer options and USB debugging; connect a data-capable USB cable, unlock the screen, and accept the computer's debugging authorization. Install a manufacturer USB driver if Windows requires it.

Sources checked during bootstrap: [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [Godot command-line export](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [official Windows engine/templates](https://godotengine.org/download/windows/). This is local debug distribution only. Recheck Play policy at the later release gate.

## Commands

From repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid -DeviceSerial YOUR_SERIAL
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid -DeviceSerial YOUR_SERIAL
# Full sequence; validation failure prevents export/install:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -DeviceSerial YOUR_SERIAL
```

`-DeviceSerial` can be omitted when exactly one authorized device is connected. `-AdbPath`/`ADB_BIN` can override ADB discovery. The script refuses ambiguous, offline or unauthorized devices. Emulator execution does not satisfy the physical-phone gate.

Equivalent commands after resolving executable paths:

```powershell
& $env:GODOT_BIN --headless --path game --editor --import
& $env:GODOT_BIN --headless --path game --export-debug 'Android Debug' '../build/android/circuit01-debug.apk'
& $env:ADB_BIN devices -l
& $env:ADB_BIN -s YOUR_SERIAL install -r build/android/circuit01-debug.apk
& $env:ADB_BIN -s YOUR_SERIAL shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p org.circuit01.handlinglab
```

Use the wrapper for validation before export and protection against deploying a stale failed build. `install -r` updates the debug app without intentionally deleting its data. If Android rejects a signing mismatch, stop and investigate; do not automatically uninstall and lose future PBs. Builds/logs go in ignored `build/`. No APK currently exists.

## Manual tests, in order

The driving playground is now available on Windows: open `game/project.godot`, press F5, and use WASD/arrows with Space for brake. See `DRIVING_PLAYGROUND.md` for the current controls and first handling session. On Android, once tools are installed, verify the same yard in landscape and all four touch zones. Synthetic desktop touch checks have passed; real finger/safe-area behavior is not yet validated.

The first subjective session is:

1. Hold throttle, release, then brake. Judge whether acceleration and stopping are immediate and predictable.
2. At low and high speed, reverse steering. Judge whether heading responds promptly without losing readable momentum.
3. Enter a turn too quickly, release throttle and countersteer. Judge whether you can catch the slide deliberately, and whether grip recovery is gradual enough to understand.
4. Repeat the turn using earlier braking and later throttle. Judge whether the improved line is both visible and faster.
5. Test simultaneous steering/throttle/brake, move a finger off a zone, lift both fingers and background/resume. Report sticky input or hidden corner approaches.
6. After the circuit/timing steps, complete ten consecutive laps during a 20-minute phone session. Record lap times, missed inputs, reset delay, device model/Android version, renderer, build hash and thermal conditions. Try the hairpin, chicane and wall contact. State whether you want another attempt without adding new content.

Stop feature expansion and adjust handling if slides feel arbitrary, throttle is mostly passive, or retry is frustrating. Camera acceptance additionally requires a matched 1672×941 shot and full-lap visibility in every heading. Frame-time/thermal acceptance requires actual traces, not a desktop FPS average. External-test recruitment and P0-V art production follow owner handling approval.

2026-09-19 deploy-phone verification: ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-phone.ps1` on DN2103. Final run passed import/startup, driving 70, catalog 18, menus 11, installed the APK, verified all 20 saved PC tracks and launched normally. Phone-only track `track_4f574f390cfe5be0` confirmed retained. Missing-source invocation exited 1 before build/install. Initial sync stopped on ADB progress emitted to stderr; corrected the native-process wrapper to check exit status while capturing stderr, then reran successfully. Existing build-tools fallback/exit-time warnings remain; full regressions not rerun. Targeted diff whitespace check passed. No mixed-workspace commit made.
