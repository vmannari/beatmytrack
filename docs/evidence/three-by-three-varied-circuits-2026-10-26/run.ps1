param([ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='gl_compatibility',[switch]$Import,[ValidateSet('full','poster','previous')][string]$Probe='poster')
$ErrorActionPreference='Stop'
$posterRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$posterLabel=if ($Import) {'import'} elseif ($Probe -eq 'full') {$Mode} else {"$Probe-$Mode"}
$posterOutput=Join-Path $PSScriptRoot $posterLabel
New-Item -ItemType Directory -Force -Path $posterOutput | Out-Null
$env:APPDATA=Join-Path $posterRepo "build/three-by-three-varied-circuits-2026-10-26/$posterLabel/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:BMT_CHALLENGE_CAPTURE_DIR=Join-Path $posterOutput 'captures'
$posterScript='res://tests/test_challenge_cards.gd'
$posterTemporary=''
$posterArchive=''
if (-not $Import -and $Probe -ne 'full') {
    $posterScript="res://tests/capture_three_by_three_$Probe.gd"
    $posterTemporary=Join-Path $posterRepo "game/tests/capture_three_by_three_$Probe.gd"
    $posterArchive=Join-Path $PSScriptRoot "capture_$Probe.gd"
    if (Test-Path -LiteralPath $posterTemporary) {throw "Capture path already exists: $posterTemporary"}
    Copy-Item -LiteralPath $posterArchive -Destination $posterTemporary
}
$posterArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $posterRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',$posterScript,'-CommandTimeoutSeconds','180')
if ($Import) {$posterArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $posterRepo 'scripts/dev.ps1'),'-Action','Import','-CommandTimeoutSeconds','120')}
elseif ($Mode -ne 'headless') {$posterArgs+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$posterStarted=[DateTime]::UtcNow
try {
    & powershell @posterArgs *> (Join-Path $posterOutput 'console.log')
    $posterExit=$LASTEXITCODE
} finally {
    if ($posterTemporary -and (Test-Path -LiteralPath $posterTemporary) -and ((Get-FileHash -LiteralPath $posterTemporary).Hash -eq (Get-FileHash -LiteralPath $posterArchive).Hash)) {
        Remove-Item -LiteralPath $posterTemporary
    }
}
@{arguments=$posterArgs;exit_code=$posterExit;started_utc=$posterStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$posterStarted).TotalSeconds}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $posterOutput 'command.json')
Get-Content -LiteralPath (Join-Path $posterOutput 'console.log') -Tail 14
exit $posterExit
