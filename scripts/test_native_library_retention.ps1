$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$testRoot = Join-Path $repoRoot ('build/legacy-cleanup-2026-10-24/native-fixture-'+[guid]::NewGuid().ToString('N'))
$resource = Join-Path $testRoot 'game'
$archive = Join-Path $testRoot 'archive'
$report = Join-Path $testRoot 'report.json'
$directory = Join-Path $resource 'platform/windows'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$current = Join-Path $directory 'keep.dll'
$obsolete = Join-Path $directory 'old.dll'
[IO.File]::WriteAllText($current,'current native fixture')
[IO.File]::WriteAllText($obsolete,'historical native fixture')
$alias = Join-Path $directory 'old-alias.dll'
New-Item -ItemType HardLink -Path $alias -Target $obsolete | Out-Null
[IO.File]::WriteAllText((Join-Path $directory 'fixture.gdextension'),'[libraries]'+"`n"+'windows.x86_64 = "res://platform/windows/keep.dll"')
$hash = (Get-FileHash -LiteralPath $obsolete -Algorithm SHA256).Hash.ToLowerInvariant()
$script = Join-Path $PSScriptRoot 'archive_native_libraries.ps1'
& $script -ResourceRoot $resource -ArchiveRoot $archive -ReportPath $report | Out-Null
if (-not (Test-Path -LiteralPath $obsolete)) { throw 'Dry run moved an old library.' }
$dry = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (@($dry.libraries).Count -ne 2 -or @($dry.referenced_libraries).Count -ne 1) { throw 'Descriptor protection did not isolate the old library names.' }
& $script -Archive -ResourceRoot $resource -ArchiveRoot $archive -ReportPath $report | Out-Null
$result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (-not $result.inspection_complete) { throw 'Loaded module inspection was unavailable; no archive pass is claimed.' }
$saved = Join-Path (Join-Path $archive $hash) 'old.dll'
if ((Test-Path -LiteralPath $obsolete) -or -not (Test-Path -LiteralPath $current) -or -not (Test-Path -LiteralPath $saved)) { throw 'Archive affected the wrong native generations.' }
if ((Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Archived library bytes changed.' }
$savedAlias = Join-Path (Join-Path $archive $hash) 'old-alias.dll'
if ((Test-Path -LiteralPath $alias) -or (Get-FileHash -LiteralPath $savedAlias -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Hard-linked historical bytes were not retained.' }
& $script -Archive -ResourceRoot $resource -ArchiveRoot $archive -ReportPath $report | Out-Null
$again = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (@($again.libraries).Count -ne 0) { throw 'A repeat archive was not idempotent.' }
$rejected = $false
try { & $script -ResourceRoot $resource -ArchiveRoot 'C:\Windows' -ReportPath $report | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'An archive escaped the repository.' }
# Every redirect stays inside this isolated fixture; the configured roots must
# still reject it before any file is moved or a report is written.
$linkedResource = Join-Path $testRoot 'hash-link-game'
$linkedSource = Join-Path $linkedResource 'platform/windows'
$linkedArchive = Join-Path $testRoot 'hash-link-archive'
$outsideArchive = Join-Path $testRoot 'outside-named-archive'
foreach ($path in @($linkedSource,$linkedArchive,$outsideArchive)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
$linkedDll = Join-Path $linkedSource 'obsolete.dll'
[IO.File]::WriteAllText($linkedDll,'archive junction regression')
$linkedHash = (Get-FileHash -LiteralPath $linkedDll -Algorithm SHA256).Hash.ToLowerInvariant()
New-Item -ItemType Junction -Path (Join-Path $linkedArchive $linkedHash) -Target $outsideArchive | Out-Null
$rejected = $false
try { & $script -Archive -ResourceRoot $linkedResource -ArchiveRoot $linkedArchive -ReportPath $report | Out-Null } catch { $rejected = $true }
if (-not $rejected -or -not (Test-Path -LiteralPath $linkedDll) -or (Test-Path -LiteralPath (Join-Path $outsideArchive 'obsolete.dll'))) { throw 'A hash-directory junction redirected the archive.' }
$sourceLinkRoot = Join-Path $testRoot 'source-link-game'
New-Item -ItemType Directory -Path (Join-Path $sourceLinkRoot 'platform') -Force | Out-Null
New-Item -ItemType Junction -Path (Join-Path $sourceLinkRoot 'platform/windows') -Target $linkedSource | Out-Null
$rejected = $false
try { & $script -Archive -ResourceRoot $sourceLinkRoot -ArchiveRoot $archive -ReportPath $report | Out-Null } catch { $rejected = $true }
if (-not $rejected -or -not (Test-Path -LiteralPath $linkedDll)) { throw 'A source-directory junction was traversed.' }
$reportLink = Join-Path $testRoot 'report-link'
New-Item -ItemType Junction -Path $reportLink -Target $outsideArchive | Out-Null
$rejected = $false
try { & $script -ResourceRoot $resource -ArchiveRoot $archive -ReportPath (Join-Path $reportLink 'escaped.json') | Out-Null } catch { $rejected = $true }
if (-not $rejected -or (Test-Path -LiteralPath (Join-Path $outsideArchive 'escaped.json'))) { throw 'A report-directory junction was traversed.' }
Write-Output 'NATIVE_LIBRARY_RETENTION: 10 checks, 0 failures'
