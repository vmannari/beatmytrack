[CmdletBinding()]
param([switch]$Archive, [string]$ResourceRoot = '', [string]$ArchiveRoot = '', [string]$ReportPath = '')
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$workspacePrefix = $workspaceRoot.TrimEnd('\') + '\'
if (-not $ResourceRoot) { $ResourceRoot = Join-Path $workspaceRoot 'game' }
if (-not $ArchiveRoot) { $ArchiveRoot = Join-Path $workspaceRoot 'archive/native-libraries' }
if (-not $ReportPath) { $ReportPath = Join-Path $workspaceRoot 'build/native-library-retention.json' }
$ResourceRoot = [IO.Path]::GetFullPath($ResourceRoot)
$ArchiveRoot = [IO.Path]::GetFullPath($ArchiveRoot)
$ReportPath = [IO.Path]::GetFullPath($ReportPath)
function Assert-RetentionPath([string]$Path, [switch]$AllowHardLink) {
    $checkedPath = [IO.Path]::GetFullPath($Path)
    if (-not $checkedPath.StartsWith($workspacePrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Native retention paths must stay inside the repository.' }
    $ancestor = $checkedPath
    while ($ancestor.StartsWith($workspacePrefix,[StringComparison]::OrdinalIgnoreCase)) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $permittedLeaf = $AllowHardLink -and $ancestor -eq $checkedPath -and $item.LinkType -eq 'HardLink'
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($item.LinkType -and -not $permittedLeaf)) { throw 'Native retention paths cannot traverse links.' }
        }
        $ancestor = Split-Path -Parent $ancestor
    }
}
foreach ($checkedPath in @($ResourceRoot,$ArchiveRoot,$ReportPath)) { Assert-RetentionPath $checkedPath }
if ($ArchiveRoot -eq $ResourceRoot -or $ArchiveRoot.StartsWith($ResourceRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Native archives must be outside the resource root.' }
$directories = @((Join-Path $ResourceRoot 'platform/windows'),(Join-Path $ResourceRoot 'platform/track_geometry'))
$referenced = @{}
foreach ($directory in $directories) {
    Assert-RetentionPath $directory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    foreach ($descriptor in Get-ChildItem -LiteralPath $directory -Filter '*.gdextension' -File) {
        Assert-RetentionPath $descriptor.FullName -AllowHardLink
        $descriptorText = [IO.File]::ReadAllText($descriptor.FullName)
        foreach ($match in [regex]::Matches($descriptorText,'res://[^"\r\n]+\.dll')) {
            $resolved = [IO.Path]::GetFullPath((Join-Path $ResourceRoot $match.Value.Substring(6)))
            $referenced[$resolved] = $true
        }
    }
}
$loaded = @{}
$inspectionComplete = $true
$inspectionFailures = @()
foreach ($process in @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)) {
    try {
        foreach ($module in $process.Modules) { $loaded[[IO.Path]::GetFullPath($module.FileName)] = $true }
    } catch {
        $inspectionComplete = $false
        $inspectionFailures += $process.Id
    }
}
$rows = @()
foreach ($directory in $directories) {
    Assert-RetentionPath $directory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    $sourcePrefix = [IO.Path]::GetFullPath($directory).TrimEnd('\')+'\'
    foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.dll' -File) {
        $source = [IO.Path]::GetFullPath($file.FullName)
        # Moving a hard-link entry preserves its other names and bytes. A
        # symbolic link could redirect the hash read outside this directory.
        if (-not $source.StartsWith($sourcePrefix,[StringComparison]::OrdinalIgnoreCase) -or ($file.LinkType -and $file.LinkType -ne 'HardLink')) { throw 'Unexpected native library path or link.' }
        Assert-RetentionPath $source -AllowHardLink
        if ($referenced.ContainsKey($source)) { continue }
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        $destination = [IO.Path]::GetFullPath((Join-Path (Join-Path $ArchiveRoot $hash) $file.Name))
        if (-not $destination.StartsWith($ArchiveRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Native archive destination escaped its root.' }
        Assert-RetentionPath $destination -AllowHardLink
        $state = if (-not $inspectionComplete) { 'inspection_incomplete' } elseif ($loaded.ContainsKey($source)) { 'loaded' } else { 'candidate' }
        if ($Archive -and $state -eq 'candidate') {
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Assert-RetentionPath $source -AllowHardLink
            Assert-RetentionPath $destination -AllowHardLink
            try {
                if (Test-Path -LiteralPath $destination) {
                    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Native archive hash mismatch.' }
                    Remove-Item -LiteralPath $source
                } else { Move-Item -LiteralPath $source -Destination $destination }
                if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Native archive verification failed.' }
                $state = 'archived'
            } catch {
                if (Test-Path -LiteralPath $source) { $state = 'in_use_or_unavailable' } else { throw }
            }
        }
        $rows += [pscustomobject]@{source=$source; archive=$destination; sha256=$hash; bytes=$file.Length; state=$state}
    }
}
$report = [pscustomobject]@{archive_requested=[bool]$Archive; inspection_complete=$inspectionComplete; inspection_failures=$inspectionFailures; referenced_libraries=@($referenced.Keys); libraries=$rows}
Assert-RetentionPath $ReportPath
New-Item -ItemType Directory -Path (Split-Path -Parent $ReportPath) -Force | Out-Null
Assert-RetentionPath $ReportPath
[IO.File]::WriteAllText($ReportPath,($report | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$report | ConvertTo-Json -Depth 5
