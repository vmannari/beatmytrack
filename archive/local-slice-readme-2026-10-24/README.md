# Beat My Track

An overhead racing game and track creator built with Godot. The project includes
Free Race, Weekly Rivalry, challenges, a Garage, local track editing and optional
account-backed publication and verified results. Start with the
[documentation index](docs/README.md) for current guides and implementation evidence.

Use **Godot 4.7.2 standard**, build `4.7.2.stable.official.ed1daf0bf`, pinned in
[godot-version.txt](godot-version.txt). Open `game/project.godot` or use the wrapper
below; it checks the pin. `GODOT_BIN` or `-GodotPath` overrides executable discovery.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Editor
```

Startup restores the saved session. A profile-ready account enters Race; otherwise
the account screen offers sign-in or Guest play. Published tracks require a reachable
service or previously downloaded content. The shipping built-in catalogue contains
**Starter Circuit**; the retired Slicks collection is retained in diagnostic fixtures.
Local files and cached tracks support offline play. See the
[menu and creator guide](docs/MENUS_AND_CREATOR.md).

Ordinary races use a standing countdown and **five laps**. Editor practice and the
Garage parking hall are untimed. Five cars are available: Compact, Pick-up, Classic
Sports, Formula and Go-kart. Local results and personal bests are distinct from
server-verified competitive results. There is no paid ordinary-racing or local-draft
quota; hosted publication has separate account entitlements.

| Keyboard control | Action |
|---|---|
| W / Up | Accelerator |
| A / D / Left / Right | Steering |
| S / Down | Brake; hold at rest to reverse |
| Space | Handbrake |
| R | Restart |
| Escape | Pause |

Touch settings offer button and analog steering layouts, handedness and sizing.
Button presses follow each finger's current position, including slide entry and
transfers. See [touch slide behavior](docs/TOUCH_SLIDE_ACTIVATION_2026_10_23.md) and
[camera options](docs/CAMERA_OPTIONS.md). The simulation runs at 120 Hz, independently
of presentation. Compatibility is the configured default renderer; desktop Mobile
checks and physical-device measurements have separate evidence.

## Development and verification

Run commands from the repository root:

```powershell
# Focused import, startup, driving, catalogue and menu checks:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Validate -QuickValidation
# Broader regression gate (stops on its first failed command):
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Validate
# One focused suite; add -Graphical and -RenderingMethod when needed:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd
```

The wrapper writes logs to ignored `build/logs/<Action>-<PID>/` and rejects script
errors as well as nonzero exits. A focused pass does not imply the broader gate
passes. Actual outcomes, retained failures and acceptance limits are recorded in
[development status](DEVELOPMENT_STATUS.md) and the linked dated reports.

For a diagnostic drive, use `-Action Run -Track starter_circuit`. F2/F3/F5/F6/F9
tuning, recording, track cycling, preset reload and AI controls belong to this direct
mode. See [driving diagnostics](docs/DRIVING_PLAYGROUND.md).

## Backend and Android

The Python API, PostgreSQL database, object storage and canonical verification workers
live under `backend/`. See [backend setup](backend/README.md),
[account setup](docs/ACCOUNT_SIGN_IN.md) and [deployment operations](backend/deploy/README.md).
Local source features and a recorded deployed artifact can differ; the
[latest recorded backend release](docs/LATEST_BACKEND_DEPLOY_2026_10_23.md) identifies
the deployed schema and digest. Store presentation and debug purchase simulation
exist; production billing is not connected.

The `Android Debug` preset uses Gradle, minimum Android API 24, ARM64 and x86_64,
package `org.circuit01.handlinglab`, and output `build/android/circuit01-debug.apk`.
Network permissions and native platform adapters are configured. Android tooling,
exports and physical deployments have been used; build-specific receipts and setup
instructions are in [the Android guide](docs/ANDROID.md). New source changes still
need matching builds and owner/device acceptance.

## Repository contract

`game/` is the Godot resource root. `Android_racing_game_blueprint_v2/` preserves the
original proposal and references outside exports; later owner decisions and current
code supersede its historical defaults. See [agent instructions](AGENTS.md),
[the original plan and subsequent checkpoints](docs/PHASE_0_PLAN.md), and
[asset provenance](licenses/ASSETS.md). Keep credentials, signing material, player data
and generated build artifacts outside committed source.
