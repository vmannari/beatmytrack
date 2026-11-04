$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../../scripts/build_identity.ps1')
if (-not (Test-GaragePreviewSource 'game/ui/garage_thumbnail_studio.gd')) { throw 'Studio missing from preview identity inputs' }
if (-not (Test-GaragePreviewSource 'game/ui/garage_thumbnail_shadow.gdshader')) { throw 'Shadow missing from preview identity inputs' }
Write-Output 'Thumbnail studio and shadow shader included in preview source identity.'
