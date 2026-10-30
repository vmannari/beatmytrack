param([ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='headless')
$ErrorActionPreference='Stop'
$paletteRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$paletteOutput=Join-Path $PSScriptRoot $Mode
New-Item -ItemType Directory -Force -Path $paletteOutput | Out-Null
$env:APPDATA=Join-Path $paletteRepo "build/customisation-extra-colours-2026-10-26/$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$paletteScript='res://tests/test_customisation_carousel.gd'
$paletteScratch=Join-Path $paletteRepo 'game/tests/_review_extra_colours.gd'
if ($Mode -ne 'headless') {
    if (Test-Path -LiteralPath $paletteScratch) {throw 'Review scratch script already exists.'}
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'capture.gd') -Destination $paletteScratch
    $paletteScript='res://tests/_review_extra_colours.gd'
}
$paletteArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $paletteRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',$paletteScript,'-CommandTimeoutSeconds','180','-TestArgument',"--evidence-root=$paletteOutput")
if ($Mode -ne 'headless') {$paletteArgs+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$paletteStarted=[DateTime]::UtcNow
try {
    & powershell @paletteArgs *> (Join-Path $paletteOutput 'console.log')
    $paletteCode=$LASTEXITCODE
    @{arguments=$paletteArgs;exit_code=$paletteCode;started_utc=$paletteStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$paletteStarted).TotalSeconds}|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $paletteOutput 'command.json')
    Get-Content (Join-Path $paletteOutput 'console.log') -Tail 24
} finally {
    if ($Mode -ne 'headless') {
        Remove-Item -LiteralPath $paletteScratch -Force
        if (Test-Path -LiteralPath ($paletteScratch+'.uid')) {Remove-Item -LiteralPath ($paletteScratch+'.uid') -Force}
    }
}
exit $paletteCode
