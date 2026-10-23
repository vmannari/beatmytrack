$ErrorActionPreference = 'Stop'
$evidenceDir = Join-Path (Get-Location) 'docs/evidence/garage-wash-easier-2026-10-19'
New-Item -ItemType Directory -Force -Path (Join-Path $evidenceDir 'logs') | Out-Null
$checks = @(
    @{Name='easier-headless'; Script='test_garage_wash_easier.gd'},
    @{Name='surfaces'; Script='test_garage_wash_surfaces.gd'},
    @{Name='scrubbing'; Script='test_gentle_scrubbing.gd'},
    @{Name='existing-wash'; Script='test_car_wash.gd'; Renderer='gl_compatibility'; Driver='opengl3'; Argument='--evidence-root=res://../docs/evidence/garage-wash-easier-2026-10-19/regressions'},
    @{Name='easier-compatibility'; Script='test_garage_wash_easier.gd'; Renderer='gl_compatibility'; Driver='opengl3'},
    @{Name='easier-mobile'; Script='test_garage_wash_easier.gd'; Renderer='mobile'; Driver='vulkan'},
    @{Name='customisation-compatibility'; Script='test_garage_clean_customisation.gd'; Renderer='gl_compatibility'; Driver='opengl3'},
    @{Name='customisation-mobile'; Script='test_garage_clean_customisation.gd'; Renderer='mobile'; Driver='vulkan'},
    @{Name='owner-after-compatibility'; Script='inspect_wash_residue.gd'; Renderer='gl_compatibility'; Driver='opengl3'; Argument='--output=res://../docs/evidence/garage-wash-easier-2026-10-19/owner-after-compatibility'},
    @{Name='owner-after-mobile'; Script='inspect_wash_residue.gd'; Renderer='mobile'; Driver='vulkan'; Argument='--output=res://../docs/evidence/garage-wash-easier-2026-10-19/owner-after-mobile'},
    @{Name='parser'; Script='test_script_parse.gd'}
)
$receipts = @()
foreach ($testCase in $checks) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',('res://tests/'+$testCase.Script),'-CommandTimeoutSeconds','240')
    if ($testCase.ContainsKey('Renderer')) { $arguments += @('-Graphical','-RenderingMethod',$testCase.Renderer,'-RenderingDriver',$testCase.Driver) }
    if ($testCase.ContainsKey('Argument')) { $arguments += @('-TestArgument',$testCase.Argument) }
    $testLog = Join-Path $evidenceDir ('logs/'+$testCase.Name+'.log')
    & powershell @arguments 2>&1 | Tee-Object -FilePath $testLog
    $testExit = $LASTEXITCODE
    $receipts += @{name=$testCase.Name; exit_code=$testExit; arguments=$arguments}
    $receipts | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'commands.json') -Encoding UTF8
    if ($testExit -ne 0) { throw ($testCase.Name+' failed; log retained') }
}
