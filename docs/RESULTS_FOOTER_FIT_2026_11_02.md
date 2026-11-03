# Race completion footer fits (2026-11-02)

RFF01: Keep Results, Tracks and Race selected track fully inside the screen with their existing 60 logical pixel minimum height. RFF02: Preserve access to rewards, standings, rating and recommendations when space is constrained.

`game/ui/race_complete.gd` reserves the header and action row outside a vertically expanding ScrollContainer. Rewards, standings and recommendations retain their layout inside its expanding content; excess height scrolls, including keyboard focus following. No results, reward, recommendation or navigation contracts change.

`game/tests/test_results_footer_fit.gd` exercises the actual menu theme, rating row and three recommendations at 1280×683 (owner screenshot aspect), 1280×720, 960×540, 1920×1080 and 1600×720. It checks every footer button against the logical stretched canvas, minimum touch height, stationary footer during scrolling, reachable recommendation cards and selection caption. `game/tests/test_race_results.gd` also gains the screenshot aspect and explicit action bounds checks.

Validation:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/results-footer-test/fit-userdata'
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_results_footer_fit.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--capture') -CommandTimeoutSeconds 120"
```

Pinned Godot 4.7.2, native Compatibility: **51 checks, 0 failures**, five captures. Log: `build/logs/TestScript-18592/test-script.log`. [Screenshot at owner aspect](evidence/results-footer-2026-11-02/footer-1280x683.png). All captures are under `docs/evidence/results-footer-2026-11-02/`.

The initial focused run incorrectly compared logical canvas bounds with physical window pixels and omitted the application theme: 51 checks, 8 failures. Corrected the fixture to use `root.get_visible_rect()` and `MenuStyle.theme()`; assertions retain all button checks. The initial native capture and log remain recorded in `build/logs/TestScript-30440/test-script.log` (captures refreshed by final run).

The broader existing `test_race_results.gd` native capture stopped before reaching Race Complete with `Lambda capture at index 0 was freed. Passed "null" instead.` (exit 1, `build/logs/TestScript-8776/test-script.log`); it is not reported as passing. Initial direct PowerShell execution was blocked by execution policy; explicit process-scoped Bypass was used. Sandbox launches stalled on log/certificate-store access; successful native runs used normal Windows access and isolated APPDATA. The dev wrapper suppresses crash dialogs for its own test child only.

No device test, deployment, owner save or owner process change was performed. Owner appearance/input acceptance after reload remains. Concurrent workspace changes and build-identity regeneration are outside this change. Task source patch: `docs/evidence/results-footer-2026-11-02/source.patch`; no main-index writes.
