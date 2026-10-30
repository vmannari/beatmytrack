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
function Get-PreviewHash {
    $text = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'game/core/build_identity.gd'))
    $match = [regex]::Match($text, 'GARAGE_PREVIEW_SHA256: String = "([a-f0-9]{64})"')
    if (-not $match.Success) { throw 'Generated preview fingerprint is missing.' }
    return $match.Groups[1].Value
}
function Get-HeaderHash {
    $text = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'game/core/build_identity.gd'))
    $match = [regex]::Match($text, 'HEADER_PREVIEW_SHA256: String = "([a-f0-9]{64})"')
    if (-not $match.Success) { throw 'Generated header fingerprint is missing.' }
    return $match.Groups[1].Value
}
$headerBefore = Get-HeaderHash
[System.IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'game/backend')) | Out-Null
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/backend/transport.gd'), '# unrelated transport', $encoding)
$transportBuild = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
if ($transportBuild -ceq $untracked -or (Get-HeaderHash) -cne $headerBefore) { throw 'Transport edits must not invalidate header appearances.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/core/app.gd'), '# unrelated navigation', $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
if ((Get-HeaderHash) -cne $headerBefore) { throw 'App navigation edits must not invalidate header appearances.' }
$previewBefore = Get-PreviewHash
[System.IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'game/ui')) | Out-Null
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/ui/garage_page.gd'), '# changed label', $encoding)
$menuBuild = Write-ClientBuildIdentity $fixtureRoot $fixtureRoot
if ($menuBuild -ceq $transportBuild -or (Get-PreviewHash) -cne $previewBefore) { throw 'Menu changes must update the build while retaining saved preview pictures.' }
if ((Get-HeaderHash) -ceq $headerBefore) { throw 'Conservative UI changes must invalidate header appearances.' }
[System.IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'game/vehicle')) | Out-Null
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/vehicle/compact_coachwork.gd'), '# first body', $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
$bodyPreview = Get-PreviewHash
if ($bodyPreview -ceq $previewBefore) { throw 'A new model source must invalidate old pictures.' }
$headerBody = Get-HeaderHash
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/vehicle/compact_coachwork.gd'), '# revised body', $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
$revisedPreview = Get-PreviewHash
if ($revisedPreview -ceq $bodyPreview) { throw 'A model edit must invalidate old pictures.' }
if ((Get-HeaderHash) -ceq $headerBody) { throw 'Model edits must invalidate header appearances.' }
[System.IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'game/assets/liveries')) | Out-Null
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/assets/liveries/stripe.svg'), '<svg/>', $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
$liveryPreview = Get-PreviewHash
if ($liveryPreview -ceq $revisedPreview) { throw 'Livery artwork must invalidate old pictures.' }
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/ui/garage_reflections.gd'), '# revised reflections', $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
if ((Get-PreviewHash) -ceq $liveryPreview) { throw 'Lighting/reflection changes must invalidate old pictures.' }
$renderPreview = Get-PreviewHash
$renderHeader = Get-HeaderHash
$project = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'game/project.godot'))
[System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'game/project.godot'), $project + "`n[rendering]`nrenderer/rendering_method=`"mobile`"`n", $encoding)
Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
if ((Get-PreviewHash) -ceq $renderPreview) { throw 'Project rendering changes must invalidate old pictures.' }
if ((Get-HeaderHash) -ceq $renderHeader) { throw 'Rendering changes must invalidate header appearances.' }
Write-Host 'BUILD_IDENTITY: 18 checks passed; isolated fixture retained in build/.'
