# Race pause-menu label fit — 2026-10-25

RPL01–RPL02 / R01 / Q01: The owner confirms that Resume, Restart and Settings in the in-race pause menu overflow on the tablet. `game/ui/race_pause_menu.gd` now sizes each button from its padded native content. Titles can wrap; the title/subtitle gap is two logical units, with ten units of vertical padding. Font fallback and wrapped subtitles update the button's minimum height. The existing scroll drawer accommodates taller rows, and all content containers pass pointer events through to the native button.

The old fixed 70-unit rows did not account for their child containers. With the actual bundled font fallbacks, even single-line English rows used 69 units for text and its inherited gap, leaving almost no padding. The parking-hall Restart subtitle wraps and exposes actual overflow. The revised single-line rows are 79 units tall with the current fonts. No gameplay, pausing, action, camera, icon or shared theme behavior changes.

Changed runtime: `game/ui/race_pause_menu.gd`. Added regression: `game/tests/test_race_menu_label_fit.gd` and its UID. Documentation: this file and the task records prepended to `AGENTS.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Verification uses pinned Godot `4.7.2.stable.official.ed1daf0bf`, isolated workspace-owned user data, logical sizes 1280×914 (tablet 7:5), 1024×768, 1280×720 and 960×540, and English, Finnish, German, Japanese and Korean font/translation configuration:

- Final native layout, padding, wrapped parking-hall subtitle, Help Back and actual Resume text tap: **624 checks, zero failures** in Compatibility and **624 checks, zero failures** in desktop Mobile/Vulkan. Both runners exit 0.
- Existing actual-Game pause integration: **17 checks, zero failures**, including frozen race presentation, Settings, Resume and compact layout. Runner exits 0. Its isolated startup records a desktop first-frame hitch; this task makes no performance claim.
- Whole-project parser: **1184 scripts, zero failures**, runner exits 0.
- Task diff whitespace and reverse-application checkpoint checks pass.

The initial containment-only probe passed 305 checks and was insufficient to establish padding. The expanded original-source regression retains **620 checks with 203 failures**, covering missing padding and the genuinely wrapped subtitle. Those assertions remain in the final test; four action/Help checks were then added. Original runtime is retained at [source-before/race_pause_menu.gd.txt](evidence/race-menu-label-fit-2026-10-25/source-before/race_pause_menu.gd.txt). Initial sandbox runners also exited 1 because Godot could not read the Windows root certificate store, despite writing complete layout reports. Final runs with certificate-store access exit cleanly; the first such invocation also printed the host PowerShell profile execution-policy diagnostic, corrected by subsequent `login:false` execution.

Actual commands, from the repository root (PowerShell):

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/race-menu-label-fit/user'
# Initial probes used before, regression-before and after-compatibility output folders.
$env:BMT_RACE_MENU_LABEL_OUTPUT = Join-Path (Get-Location) 'docs/evidence/race-menu-label-fit-2026-10-25/final-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_menu_label_fit.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_pause_menu.gd -Graphical -RenderingMethod gl_compatibility -TestArgument evidence=res://../docs/evidence/race-menu-label-fit-2026-10-25/integration -CommandTimeoutSeconds 120

$env:BMT_RACE_MENU_LABEL_OUTPUT = Join-Path (Get-Location) 'docs/evidence/race-menu-label-fit-2026-10-25/final-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_menu_label_fit.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/ui/race_pause_menu.gd game/tests/test_race_menu_label_fit.gd
git apply --check --reverse docs/evidence/race-menu-label-fit-2026-10-25/checkpoint.patch
```

Evidence: [report](evidence/race-menu-label-fit-2026-10-25/report.json), [before](evidence/race-menu-label-fit-2026-10-25/before/pause-en-1280x914.png), [after](evidence/race-menu-label-fit-2026-10-25/final-compatibility/pause-en-1280x914.png), [actual paused race](evidence/race-menu-label-fit-2026-10-25/integration/1280x720.png), and [task-only checkpoint](evidence/race-menu-label-fit-2026-10-25/checkpoint.patch). Other language and renderer captures accompany the reports. The development entry point regenerates the existing generated client identity; that is outside the task checkpoint. Concurrent work is preserved.

Client reload and owner acceptance on the physical tablet remain. No device attachment check, device test, APK export/install, deployment or owner-process restart was performed.
