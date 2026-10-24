param([ValidateSet('before','after')][string]$Phase='before',[switch]$Controls)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
$label=if ($Controls) { 'controls' } else { $Phase }
$captureRoot=[System.IO.Path]::GetFullPath((Join-Path $repoRoot ('build/surface-audio-latency-2026-10-23/'+$label)))
$allowedRoot=[System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build/surface-audio-latency-2026-10-23'))
if (-not $captureRoot.StartsWith($allowedRoot+[System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Capture folder escaped task storage.' }
New-Item -ItemType Directory -Force -Path $captureRoot | Out-Null
foreach ($name in @('ready.json','armed','events.json','loopback.pcm','packets.csv','capture-meta.txt')) {
    $old=Join-Path $captureRoot $name
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
}
$probe=Join-Path $repoRoot 'build/audio-output-2026-10-09/process-audio-probe.exe'
$dev=Join-Path $repoRoot 'scripts/dev.ps1'
$script=if ($Controls) { 'res://tests/probe_mixed_audio_output.gd' } else { 'res://tests/probe_surface_audio_output.gd' }
$arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$dev+'"'),'-Action','TestScript','-ScriptPath',$script,'-Graphical','-RenderingMethod','gl_compatibility','-TestArgument',('--output-dir=res://../build/surface-audio-latency-2026-10-23/'+$label))
$game=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $captureRoot 'engine.log') -RedirectStandardError (Join-Path $captureRoot 'engine-error.log')
$null=$game.Handle
$readyPath=Join-Path $captureRoot 'ready.json'
$deadline=[DateTime]::UtcNow.AddSeconds(25)
while (-not (Test-Path -LiteralPath $readyPath)) {
    if ($game.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw ('Probe did not become ready; see '+$captureRoot) }
    Start-Sleep -Milliseconds 100
}
$ready=Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
$duration=if ($Controls) { 38 } else { 22 }
& $probe $ready.pid $captureRoot $duration
if ($LASTEXITCODE -ne 0) { throw 'Own-process loopback capture failed.' }
if (-not $game.WaitForExit(10000)) { throw 'Probe did not finish.' }
$game.Refresh()
if ($game.ExitCode -ne 0) { throw 'Diagnostic game failed.' }
if ($Controls) { & python (Join-Path $repoRoot 'scripts/review_mixed_audio_output.py') $captureRoot }
else { & python (Join-Path $repoRoot 'scripts/review_windows_audio_output.py') $captureRoot }
if ($LASTEXITCODE -ne 0) { throw 'Timing review failed.' }
