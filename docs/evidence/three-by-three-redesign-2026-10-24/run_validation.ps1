param(
    [ValidateSet('import','test_challenge_entry','test_challenge_cards')][string]$Test = 'test_challenge_cards',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$celRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $celRepo "build/three-by-three-redesign-2026-10-24/$Test-$Mode/appdata"
$env:BMT_API_URL = ''
$env:BMT_CHALLENGE_CAPTURE_DIR = $PSScriptRoot
$env:BMT_CHALLENGE_ENTRY_OUTPUT = $PSScriptRoot
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$celEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$celVersion = (& $celEngine --version).Trim()
if ($celVersion -ne (Get-Content -LiteralPath (Join-Path $celRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$celArgs = @('--path', (Join-Path $celRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--audio-driver','Dummy')
if ($Test -eq 'import') { $celArgs += @('--headless','--editor','--import') }
else {
    $celArgs += @('--script', "res://tests/$Test.gd")
    if ($Mode -eq 'headless') { $celArgs += '--headless' }
    else { $celArgs += @('--rendering-method',$Mode,'--max-fps','60') }
    if ($Mode -eq 'mobile') { $celArgs += @('--rendering-driver','vulkan') }
}
& $celEngine @celArgs
exit $LASTEXITCODE
