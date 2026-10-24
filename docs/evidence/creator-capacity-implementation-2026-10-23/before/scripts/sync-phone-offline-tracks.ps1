param(
    [Parameter(Mandatory = $true)][string]$DeviceSerial,
    [Parameter(Mandatory = $true)][string]$SourceCachePath,
    [string]$Output = 'build/offline-track-sync',
    [string]$AdbPath = (Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = 'org.circuit01.handlinglab'
$cache = (Resolve-Path -LiteralPath $SourceCachePath).Path
$cacheKey = Split-Path -Leaf $cache
if ($cacheKey -cnotmatch '^[a-f0-9]{64}$') { throw 'Use the original server-scoped public cache directory.' }
$sourceIndex = Get-Content -LiteralPath (Join-Path $cache 'index.json') -Raw | ConvertFrom-Json
$sourceEntries = @($sourceIndex.entries)
if ($sourceEntries.Count -eq 0) { throw 'The public catalog is empty.' }
$bundle = [System.IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $bundle) { throw 'Use a new output directory for each transfer.' }
New-Item -ItemType Directory -Path (Join-Path $bundle 'snapshot') -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$documents = @{}
$identities = @{}
foreach ($entry in $sourceEntries) {
    if ($entry.state -cne 'published' -or $entry.track_id -cnotmatch '^[a-f0-9-]{36}$' -or $entry.version_id -cnotmatch '^[a-f0-9-]{36}$' -or $entry.content_hash -cnotmatch '^[a-f0-9]{64}$' -or -not ($entry.points -is [array])) { throw 'Invalid published track metadata.' }
    if ($identities.ContainsKey($entry.track_id)) { throw 'The catalog contains duplicate logical tracks.' }
    $identities[$entry.track_id] = $true
    $filename = $entry.content_hash + '.json'
    $source = Join-Path $cache $filename
    if ((Get-Item -LiteralPath $source).Length -gt 524288) { throw "Track exceeds the document bound: $($entry.name)" }
    $snapshot = Join-Path $bundle ('snapshot/' + $filename)
    Copy-Item -LiteralPath $source -Destination $snapshot
    if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.content_hash) { throw "Track hash mismatch: $($entry.name)" }
    $document = Get-Content -LiteralPath $snapshot -Raw | ConvertFrom-Json
    if ($document.schema -cne 'creator-track-v5') { throw "Unsupported track schema: $($entry.name)" }
    $documents[$filename] = $snapshot
}
function Invoke-Phone([string[]]$Arguments) {
    # Windows PowerShell wraps even successful adb progress on stderr in errors.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $result = & $AdbPath -s $DeviceSerial @Arguments 2>&1
        $nativeExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($nativeExitCode -ne 0) { throw "ADB failed: $($Arguments -join ' ')`n$($result -join "`n")" }
    return ($result -join "`n")
}
if ((Invoke-Phone @('get-state')).Trim() -cne 'device') { throw 'The requested phone is not authorized.' }
Invoke-Phone @('shell','run-as',$package,'pwd') | Out-Null
$phoneRoot = 'files/cloud/' + $cacheKey
$transaction = 'offline-' + [guid]::NewGuid().ToString('N')
$stage = '/data/local/tmp/' + $transaction
$backup = 'files/track_sync_backups/' + $transaction
$manifest = [ordered]@{device=$DeviceSerial; package=$package; cache_key=$cacheKey; tracks=$sourceEntries.Count; names=@($sourceEntries.name); backup=$backup; files=@(); complete=$false}
$manifestPath = Join-Path $bundle 'manifest.json'
function Save-Receipt {
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), $utf8)
}
Invoke-Phone @('shell','am','force-stop',$package) | Out-Null
$staged = @()
try {
    Invoke-Phone @('shell','mkdir','-p',$stage) | Out-Null
    Invoke-Phone @('shell','run-as',$package,'mkdir','-p',$phoneRoot,$backup) | Out-Null
    $oldEntries = @()
    & $AdbPath -s $DeviceSerial shell run-as $package test -f "$phoneRoot/index.json"
    if ($LASTEXITCODE -eq 0) {
        $oldIndex = Invoke-Phone @('shell','run-as',$package,'cat',"$phoneRoot/index.json")
        [System.IO.File]::WriteAllText((Join-Path $bundle 'previous-index.json'), $oldIndex, $utf8)
        $oldEntries = @(($oldIndex | ConvertFrom-Json).entries)
    }
    $merged = @($sourceEntries) + @($oldEntries | Where-Object { -not $identities.ContainsKey($_.track_id) })
    $indexSnapshot = Join-Path $bundle 'snapshot/index.json'
    [System.IO.File]::WriteAllText($indexSnapshot, (@{entries=$merged} | ConvertTo-Json -Depth 50 -Compress), $utf8)
    # Publish the catalog last; every new card already has its complete document.
    $files = @($documents.Keys | Sort-Object) + @('index.json')
    Save-Receipt
    foreach ($filename in $files) {
        $source = if ($filename -eq 'index.json') { $indexSnapshot } else { $documents[$filename] }
        $expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        $final = "$phoneRoot/$filename"
        $temporary = "$final.$transaction"
        $publicStage = "$stage/$filename"
        $staged += $publicStage
        Invoke-Phone @('push',$source,$publicStage) | Out-Null
        Invoke-Phone @('shell','run-as',$package,'cp',$publicStage,$temporary) | Out-Null
        $actual = (Invoke-Phone @('shell','run-as',$package,'sha256sum',$temporary)).Split(' ')[0]
        if ($actual -cne $expected) { throw "Staged hash mismatch: $filename" }
        & $AdbPath -s $DeviceSerial shell run-as $package test -f $final
        $replaced = $LASTEXITCODE -eq 0
        if ($replaced) { Invoke-Phone @('shell','run-as',$package,'cp',$final,"$backup/$filename") | Out-Null }
        Invoke-Phone @('shell','run-as',$package,'mv',$temporary,$final) | Out-Null
        $actual = (Invoke-Phone @('shell','run-as',$package,'sha256sum',$final)).Split(' ')[0]
        if ($actual -cne $expected) { throw "Installed hash mismatch: $filename" }
        $manifest.files += [ordered]@{name=$filename;sha256=$expected;bytes=(Get-Item -LiteralPath $source).Length;replaced=$replaced}
        Save-Receipt
    }
    $manifest.complete = $true
    Save-Receipt
    Write-Host "Copied $($sourceEntries.Count) published tracks for offline guest racing. Receipt: $manifestPath"
} finally {
    # Only remove the exact, generated staging files; retain private backups.
    foreach ($path in $staged) { & $AdbPath -s $DeviceSerial shell rm -f $path | Out-Null }
    & $AdbPath -s $DeviceSerial shell rmdir $stage | Out-Null
    & (Join-Path $PSScriptRoot 'dev.ps1') -Action LaunchAndroid -DeviceSerial $DeviceSerial
}
