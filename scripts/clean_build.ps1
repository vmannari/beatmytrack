[CmdletBinding()]
param(
    [switch]$Apply,
    [ValidateRange(1, 1000)][int]$MaxGiB = 20,
    [ValidateRange(1, 365)][int]$MaxAgeDays = 7,
    [ValidateRange(1, 168)][int]$GraceHours = 24
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$root = [IO.Path]::GetFullPath((Join-Path $repo 'build'))
if (-not (Test-Path -LiteralPath $root)) { return }
if ((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Refusing a linked build root.'
}
if (-not ('BmtBuildRetentionDelete' -as [type])) {
    # Use .NET directly to avoid per-file PowerShell pipeline overhead in large
    # test profiles. Directory deletion is always nonrecursive; links are leaves.
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class BmtBuildRetentionDelete {
    public static Action<string> FileFallback;
    public static bool CanDelete(string path, DateTime cutoff) {
        FileAttributes attributes = File.GetAttributes(path);
        if ((attributes & FileAttributes.ReparsePoint) != 0) return true;
        if (File.GetLastWriteTimeUtc(path) > cutoff) return false;
        string extension = Path.GetExtension(path).ToLowerInvariant();
        if (Path.GetFileName(path) == ".keep" || extension == ".jks" || extension == ".keystore" || extension == ".p12") return false;
        if ((attributes & FileAttributes.Directory) != 0) {
            foreach (string child in Directory.GetFileSystemEntries(path))
                if (!CanDelete(child, cutoff)) return false;
        }
        return true;
    }
    public static void Delete(string path, string root) {
        string full = Path.GetFullPath(path);
        if (!full.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new IOException("Deletion escaped build: " + full);
        FileAttributes attributes = File.GetAttributes(full);
        bool directory = (attributes & FileAttributes.Directory) != 0;
        if ((attributes & FileAttributes.ReparsePoint) != 0) {
            if (directory) Directory.Delete(full, false);
            else File.Delete(full);
        } else if (directory) {
            if (File.Exists(Path.Combine(full, ".keep"))) throw new IOException("New .keep marker: " + full);
            foreach (string child in Directory.GetFileSystemEntries(full)) Delete(child, root);
            Directory.Delete(full, false);
        } else {
            if ((attributes & FileAttributes.ReadOnly) != 0)
                File.SetAttributes(full, attributes & ~FileAttributes.ReadOnly);
            try { File.Delete(full); }
            catch (UnauthorizedAccessException) {
                if (FileFallback == null) throw;
                FileFallback(full);
            }
        }
    }
}
'@
}
[BmtBuildRetentionDelete]::FileFallback = [Action[string]] {
    param([string]$FilePath)
    Remove-Item -LiteralPath $FilePath -Force -ErrorAction Stop
}
# Serialize cleanup runs; never modify the Git index or follow directory links.
$lockPath = Join-Path $repo '.tmp/build-cleanup.lock'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $lockPath))
try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
catch { Write-Warning 'Build cleanup already running; skipped.'; return }
try {
    $tracked = @(& git -C $repo ls-files -- build)
    if ($LASTEXITCODE -ne 0) { throw 'Could not check tracked build files.' }
    $raw = & python (Join-Path $PSScriptRoot 'build_inventory.py')
    if ($LASTEXITCODE -ne 0) { throw 'Build inventory failed; nothing deleted.' }
    $entries = ConvertFrom-Json -InputObject ($raw -join "`n")
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $total = 0L
    foreach ($entry in $entries) { $total += [long]$entry.bytes }
    $before = $total
    $removed = 0
    $failures = @()
    $deleted = @()
    foreach ($entry in ($entries | Sort-Object latest)) {
        $target = [IO.Path]::GetFullPath($entry.path)
        # Only direct children of this exact workspace build directory qualify.
        if ([IO.Path]::GetDirectoryName($target) -ne $root) { throw "Unsafe cleanup path: $target" }
        $name = [IO.Path]::GetFileName($target)
        $relative = 'build/' + $name
        $isTracked = @($tracked | Where-Object { $_ -eq $relative -or $_.StartsWith($relative + '/') }).Count -gt 0
        # Historical owner backups and tool/source inputs are not disposable output.
        $reserved = $name -match '(?i)backup|track-sync|(^|[-_])sources?$|^android-tools$|^tools$'
        if ($entry.protected -or $isTracked -or $reserved) { continue }
        if ($entry.latest -gt ($now - $GraceHours * 3600)) { continue }
        if ($entry.latest -gt ($now - $MaxAgeDays * 86400) -and $total -le $MaxGiB * 1GB) { continue }
        if ($Apply) {
            try {
                $item = Get-Item -LiteralPath $target -Force
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Target became a link.' }
                if ($item.LastWriteTimeUtc -gt [DateTime]::UtcNow.AddHours(-$GraceHours)) { continue }
                if (Test-Path -LiteralPath (Join-Path $target '.keep')) { continue }
                # Recheck real descendants immediately before removal: another
                # task may have resumed an old profile since the initial scan.
                if (-not [BmtBuildRetentionDelete]::CanDelete($target, [DateTime]::UtcNow.AddHours(-$GraceHours))) { continue }
                [BmtBuildRetentionDelete]::Delete($target, $root)
            } catch {
                $failures += "$name : $($_.Exception.Message)"
                continue
            }
        }
        $total -= [long]$entry.bytes
        $removed++
        $deleted += $name
    }
    $receipt = [ordered]@{
        utc = [DateTime]::UtcNow.ToString('o'); applied = [bool]$Apply
        beforeGiB = [Math]::Round($before / 1GB, 3)
        remainingGiB = [Math]::Round($total / 1GB, 3)
        reclaimedGiB = [Math]::Round(($before - $total) / 1GB, 3)
        entries = $removed; targetGiB = $MaxGiB; graceHours = $GraceHours
        failures = $failures; deleted = $deleted
    }
    # Replace a single receipt rather than accumulating cleanup logs.
    $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $repo '.tmp/build-cleanup-last.json') -Encoding UTF8
    Write-Host ("Build cleanup: {0:N2} -> {1:N2} GiB; {2} entries; apply={3}" -f ($before / 1GB), ($total / 1GB), $removed, [bool]$Apply)
    if ($total -gt $MaxGiB * 1GB) { Write-Warning 'Build exceeds target: recent, protected or locked entries remain. See .tmp/build-cleanup-last.json.' }
    if ($failures.Count) { Write-Warning ($failures -join "`n") }
} finally { $lock.Dispose() }
