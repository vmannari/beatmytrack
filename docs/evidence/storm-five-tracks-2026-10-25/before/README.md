# Beat my track

The electric car's [smooth nose correction](docs/ELECTRIC_SMOOTH_NOSE_2026_10_25.md) gives the hood, light brow and bumper a continuous curved profile. Matched side views and actual mesh measurements are linked in the report.

Beat my track is a Godot racing game and local track editor for Windows and Android.
Ordinary races have five laps and five fictional cars: Compact, Pickup, Classic,
Formula and Kart. The app includes Free Race discovery, local creation and untimed
practice, verified online results, Weekly Rivalry, Challenges and a Garage with
appearance customisation and a parking-hall test drive.

The current World Ranking implementation is prospective: launch and matching
client, API and worker rollout are separate from running this checkout. Backend
and provider configuration determine which online services are available.

## Run the project

Open `game/project.godot`, or use the repository entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Editor
```

Use the exact engine in [godot-version.txt](godot-version.txt), currently
`4.7.2.stable.official.ed1daf0bf`, and matching export templates. The development
script verifies the version and generates the client build identity. Set
`GODOT_BIN` or pass `-GodotPath` when the pinned console executable is elsewhere;
the machine's older `godot` alias is unsuitable. Native extension descriptors
under `game/platform/` select the Windows libraries used by this checkout.

The ordinary keyboard controls are W/Up for accelerator, A/D or Left/Right for
steering, S/Down for brake, Space for handbrake, R for reset and Escape for pause.
Touch supports independent fingers, slide activation and configurable buttons,
analog slider or joystick steering. Camera, control and sound settings are in
the app. Garage test driving is untimed and does not award race records.

## Local tracks and saves

The shipping built-in catalog contains the original Ellipse. Published
online tracks are discovered from the configured backend; the historical Slicks
collection is retained only as excluded regression fixtures.

Creator import accepts `creator-track-v5`; prepared native tracks use
`surface-grid-v2`. Older creator formats and the retired Coast alias are rejected.
Existing owner files are preserved. Local PBs, paint, controls and other supported
settings upgrade at the persistence boundary and commit through atomic saves.
Pending result uploads and publication journals remain recoverable.

See [creator workflow](docs/WIREFRAME_EDITOR.md),
[current import policy](docs/EDITOR_T11_T15_2026_10_23.md),
[Garage test drive](docs/PARKING_HALL_2026_10_23.md) and
[slide controls](docs/TOUCH_SLIDE_ACTIVATION_2026_10_23.md).

## Backend

[Backend setup](backend/README.md) covers authentication, immutable publication,
trajectory verification, deployment configuration and local development services.
The current client requires discovery v3 and trajectory verification; it retains
cached/local play when a matching online service is unavailable. Recovering
pre-update upload replies additionally requires submission recovery version 1.

Production Studio access uses configured named staff identities and verified MFA.
Shared diagnostic keys are disabled by default and forbidden in production.
Development authentication and artificial populations remain explicitly gated.
Never commit credentials, provider keys or signing secrets.

## Verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestControlLayout
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_legacy_cleanup.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BackendTest
```

Use isolated test user data for app-level tests. Command logs go under `build/`.
[Development status](DEVELOPMENT_STATUS.md), [agent instructions](AGENTS.md) and
the dated evidence under `docs/evidence/` record actual test results and remaining
owner/device acceptance. Desktop checks do not establish physical-device FPS or
appearance acceptance.

## Android

[Android setup](docs/ANDROID.md) covers SDK/JDK/templates and device commands.
The Android preset uses Gradle, Android API 24 minimum, arm64 and x86_64, and
network permission for online services. Builds have previously been installed
on the owner's phone and tablet; that does not certify every current source change.
Export, installation and physical-device testing are separate actions.

The installed package remains `org.circuit01.handlinglab`; changing that identity
would separate existing application data. Development commands generate APKs
under `build/android/`. No device installation or production deployment is implied
by editing this checkout.

## Repository and native artifacts

`game/` is the Godot resource root. Backend code, the original blueprint, archived
references and task evidence stay outside it. Tests and offline verifier entry
points are excluded from Android export. [Asset provenance](licenses/ASSETS.md)
and native license notices must accompany their respective shipped assets.

Native build scripts retain the descriptor-selected libraries and any generation
loaded by a running Godot process. Other Windows DLLs can be archived, with hash
verification, outside the resource root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/archive_native_libraries.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/archive_native_libraries.ps1 -Archive
```

The first command is a dry run. Incomplete process inspection prevents archiving;
running game/editor processes are never stopped. Archives preserve rollback bytes.
The superseded local-slice guide is preserved in
[the documentation archive](archive/local-slice-readme-2026-10-24/README.md).
