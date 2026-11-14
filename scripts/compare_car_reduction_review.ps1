$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$carReductionRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-reduction-review-2026-11-13'
$carReductionRows = @(
    @('Forklift: axial rings', 'gl_compatibility-axial/forklift-axial-front'),
    @('Rally: conservative indices', 'gl_compatibility/compact-lod1mm-front'),
    @('Volt: conservative indices', 'gl_compatibility/electric-lod1mm-front'),
    @('Kart: static helmet detail', 'gl_compatibility/kart-lod1mm-front'),
    @('Hover: rings (distance candidate)', 'gl_compatibility-hover/hovercraft-hover-rings-rear')
)
$carReductionSheet = New-Object System.Drawing.Bitmap(1200,2450)
$carReductionDrawing = [System.Drawing.Graphics]::FromImage($carReductionSheet)
$carReductionDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#18232c'))
$carReductionFont = New-Object System.Drawing.Font('Segoe UI',15)
for ($carReductionRow=0; $carReductionRow -lt $carReductionRows.Count; $carReductionRow++) {
    $carReductionY = $carReductionRow*490
    $carReductionDrawing.DrawString(($carReductionRows[$carReductionRow][0]+' | CURRENT / CANDIDATE'),$carReductionFont,[System.Drawing.Brushes]::White,[single]8,[single]$carReductionY)
    for ($carReductionColumn=0; $carReductionColumn -lt 2; $carReductionColumn++) {
        $carReductionSuffix = @('-before.png','-candidate.png')[$carReductionColumn]
        $carReductionImage = [System.Drawing.Image]::FromFile((Join-Path $carReductionRoot ($carReductionRows[$carReductionRow][1]+$carReductionSuffix)))
        $carReductionDrawing.DrawImage($carReductionImage,[int]($carReductionColumn*600),[int]($carReductionY+28),600,456)
        $carReductionImage.Dispose()
    }
}
$carReductionSheet.Save((Join-Path $carReductionRoot 'candidate-comparisons.png'))
$carReductionDrawing.Dispose()
$carReductionSheet.Dispose()
$carReductionFont.Dispose()
Write-Output 'CAR_REDUCTION_COMPARISONS: five native before/candidate pairs saved.'
