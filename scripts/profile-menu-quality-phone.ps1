[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DeviceSerial,
    [Parameter(Mandatory = $true)][string]$Output,
    [ValidateSet('Quality','PageSwipes')][string]$Mode = 'Quality',
    [string]$AdbPath = (Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe')
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $repoRoot $Output
$package = 'org.circuit01.handlinglab'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Invoke-Adb([string[]]$Arguments) {
    $result = & $AdbPath -s $DeviceSerial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
$files = Invoke-Adb @('shell','run-as',$package,'ls','files')
foreach ($marker in @('menu_probe.json','mobile_probe.json','control_probe.json')) {
    if ($files -contains $marker) { throw "Existing diagnostic $marker is active; its markers were preserved." }
}
$configuration = if ($Mode -eq 'Quality') { '{"quality_review":true}' } else { '{"page_swipes":true}' }
$configuration | Set-Content -LiteralPath (Join-Path $evidence 'config.json') -Encoding ASCII
Invoke-Adb @('shell','getprop','ro.product.model') | Set-Content -LiteralPath (Join-Path $evidence 'device.txt')
try {
    Invoke-Adb @('shell','am','force-stop',$package) | Out-Null
    Invoke-Adb @('push',(Join-Path $evidence 'config.json'),'/data/local/tmp/menu-quality.json') | Out-Null
    Invoke-Adb @('shell','run-as',$package,'cp','/data/local/tmp/menu-quality.json','files/menu_probe.json') | Out-Null
    Invoke-Adb @('shell','run-as',$package,'rm','-f','files/menu_probe_results.json') | Out-Null
    Invoke-Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package)
    $deadline = (Get-Date).AddSeconds(100)
    $completed = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $files = Invoke-Adb @('shell','run-as',$package,'ls','files')
        if ($files -notcontains 'menu_probe_results.json') { continue }
        $raw = Invoke-Adb @('shell','run-as',$package,'cat','files/menu_probe_results.json')
        $raw | Set-Content -LiteralPath (Join-Path $evidence 'report.json') -Encoding UTF8
        $report = $raw -join "`n" | ConvertFrom-Json
        if ($Mode -eq 'Quality' -and -not $report.quality_review) { throw 'Installed APK lacks the quality review diagnostic.' }
        if ($Mode -eq 'PageSwipes' -and $report.failures.Count -gt 0) { throw "Page swipe failures: $($report.failures -join ', ')" }
        $report | ConvertTo-Json -Depth 8
        Invoke-Adb @('shell','screencap','-p','/data/local/tmp/menu-quality.png') | Out-Null
        Invoke-Adb @('pull','/data/local/tmp/menu-quality.png',(Join-Path $evidence 'menu.png')) | Out-Null
        $completed = $true
        break
    }
    if (-not $completed) { throw 'Menu diagnostic timed out.' }
} finally {
    Invoke-Adb @('shell','am','force-stop',$package) | Out-Null
    Invoke-Adb @('shell','run-as',$package,'rm','-f','files/menu_probe.json','files/menu_probe_results.json') | Out-Null
    Invoke-Adb @('shell','rm','-f','/data/local/tmp/menu-quality.json','/data/local/tmp/menu-quality.png') | Out-Null
    Invoke-Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Out-Null
    Write-Host 'Menu diagnostic removed; normal startup restored.'
}
