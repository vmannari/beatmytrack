param([ValidateSet('Start','Held','Backtrack','Short','Carousel')][string]$Action)
$ErrorActionPreference = 'Stop'
$phoneAdb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$evidence = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/exclusive-menu-swipes-2026-10-04'
function Invoke-Phone([string[]]$Arguments) {
    $line = 'adb -s PRQKU4U4PREQNRWG ' + ($Arguments -join ' ')
    Add-Content -LiteralPath (Join-Path $evidence 'phone-commands.txt') -Value $line
    & $phoneAdb -s PRQKU4U4PREQNRWG @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Phone command failed: $line" }
}
function Capture-Phone([string]$Name) {
    Invoke-Phone @('shell','screencap','-p','/data/local/tmp/exclusive-menu.png')
    Invoke-Phone @('pull','/data/local/tmp/exclusive-menu.png',(Join-Path $evidence ($Name+'.png')))
}
function Touch-Phone([string]$Kind,[int]$X,[int]$Y) {
    Invoke-Phone @('shell','input','touchscreen','motionevent',$Kind,[string]$X,[string]$Y)
}
switch ($Action) {
    'Start' {
        Invoke-Phone @('shell','input','tap','1200','974')
        Start-Sleep -Milliseconds 1200
        Invoke-Phone @('shell','input','tap','1180','85')
        Start-Sleep -Milliseconds 700
        Capture-Phone 'phone-tapped-create'
    }
    'Held' {
        Touch-Phone 'DOWN' 2150 500
        foreach ($x in @(2000,1500,800,220)) { Touch-Phone 'MOVE' $x 500 }
        Start-Sleep -Milliseconds 1500
        Capture-Phone 'phone-long-held'
        Touch-Phone 'UP' 220 500
        Start-Sleep -Milliseconds 700
        Capture-Phone 'phone-long-committed'
    }
    'Backtrack' {
        Invoke-Phone @('shell','input','tap','1180','85')
        Start-Sleep -Milliseconds 700
        Touch-Phone 'DOWN' 2150 500
        foreach ($x in @(1500,1800,1550,1830)) { Touch-Phone 'MOVE' $x 500 }
        Start-Sleep -Milliseconds 800
        Capture-Phone 'phone-backtrack-held'
        Touch-Phone 'UP' 1830 500
        Start-Sleep -Milliseconds 700
        Capture-Phone 'phone-backtrack-returned'
    }
    'Short' {
        Touch-Phone 'DOWN' 2150 500
        Touch-Phone 'MOVE' 2114 500
        Start-Sleep -Milliseconds 800
        Touch-Phone 'UP' 2114 500
        Start-Sleep -Milliseconds 700
        Capture-Phone 'phone-short-committed'
    }
    'Carousel' {
        Invoke-Phone @('shell','input','tap','670','85')
        Start-Sleep -Milliseconds 700
        Invoke-Phone @('shell','input','swipe','1350','840','950','840','450')
        Start-Sleep -Milliseconds 700
        Capture-Phone 'phone-carousel'
    }
}
