param([string]$Phase = 'draft')
$ErrorActionPreference = 'Stop'
if ($Phase -eq 'all') {
    & "$PSScriptRoot/run.ps1" -Job shape-before
    if ($LASTEXITCODE -ne 1) { throw 'Expected old driver to fail the shape review.' }
    & "$PSScriptRoot/verify.ps1" -Phase final
    & "$PSScriptRoot/verify.ps1" -Phase mobile
    exit 0
}
if ($Phase -eq 'draft') {
    & "$PSScriptRoot/run.ps1" -Job shape-before
    if ($LASTEXITCODE -ne 1) { throw 'Expected old driver to fail the shape review.' }
    $jobs = @('shape-draft','construction-draft','proportions-draft','fit-draft')
} elseif ($Phase -eq 'final') {
    $jobs = @('shape','construction','fit','proportions','model','retained','native','art','liveries','news','import','handling','parser')
} elseif ($Phase -eq 'mobile') {
    $jobs = @('model','native')
} else { throw 'Unknown phase' }
foreach ($kartShapeJob in $jobs) {
    if ($Phase -eq 'mobile') { & "$PSScriptRoot/run.ps1" -Job $kartShapeJob -Renderer mobile }
    else { & "$PSScriptRoot/run.ps1" -Job $kartShapeJob }
    if ($LASTEXITCODE -ne 0) { throw "Kart check failed: $kartShapeJob" }
}
