param([ValidateSet('before','after')][string]$Phase='before')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
$captureRoot=[System.IO.Path]::GetFullPath((Join-Path $repoRoot ('build/snow-audio-response-2026-10-22/'+$Phase)))
$allowedRoot=[System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build/snow-audio-response-2026-10-22'))
if (-not $captureRoot.StartsWith($allowedRoot+[System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Capture folder escaped task storage.' }
New-Item -ItemType Directory -Force -Path $captureRoot | Out-Null
foreach ($name in @('ready.json','armed','events.json','loopback.pcm','packets.csv','capture-meta.txt')) {
    $old=Join-Path $captureRoot $name
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
}
$probe=Join-Path $repoRoot 'build/audio-output-2026-10-09/process-audio-probe.exe'
if (-not (Test-Path -LiteralPath $probe)) { throw 'Existing own-process audio probe is unavailable.' }
$dev=Join-Path $repoRoot 'scripts/dev.ps1'
$arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$dev+'"'),'-Action','TestScript','-ScriptPath','res://tests/probe_contact_audio_output.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument',('--output-dir=res://../build/snow-audio-response-2026-10-22/'+$Phase))
$game=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $captureRoot 'engine.log') -RedirectStandardError (Join-Path $captureRoot 'engine-error.log')
$null=$game.Handle # Retain the Windows process handle so ExitCode survives exit.
$readyPath=Join-Path $captureRoot 'ready.json'
$deadline=[DateTime]::UtcNow.AddSeconds(25)
while (-not (Test-Path -LiteralPath $readyPath)) {
    if ($game.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw ('Probe did not become ready; see '+$captureRoot) }
    Start-Sleep -Milliseconds 100
}
$ready=Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
& $probe $ready.pid $captureRoot 19
if ($LASTEXITCODE -ne 0) { throw 'Own-process loopback capture failed.' }
if (-not $game.WaitForExit(10000)) { throw 'Probe did not finish.' }
$game.Refresh()
if ($game.ExitCode -ne 0) { throw 'Diagnostic game failed; see engine log.' }
& python (Join-Path $repoRoot 'scripts/review_windows_audio_output.py') $captureRoot
if ($LASTEXITCODE -ne 0) { throw 'Timing review failed.' }
