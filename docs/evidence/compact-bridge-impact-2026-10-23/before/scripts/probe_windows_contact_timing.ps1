param(
    [ValidateSet('direct','events','surfaces','kerbs')][string]$Kind = 'direct',
    [Parameter(Mandatory=$true)][string]$Label
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple capture label.' }
$captureRoot = Join-Path $repoRoot ('build/windows-contact-timing-2026-10-23/' + $Label + '/' + $Kind)
if (Test-Path -LiteralPath $captureRoot) { throw ('Capture already exists: ' + $captureRoot) }
New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
$env:APPDATA = Join-Path $captureRoot 'native-user'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$scripts = @{
    direct = 'res://tests/probe_direct_collision_output.gd'
    events = 'res://tests/probe_contact_audio_output.gd'
    surfaces = 'res://tests/probe_surface_audio_output.gd'
    kerbs = 'res://tests/probe_kerb_contact_output.gd'
}
$dev = Join-Path $repoRoot 'scripts/dev.ps1'
$probe = Join-Path $repoRoot 'build/audio-output-2026-10-09/process-audio-probe.exe'
$arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $dev + '"'),'-Action','TestScript','-ScriptPath',$scripts[$Kind],'-Graphical','-RenderingMethod','gl_compatibility','-TestArgument',('"--output-dir=' + $captureRoot.Replace('\','/') + '"'))
$diagnostic = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $captureRoot 'engine.log') -RedirectStandardError (Join-Path $captureRoot 'engine-error.log')
$null = $diagnostic.Handle
$readyPath = Join-Path $captureRoot 'ready.json'
$deadline = [DateTime]::UtcNow.AddSeconds(40)
while (-not (Test-Path -LiteralPath $readyPath)) {
    if ($diagnostic.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw ('Diagnostic did not become ready: ' + $captureRoot) }
    Start-Sleep -Milliseconds 100
}
$ready = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
& $probe $ready.pid $captureRoot 30
if ($LASTEXITCODE -ne 0) { throw 'Own-process capture failed.' }
if (-not $diagnostic.WaitForExit(10000)) { throw 'Diagnostic did not finish.' }
$diagnostic.Refresh()
if ($diagnostic.ExitCode -ne 0) { throw ('Diagnostic failed: ' + $captureRoot) }
$reviewer = switch ($Kind) {
    'direct' { 'review_direct_collision_output.py' }
    'kerbs' { 'review_kerb_contact_output.py' }
    default { 'review_windows_audio_output.py' }
}
& python (Join-Path $repoRoot ('scripts/' + $reviewer)) $captureRoot
if ($LASTEXITCODE -ne 0) { throw 'Timing review failed.' }
Write-Output ('CAPTURE_ROOT=' + $captureRoot)
