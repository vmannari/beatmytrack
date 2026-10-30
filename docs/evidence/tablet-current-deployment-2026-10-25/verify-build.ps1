$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $repoRoot 'scripts/build_identity.ps1')
$source = Join-Path $PSScriptRoot 'source'
$env:GIT_DIR = Join-Path $repoRoot '.git'
$env:GIT_WORK_TREE = $source
$logRoot = (Get-ChildItem -LiteralPath (Join-Path $source 'build/logs') -Directory -Filter 'ExportAndroid-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$builtIdentity = Get-Content -LiteralPath (Join-Path $logRoot 'client-build-identity.json') -Raw | ConvertFrom-Json
$currentId = Write-ClientBuildIdentity $source (Join-Path $PSScriptRoot 'source-recheck')
if ($currentId -ne $builtIdentity.build_id) { throw 'Shipping sources changed during export; rebuild required.' }
$apkPath = Join-Path $PSScriptRoot 'current-game.apk'
Copy-Item -LiteralPath (Join-Path $source 'build/android/circuit01-debug.apk') -Destination $apkPath
$badging = @(& 'C:\Users\ville\AppData\Local\Android\Sdk\build-tools\36.1.0\aapt2.exe' dump badging $apkPath)
if ($LASTEXITCODE -ne 0) { throw 'APK manifest inspection failed.' }
$packageLine = $badging | Where-Object { $_.StartsWith('package:') }
if ($packageLine -notmatch "name='org.circuit01.handlinglab'" -or $packageLine -notmatch ('versionName=''' + [regex]::Escape($currentId) + '''')) { throw 'APK package/version mismatch.' }
$badging | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'apk-badging.txt') -Encoding UTF8
$verified = [ordered]@{
    build_id = $builtIdentity.build_id
    source_sha256 = $builtIdentity.source_sha256
    source_files = $builtIdentity.source_files
    source_unchanged_during_build = $true
    apk_version_matches = $true
    apk_path = $apkPath
    apk_bytes = (Get-Item -LiteralPath $apkPath).Length
    apk_sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$verified | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'verified-build.json') -Encoding UTF8
$verified | ConvertTo-Json
