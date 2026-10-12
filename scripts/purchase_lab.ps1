[CmdletBinding()]
param(
    [ValidateSet('Start','Run','Stop','Admin')][string]$Action = 'Run',
    [ValidateRange(1024,65535)][int]$Port = 18182,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$labFolder = Join-Path $taskRoot 'build/purchase-lab'
$python = Join-Path $taskRoot '.tools/backend-venv/Scripts/python.exe'
$godot = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pidFile = Join-Path $labFolder 'server.pid'
$keyFile = Join-Path $labFolder 'development.key'
$workerFile = Join-Path $labFolder 'worker.pid'
New-Item -ItemType Directory -Path $labFolder -Force | Out-Null
$owned = $null
if (Test-Path -LiteralPath $pidFile) {
    $labPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$labPid" -ErrorAction SilentlyContinue
    if ($candidate) {
        if ($candidate.ExecutablePath -ne $python -or $candidate.CommandLine -notlike '*bmt_backend.purchase_lab*' -or $candidate.CommandLine -notlike "*$labFolder*") {
            throw 'Recorded PID belongs to another process; leaving it untouched.'
        }
        $owned = $candidate
    }
}
if ($Action -eq 'Stop') {
    if (Test-Path -LiteralPath $workerFile) {
        $workerPid = [int](Get-Content -LiteralPath $workerFile -Raw)
        $workerProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$workerPid" -ErrorAction SilentlyContinue
        if ($workerProcess) {
            if ($workerProcess.ExecutablePath -ne $python -or $workerProcess.CommandLine -notlike '*bmt_backend.purchase_lab*--worker*' -or $workerProcess.CommandLine -notlike "*$labFolder*") { throw 'Worker PID ownership differs; leaving it untouched.' }
            Stop-Process -Id $workerPid
        }
        Remove-Item -LiteralPath $workerFile
    }
    if ($owned) { Stop-Process -Id $owned.ProcessId }
    if (Test-Path -LiteralPath $pidFile) { Remove-Item -LiteralPath $pidFile }
    Write-Host 'Purchase lab stopped. Test account data is retained.'
    return
}
if (-not $owned) {
    if (-not (Test-Path -LiteralPath $python)) { throw 'Backend environment missing; run scripts/dev.ps1 -Action BackendTest first.' }
    if (-not (Test-Path -LiteralPath $godot)) { throw 'Pinned Godot executable is missing.' }
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw 'Port is already occupied; existing service left untouched.' }
    Write-Host 'Preparing the approved test track catalog...'
    & $python -m bmt_backend.purchase_lab --data-dir $labFolder --port $Port --godot-bin $godot --seed-catalog
    if ($LASTEXITCODE -ne 0) { throw 'Purchase-lab track catalog preparation failed; see the error above.' }
    $arguments = @('-m','bmt_backend.purchase_lab','--data-dir',('"'+$labFolder+'"'),'--port',$Port,'--godot-bin',('"'+$godot+'"'))
    $server = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $labFolder 'server.log') -RedirectStandardError (Join-Path $labFolder 'server-errors.log')
    [IO.File]::WriteAllText($pidFile,[string]$server.Id)
}
$ready = $false
for ($attempt=0; $attempt -lt 40; $attempt++) {
    try {
        $bootstrap = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/bootstrap" -TimeoutSec 2
        if ($bootstrap.purchase_simulation -and (Test-Path -LiteralPath $keyFile)) { $ready = $true; break }
    } catch { }
    Start-Sleep -Milliseconds 250
}
if (-not $ready) { throw 'Purchase lab did not become ready. See build/purchase-lab/server-errors.log.' }
if ($owned) {
    & $python -m bmt_backend.purchase_lab --data-dir $labFolder --port $Port --godot-bin $godot --seed-catalog
    if ($LASTEXITCODE -ne 0) { throw 'Purchase-lab track catalog preparation failed; existing services left running.' }
}
$workerAlive = $false
if (Test-Path -LiteralPath $workerFile) {
    $workerPid = [int](Get-Content -LiteralPath $workerFile -Raw)
    $workerProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$workerPid" -ErrorAction SilentlyContinue
    if ($workerProcess) {
        if ($workerProcess.ExecutablePath -ne $python -or $workerProcess.CommandLine -notlike '*bmt_backend.purchase_lab*--worker*' -or $workerProcess.CommandLine -notlike "*$labFolder*") { throw 'Worker PID ownership differs; leaving it untouched.' }
        $workerAlive = $true
    }
}
if (-not $workerAlive) {
    $arguments = @('-m','bmt_backend.purchase_lab','--data-dir',('"'+$labFolder+'"'),'--port',$Port,'--godot-bin',('"'+$godot+'"'),'--worker')
    $workerProcess = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $labFolder 'worker.log') -RedirectStandardError (Join-Path $labFolder 'worker-errors.log')
    [IO.File]::WriteAllText($workerFile,[string]$workerProcess.Id)
}
Write-Host "Purchase lab ready on port $Port. No store connection or payment."
if ($Action -eq 'Start') { return }
if ($Action -eq 'Admin') {
    if (-not $bootstrap.admin_console_configured) {
        & $PSCommandPath -Action Stop -Port $Port
        & $PSCommandPath -Action Start -Port $Port
    }
    $consoleUrl = "http://127.0.0.1:$Port/admin#economy"
    $adminKeyFile = Join-Path $labFolder 'admin-owner.key'
    if (-not (Test-Path -LiteralPath $adminKeyFile)) { throw 'Separate admin key is missing; restart the purchase lab.' }
    if ($NoBrowser) { Write-Host "Backend UI: $consoleUrl. Admin key file: $adminKeyFile"; return }
    Set-Clipboard -Value ((Get-Content -LiteralPath $adminKeyFile -Raw).Trim())
    Start-Process -FilePath $consoleUrl
    Write-Host 'Backend console opened. Paste the separate administrator key from the clipboard and Connect.'
    return
}
$previousUrl = $env:BMT_API_URL
$previousKey = $env:BMT_DEV_AUTH_KEY
$previousLab = $env:BMT_PURCHASE_LAB
try {
    $env:BMT_API_URL = "http://127.0.0.1:$Port"
    $env:BMT_DEV_AUTH_KEY = (Get-Content -LiteralPath $keyFile -Raw).Trim()
    $env:BMT_PURCHASE_LAB = 'true'
    & (Join-Path $PSScriptRoot 'dev.ps1') -Action Run -CommandTimeoutSeconds 7200
} finally {
    $env:BMT_API_URL = $previousUrl
    $env:BMT_DEV_AUTH_KEY = $previousKey
    $env:BMT_PURCHASE_LAB = $previousLab
}
