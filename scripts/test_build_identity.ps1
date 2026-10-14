[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'build_identity.ps1')
$fixtureRoot = Join-Path (Split-Path -Parent $PSScriptRoot) ('build/build-identity-fixture-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'game/tests')) | Out-Null
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/project.godot'), "[application]`nconfig/base_version=`"fixture`"`nconfig/version=`"old`"`n", $encoding)
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/export_presets.cfg'), "exclude_filter=`"tests/*`"`nversion/name=`"`"`n", $encoding)
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/car.gd'), "extends Node`n", $encoding)
& git -C $fixtureRoot init -q
if ($LASTEXITCODE) { throw 'Fixture Git initialization failed.' }
$first = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
$second = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
if ($first -cne $second) { throw 'Identical sources must keep the same build identity.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/tests/diagnostic.gd'), '# excluded fixture', $encoding)
if ((Write-ClientBuildIdentity $fixtureRoot $fixtureRoot) -cne $first) { throw 'Export-excluded tests must not change client identity.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/car.gd.uid'), 'uid://generated-metadata', $encoding)
if ((Write-ClientBuildIdentity $fixtureRoot $fixtureRoot) -cne $first) { throw 'Engine-generated UID metadata must not change the source identity.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/car.gd'), "extends Node`nvar changed: bool = true`n", $encoding)
$dirty = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
if ($dirty -ceq $first) { throw 'Uncommitted runtime changes must change client identity.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/new_asset.txt'), 'new shipped asset', $encoding)
$untracked = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
if ($untracked -ceq $dirty) { throw 'New shipping assets must change client identity.' }
$project = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'game/project.godot'))
$identity = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'game/core/build_identity.gd'))
if (-not $project.Contains('config/version="' + $untracked + '"') -or -not $identity.Contains('const ID: String = "' + $untracked + '"')) { throw 'Runtime and export versions must match.' }
Write-Host 'BUILD_IDENTITY: 7 checks passed; isolated fixture retained in build/.'
