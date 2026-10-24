param([switch]$Graphical,[switch]$Baseline,[string]$RenderingMethod='gl_compatibility',[string[]]$Checks=@('test_complete_contact_outline'),[string[]]$ExtraArgument=@())
$ErrorActionPreference='Stop'
$repoRoot=[System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$env:APPDATA=Join-Path $PSScriptRoot ('checks-user-'+$PID)
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
foreach($check in $Checks) {
    $arguments=@{Action='TestScript';ScriptPath=('res://tests/'+$check+'.gd');RenderingMethod=$RenderingMethod;Graphical=$Graphical}
    $arguments.TestArgument=@($ExtraArgument)
    if($Baseline){$arguments.TestArgument+=@('--baseline')}
    & (Join-Path $repoRoot 'scripts/dev.ps1') @arguments
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
}
