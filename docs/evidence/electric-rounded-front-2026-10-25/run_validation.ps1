$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $repo
$entry = Join-Path $repo 'scripts/dev.ps1'
$logRoot = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$results = [Collections.Generic.List[object]]::new()
function Check([string]$name, [string[]]$arguments) {
    $command = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ' + ($arguments -join ' ')
    Write-Host $command
    & powershell -NoProfile -ExecutionPolicy Bypass -File $entry @arguments 2>&1 | Tee-Object -FilePath (Join-Path $logRoot "$name.log")
    $nativeExit = $LASTEXITCODE
    $results.Add([ordered]@{name=$name; command=$command; exit=$nativeExit})
    $results | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'validation.json')
    if ($nativeExit -ne 0) { throw "Failed validation: $name" }
}
Check 'model-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_model.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/model')
Check 'model-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_model.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/mobile-model')
Check 'rounded-front-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_rounded_front.gd','-Graphical','-RenderingMethod','gl_compatibility')
Check 'rounded-front-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_rounded_front.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/mobile-front')
Check 'hood-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/hood')
Check 'hood-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/mobile-hood')
Check 'surface' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_surface_finish.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25')
Check 'catalogue-art' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--bake-art')
Check 'livery-photos' @('-Action','TestScript','-ScriptPath','res://tests/bake_livery_previews.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--vehicle=electric')
$historicalNewsReport = Join-Path $repo 'docs/evidence/garage-news-rivalry-view-2026-10-17/framing.json'
$historicalNewsBytes = [IO.File]::ReadAllBytes($historicalNewsReport)
try {
    Check 'news-photo' @('-Action','TestScript','-ScriptPath','res://tests/bake_news_car_photos.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--vehicle=electric')
    Copy-Item -LiteralPath $historicalNewsReport -Destination (Join-Path $PSScriptRoot 'news-framing.json')
} finally { [IO.File]::WriteAllBytes($historicalNewsReport,$historicalNewsBytes) }
Check 'import' @('-Action','Import')
Check 'garage-race-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/native')
Check 'garage-race-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25/mobile-native')
Check 'electric' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25')
Check 'one-pedal' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_one_pedal.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-rounded-front-2026-10-25')
Check 'parser' @('-Action','TestScript','-ScriptPath','res://tests/test_script_parse.gd')
