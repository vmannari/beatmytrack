# CIRCUIT / 01 — handling laboratory

Working title from the blueprint. **The driving playground and four handling-test circuits are playable.** Open `game/project.godot` in Godot 4.7.2 and run the project. One original car, the handling yard and four native Slicks-derived practice layouts let us evaluate steering and slide recovery. Handling approval and final art remain pending. See [Slicks import, results and captures](SLICKS_IMPORT.md).

## Drive and tune

| Control | Action |
|---|---|
| W / Up | Accelerator; brakes first when reversing |
| A/D / Left/Right | Steering |
| S / Down / Space | Brake; keep held at rest for 0.35 s to reverse |
| R / Restart button | Immediate reset |
| Escape / Pause button | Pause/resume; focus loss also pauses and releases inputs |
| 1 / 2 / 3 | Stable / Balanced / Loose handling presets |
| F1 | Toggle telemetry |
| F2 / Tune button | Six live handling controls; changing a value resets the car |
| F3 / Record button | Start from a fresh reset, then save quantized inputs and state checkpoints |
| F6 | Reload current preset Resource from disk and reset |
| F5 / Track button | Cycle FREEWAY, 1WAY, 66, OFFROAD and the yard |
| F4 / F7 | Top-down track overview / original-data diagnostic overlays |
| F9 | Toggle conservative AI practice driver and restart |

Touch controls support separate left/right/brake/throttle fingers; mobile hardware testing remains outstanding. Mouse clicks operate the top buttons and tuning panel; the lower driving zones are touch inputs, not mouse pedals. In-game tweaks are temporary. For saved tuning, open `game/resources/balanced.tres` (or another preset) in the Inspector, change its exported fields, save and press F6 in the game. All parameter units and tuning advice are in [the driving guide](docs/DRIVING_PLAYGROUND.md).

Try **Balanced** first: accelerate to roughly 60–80 km/h, turn toward a skid circle, then lift and countersteer. Judge whether the slide is predictable and catchable. Compare **Stable** and **Loose** on the same maneuver; report which you prefer and whether steering feels delayed, too twitchy or difficult to recover.

Open `game/project.godot` with **Godot 4.7.2 standard**, build `4.7.2.stable.official.ed1daf0bf`. The supplied machine has that executable under `C:\apps\Godot 4.7.2\`; its `godot` PATH alias points to an older version. `scripts/dev.ps1` checks the pin before running anything.

## Developer loop (PowerShell, from repository root)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run -Track slicks_freeway_test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Editor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Capture
```

ExecutionPolicy Bypass applies to this invocation only; no machine policy change is needed. `Run`/`Editor` remain attached until the window closes. Override discovery with `-GodotPath 'D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'` or `GODOT_BIN`. Validation imports the project, parses every GDScript, checks main-scene startup and runs the driving and track regression suites, failing on engine script errors even when the process exits zero. Logs and `playground.png` capture go to ignored `build/`.

Compatibility rendering is the initial baseline. The project uses landscape, a 1280×720 logical UI with expanded wider viewports, a fixed 120 Hz simulation and independent input actions. A stable-yaw high-oblique orthographic camera follows the car with bounded look-ahead and separate visual interpolation. Camera extent uses the requested baseline / 1.15 factor; exact reference matching and physical-phone safe-area approval remain future checks. Matte toon materials and simple original geometry are handling stand-ins, not final art.

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
