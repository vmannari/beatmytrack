$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath '.').Path
$evidence = Join-Path $repo 'docs\evidence\challenger-surface-joins-2026-11-12'
$removed = @()
foreach ($leaf in @('garage-draft','garage-draft2','garage-remesh','garage-remesh2','garage-remesh3','garage-source-final','garage-upper')) {
    $candidate = [IO.Path]::GetFullPath((Join-Path $evidence $leaf))
    if (-not $candidate.StartsWith($evidence + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence target escaped task folder' }
    if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Recurse -Force; $removed += $candidate }
}
$buildRoot = [IO.Path]::GetFullPath((Join-Path $repo 'build'))
$target = [IO.Path]::GetFullPath((Join-Path $buildRoot 'challenger-surface-joins-2026-11-12'))
if (-not $target.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Build target escaped workspace build' }
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force; $removed += $target }
@{ removed = $removed; final_comparisons_and_receipts_retained = $true } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'cleanup-receipt.json') -Encoding UTF8
Write-Output 'Task build output and redundant comparison drafts removed.'
