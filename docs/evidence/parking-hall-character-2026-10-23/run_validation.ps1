$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location -LiteralPath $taskRepo
$env:APPDATA = Join-Path $taskRepo 'build/parking-hall-character/final-userdata'
$taskRuns = @(
    @{ name='focused-headless'; script='test_parking_hall'; args=@() },
    @{ name='focused-compatibility'; script='test_parking_hall'; args=@('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/parking-hall-character-2026-10-23/captures/compatibility') },
    @{ name='focused-mobile'; script='test_parking_hall'; args=@('-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/parking-hall-character-2026-10-23/captures/mobile') },
    @{ name='app'; script='test_app'; args=@() },
    @{ name='parser'; script='test_script_parse'; args=@() }
)
foreach ($taskRun in $taskRuns) {
    $taskArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',"res://tests/$($taskRun.script).gd",'-CommandTimeoutSeconds','300') + $taskRun.args
    & powershell @taskArguments | Tee-Object -FilePath "docs/evidence/parking-hall-character-2026-10-23/logs/$($taskRun.name).log"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
