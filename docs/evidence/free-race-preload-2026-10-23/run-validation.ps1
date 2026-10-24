$ErrorActionPreference = 'Stop'
$env:APPDATA = Join-Path (Get-Location) 'build/free-race-preload-user'
$env:BMT_DISCOVERY_EVIDENCE_DIR = Join-Path (Get-Location) 'docs/evidence/free-race-preload-2026-10-23/captures'
$logDirectory = Join-Path (Get-Location) 'docs/evidence/free-race-preload-2026-10-23/logs'
$cases = @(
    @{Name='focused-headless'; Script='test_free_race_preload.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='focused-compatibility'; Script='test_free_race_preload.gd'; Graphical=$true; Renderer='gl_compatibility'},
    @{Name='focused-mobile'; Script='test_free_race_preload.gd'; Graphical=$true; Renderer='mobile'},
    @{Name='discovery-windows'; Script='test_discovery_windows.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='discovery-pages'; Script='test_discovery_pages.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='free-race-list'; Script='test_free_race_list.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='challenges'; Script='test_challenges.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='app'; Script='test_app.gd'; Graphical=$false; Renderer='gl_compatibility'},
    @{Name='parser'; Script='test_script_parse.gd'; Graphical=$false; Renderer='gl_compatibility'}
)
foreach ($case in $cases) {
    $testParameters = @{Action='TestScript'; ScriptPath=('res://tests/'+$case.Script); RenderingMethod=$case.Renderer; Graphical=$case.Graphical}
    if ($case.Name -eq "free-race-list") { $testParameters.TestArgument = @("--evidence-root="+(Join-Path (Get-Location) "docs/evidence/free-race-preload-2026-10-23/free-race-list")) }
    & ./scripts/dev.ps1 @testParameters
    $testExit = $LASTEXITCODE
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logDirectory ($case.Name+'.log'))
    if ($testExit -ne 0) { throw "Validation failed: $($case.Name), exit $testExit" }
}
