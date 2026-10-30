param([switch]$ResumePresentation)
$ErrorActionPreference = 'Stop'
if (-not $ResumePresentation) {
    & "$PSScriptRoot/run.ps1" -Job bake
    if ($LASTEXITCODE -ne 0) { throw 'Bake failed' }
}
& "$PSScriptRoot/run.ps1" -Job garage-template
if ($LASTEXITCODE -ne 0) { throw 'Garage kart bake failed' }
$phases = if ($ResumePresentation) { @('visual','assets','checks') } else { @('geometry','visual','assets','checks') }
foreach ($kartPhase in $phases) {
    & "$PSScriptRoot/verify.ps1" -Phase $kartPhase
    if ($LASTEXITCODE -ne 0) { throw "Failed phase $kartPhase" }
}
foreach ($kartJob in @('model','bodywork-view','native')) {
    & "$PSScriptRoot/run.ps1" -Job $kartJob -Renderer mobile
    if ($LASTEXITCODE -ne 0) { throw "Failed Mobile check $kartJob" }
}
