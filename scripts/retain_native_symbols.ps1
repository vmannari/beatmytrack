param([Parameter(Mandatory)][string]$Compiled,[Parameter(Mandatory)][string]$Objcopy,[Parameter(Mandatory)][string]$Strip,[string]$Source='')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $repoRoot 'native/track_geometry/track_geometry.cpp' }
$resolvedBinary = (Resolve-Path -LiteralPath $Compiled).Path
$allowedBuild = [IO.Path]::GetFullPath((Join-Path $repoRoot 'build')) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedBinary.StartsWith($allowedBuild,[StringComparison]::OrdinalIgnoreCase)) { throw 'Only freshly compiled workspace build outputs may be stripped.' }
$debug = $resolvedBinary + '.debug'
& $Objcopy '--only-keep-debug' $resolvedBinary $debug
if ($LASTEXITCODE) { throw 'Native debug symbol extraction failed.' }
& $Strip '--strip-unneeded' $resolvedBinary
if ($LASTEXITCODE) { throw 'Native library strip failed.' }
$binaryHash = (Get-FileHash -LiteralPath $resolvedBinary -Algorithm SHA256).Hash.ToLowerInvariant()
$symbolHash = (Get-FileHash -LiteralPath $debug -Algorithm SHA256).Hash.ToLowerInvariant()
$destination = Join-Path $repoRoot ('build/symbols/'+$binaryHash)
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $debug -Destination (Join-Path $destination (Split-Path -Leaf $debug)) -Force
$identity = [IO.File]::ReadAllText((Join-Path $repoRoot 'game/core/build_identity.gd'))
$receipt = [ordered]@{ schema='bmt-native-symbols-v1'; binary=(Split-Path -Leaf $resolvedBinary); binary_sha256=$binaryHash; symbols=(Split-Path -Leaf $debug); symbols_sha256=$symbolHash; source_sha256=(Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant(); build_identity=$identity; engine='4.7.2.stable.official.ed1daf0bf' }
[IO.File]::WriteAllText((Join-Path $destination 'mapping.json'),($receipt | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
