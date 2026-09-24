[CmdletBinding()]
param([string]$Output = 'docs/evidence/menu-selection-2026-09-24/phone')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $repoRoot $Output
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package = 'org.circuit01.handlinglab'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Invoke-Adb([string[]]$Arguments) {
    $result = & $adb @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
$files = Invoke-Adb @('shell','run-as',$package,'ls','files')
if ($files -contains 'menu_probe.json' -or $files -contains 'mobile_probe.json') { throw 'An existing diagnostic is active; leave its markers intact.' }
'{}' | Set-Content "$evidence/config.json" -Encoding ASCII
Invoke-Adb @('shell','getprop','ro.product.model') | Set-Content "$evidence/device.txt"
try {
    Invoke-Adb @('shell','am','force-stop',$package)
    Invoke-Adb @('push',"$evidence/config.json",'/data/local/tmp/menu-profile.json')
    Invoke-Adb @('shell','run-as',$package,'cp','/data/local/tmp/menu-profile.json','files/menu_probe.json')
    Invoke-Adb @('shell','run-as',$package,'rm','-f','files/menu_probe_results.json')
    Invoke-Adb @('shell','input','keyevent','KEYCODE_WAKEUP')
    Invoke-Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package)
    $deadline = (Get-Date).AddSeconds(100)
    $completed = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $files = Invoke-Adb @('shell','run-as',$package,'ls','files')
        if ($files -notcontains 'menu_probe_results.json') { continue }
        $raw = Invoke-Adb @('shell','run-as',$package,'cat','files/menu_probe_results.json')
        $raw | Set-Content "$evidence/report.json" -Encoding UTF8
        $report = $raw -join "`n" | ConvertFrom-Json
        if ($report.interrupted) { throw 'Menu probe interrupted by navigation.' }
        if ($report.selections.Count -ne 3) { throw 'Menu probe requires saved Speedy and Knot tracks on the device.' }
        $report | ConvertTo-Json -Depth 6
        Invoke-Adb @('shell','screencap','-p','/data/local/tmp/menu-profile.png')
        Invoke-Adb @('pull','/data/local/tmp/menu-profile.png',"$evidence/menu.png")
        $completed = $true
        break
    }
    if (-not $completed) { throw 'Menu probe timed out without measurements.' }
} finally {
    Invoke-Adb @('shell','am','force-stop',$package)
    Invoke-Adb @('shell','run-as',$package,'rm','-f','files/menu_probe.json','files/menu_probe_results.json')
    Invoke-Adb @('shell','rm','-f','/data/local/tmp/menu-profile.json','/data/local/tmp/menu-profile.png')
    Invoke-Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package)
    Write-Host 'Normal play restored; menu diagnostic removed.'
}
