# Race Friends button removal — 2026-10-25

RFB01 / R01 / G01 / Q01: Remove the disabled Friends button from the Race page. The shared `game/ui/race_mode_rail.gd` now creates only Weekly Rivalry, Free race and Challenges, including the stationary rail used during transitions. This is a one-line runtime change.

Verification used pinned Godot `4.7.2.stable.official.ed1daf0bf` and the existing native mouse/touch navigation check, with disposable local records and the remote API disabled. Its [input report](evidence/race-friends-button-2026-10-25/input.json) records **62 checks, zero failures**, including captures at 1280×720 and 960×540. Both Free Race captures were inspected: the three remaining buttons fit and Friends is absent. The empty track list belongs to the isolated offline fixture.

Actual commands (repository root, PowerShell):

```powershell
$env:BMT_RACE_MODE_INPUT_OUTPUT = Join-Path (Get-Location) 'docs/evidence/race-friends-button-2026-10-25'
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_mode_input.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
git diff --check -- game/ui/race_mode_rail.gd
```

The initial direct `./scripts/dev.ps1` invocation was refused by the host execution policy before running. The process-scoped invocation above returned exit 1 with sandbox diagnostics about the default `user://` log path; the engine also reported a root-certificate-store read error in the runner log. The native test nevertheless wrote its complete zero-failure report and five screenshots. This is not a clean runner pass. The source diff whitespace check passed.

Captures: [Race 1280×720](evidence/race-friends-button-2026-10-25/free-race-1280x720.png), [Race 960×540](evidence/race-friends-button-2026-10-25/free-race-960x540.png), plus Rivalry views in the same evidence directory. [Task-only Git patch](evidence/race-friends-button-2026-10-25/checkpoint.patch) contains only the runtime change; concurrent workspace edits were excluded. The development entry point also regenerates the existing generated build identity.

Client reload and owner appearance acceptance remain. No device attachment check or physical-device test, APK export, deployment, or owner-process restart was performed.
