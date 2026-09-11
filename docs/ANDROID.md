# Android debug build and physical-phone gate

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
& $env:ADB_BIN -s YOUR_SERIAL shell am start -W -n org.circuit01.handlinglab/com.godot.game.GodotApp
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
