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
Check 'fairing-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood_fairing.gd','-Graphical','-RenderingMethod','gl_compatibility')
Check 'fairing-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood_fairing.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-fairing')
Check 'quality-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_quality.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/quality')
Check 'quality-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_quality.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-quality')
Check 'model-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_model.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/model')
Check 'model-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_model.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-model')
Check 'smooth-nose-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_smooth_nose.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/nose')
Check 'retained-front' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_rounded_front.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/rounded')
Check 'smooth-nose-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_smooth_nose.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-nose')
Check 'hood-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/hood')
Check 'hood-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_hood.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-hood')
Check 'surface' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_surface_finish.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26')
Check 'catalogue-art' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--bake-art')
Check 'livery-photos' @('-Action','TestScript','-ScriptPath','res://tests/bake_livery_previews.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--vehicle=electric')
$historicalNewsReport = Join-Path $repo 'docs/evidence/garage-news-rivalry-view-2026-10-17/framing.json'
$historicalNewsBytes = [IO.File]::ReadAllBytes($historicalNewsReport)
try {
    Check 'news-photo' @('-Action','TestScript','-ScriptPath','res://tests/bake_news_car_photos.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--vehicle=electric')
    Copy-Item -LiteralPath $historicalNewsReport -Destination (Join-Path $PSScriptRoot 'news-framing.json')
} finally { [IO.File]::WriteAllBytes($historicalNewsReport,$historicalNewsBytes) }
Check 'import' @('-Action','Import')
Check 'garage-race-compatibility' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/native')
Check 'garage-race-mobile' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car_ui.gd','-Graphical','-RenderingMethod','mobile','-RenderingDriver','vulkan','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26/mobile-native')
Check 'electric' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_car.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26')
Check 'one-pedal' @('-Action','TestScript','-ScriptPath','res://tests/test_electric_one_pedal.gd','-TestArgument','--evidence-root=res://../docs/evidence/electric-hood-fairing-2026-10-26')
Check 'parser' @('-Action','TestScript','-ScriptPath','res://tests/test_script_parse.gd')
