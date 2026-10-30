param([string]$Phase = 'geometry')
$ErrorActionPreference = 'Stop'
$jobs = switch ($Phase) {
    'geometry' { @('bodywork','retained','shape','construction','fit','proportions') }
    'visual' { @('model','bodywork-view','native') }
    'assets' { @('art','liveries','news','header','import') }
    'checks' { @('handling','parser') }
    default { throw "Unknown phase $Phase" }
}
foreach ($kartJob in $jobs) {
    & "$PSScriptRoot/run.ps1" -Job $kartJob
    if ($LASTEXITCODE -ne 0) { throw "Kart finishing failed: $kartJob" }
}
