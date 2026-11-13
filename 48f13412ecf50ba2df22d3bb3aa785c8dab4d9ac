# Desert rally dust - 2026-10-25

DRD01: Interpret the owner's Rush Rally reference as a grounded rally wake with softer, textured cloud edges and a transparent older trail. This is a first local visual iteration, pending owner acceptance; no Rush Rally assets were copied. Reference discovery included the developer's particle-update page: https://www.rushrally.co.uk/blog/2022/013_rr3_4k/index.html . No exact shot-for-shot fidelity claim.

DRD02: `game/vehicle/sand_dust.gd` versions the presentation to desert-dust-22. Desert-only cloud and tyre materials use the existing puff texture to vary edge radius and density. Old clouds fade much earlier; maximum growth falls from 2.5 to 1.9, upward acceleration halves, and initial maximum velocity falls from 2.2 to 1.8. Quick initial wake fill, nine-second total lifetime, 64 lingering/48 contact particles per wheel, bridge clipping, physical-height occlusion, surface contacts and canonical simulation remain. No new texture samples or emitters. Other biomes keep their previous shader branch.

DRD03: `game/tests/capture_desert_rally_dust.gd` captures a fixed-document route at 1600x900, with stopped-emission fade and unchanged-state assertion. `--before` reloads the exact task-start source into isolated process memory only. `check_desert_dust_depth_baseline.gd` uses the same approach to rerun the existing depth assertions. Random particle state and wall-clock frame scheduling are not identical; these are matched route/scene witnesses, not pixel-exact or performance comparisons.

R01: Existing Desert tests: 91 checks, zero failures. Existing bridge dust: 121 checks, zero failures in Compatibility and desktop Mobile. Existing depth test is not fully green: the task-start source itself has four zero-tolerance roof-edge failures, reproduced in isolation. Initial smaller-card revision had seven depth failures; restoring the base footprint reduced that to five, including insufficient pickup-side coverage, prompting the final density adjustment. Initial parameter revision also failed five Desert assertions; all were restored without changing those assertions. Final depth: 43 checks, the same four roof-edge failures as baseline; pickup coverage is restored (449 pixels, required >100). No new failing assertions. Logs are recorded in report.json.

Q01: No existing test assertions were edited. Initial legacy capture failed its unrelated old sand-bank geometry assertion on the isolated fallback track. It is retained as a diagnostic; the dedicated fixed-document capture replaces it. PowerShell execution policy required process-only `-ExecutionPolicy Bypass`; sandbox user-log access required a task-local APPDATA. Windows certificate-store access still reports an error and makes the launcher return 1 even when native assertions finish; native logs, not launcher exit alone, identify outcomes. Heavy desktop capture hitches are recorded, so there is no frame-rate improvement claim.

Commands use the pinned engine through `scripts/dev.ps1`:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/desert-rally-dust-final-tests'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert.gd
# Distinct task-local APPDATA folders for each following process.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_dust.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_dust.gd -Graphical -RenderingMethod mobile
# For array arguments, invoked with -Command and @() rather than -File:
./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dust_depth.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--output=res://../docs/evidence/desert-rally-dust-2026-10-25/depth-accepted') -CommandTimeoutSeconds 240
./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/check_desert_dust_depth_baseline.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--output=res://../docs/evidence/desert-rally-dust-2026-10-25/depth-baseline') -CommandTimeoutSeconds 240
./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_desert_rally_dust.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--before') -CommandTimeoutSeconds 120
./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_desert_rally_dust.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
```

Evidence: `docs/evidence/desert-rally-dust-2026-10-25/matched/{before,after}/{driving,fade}.png`, immutable task-start source, native logs, hashes and scoped patch. Screenshots under `review` and the initial `before` folder used different track selection and are not a matched comparison. Intermediate depth captures remain recorded.

Remaining: owner driving/appearance review, real-phone frame pacing/thermal cost, and the pre-existing roof-edge test issue. No device attachment check or device test was performed. No APK, deployment, live mutation, purchase or owner-process restart. Concurrent changes are preserved.
