# CIRCUIT / 01 — handling laboratory

Working title from the blueprint. Phase 0 review and Phase 1 bootstrap only: the current scene confirms startup. It does **not** yet contain a drivable car, track, camera calibration or race logic. The next implementation task is the physics playground; driving feel is the first subjective gate.

Open `game/project.godot` with **Godot 4.7.2 standard**, build `4.7.2.stable.official.ed1daf0bf`. The supplied machine has that executable under `C:\apps\Godot 4.7.2\`; its `godot` PATH alias points to an older version. `scripts/dev.ps1` checks the pin before running anything.

## Developer loop (PowerShell, from repository root)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Editor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Capture
```

ExecutionPolicy Bypass applies to this invocation only; no machine policy change is needed. `Run`/`Editor` remain attached until the window closes. Override discovery with `-GodotPath 'D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'` or `GODOT_BIN`. Validation imports the project, parses every GDScript and checks main-scene startup, failing on engine script errors even when the process exits zero. Logs and capture go to ignored `build/`.

Compatibility rendering is the initial baseline. The project uses landscape, a 1280×720 logical UI with expanded wider viewports, a fixed 120 Hz physics setting and independent input actions. Camera coverage and safe-area touch layout are future implementation checks. Keyboard actions are registered now (WASD/arrows, Space brake, R restart, F1 telemetry, Escape pause); they will become functional with the playground.

## Android

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid
# Or validate, build, install and launch in sequence:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -DeviceSerial YOUR_SERIAL
```

See [Android setup and device acceptance](docs/ANDROID.md). Preset: `Android Debug`, arm64, package `org.circuit01.handlinglab`, output `build/android/circuit01-debug.apk`. There is no backend, runtime external dependency or network permission. SDK, JDK and matching templates are currently missing from the configured locations, so no APK or physical-phone test is claimed.

## Project contract

Read [Phase 0 review and eight tasks](docs/PHASE_0_PLAN.md), [development status](DEVELOPMENT_STATUS.md) and [agent instructions](AGENTS.md). `game/` is the entire Godot resource root. The preserved specification, financial workbook and reference images are outside it and are never packaged as game assets. Asset provenance belongs in [licenses](licenses/ASSETS.md).

The existing package's Python tests exercise documentation/schema examples, not this game:

```powershell
# Optional documentation-only tooling; not a game dependency.
python -m venv .tools/review
.tools/review/Scripts/python.exe -m pip install jsonschema==4.26.0
.tools/review/Scripts/python.exe -X utf8 -m unittest discover -s Android_racing_game_blueprint_v2/technical/tests -v
```

Use `git` normally, or `& 'C:\Program Files\Git\cmd\git.exe'` on this machine where Git is installed but absent from this shell's PATH. No remote or publication is configured.
