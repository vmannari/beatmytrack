$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$coarseOut = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-coarse-models-2026-11-14'
$coarseNames = @{compact='Rally';kart='Kart';forklift='Forklift';electric='Volt';hovercraft='Hover';super_rally='Challenger'}
$coarseFont = New-Object System.Drawing.Font('Segoe UI',16)
try {
    foreach ($coarseRenderer in @('gl_compatibility','mobile')) {
        $coarseDirectory = Join-Path $coarseOut $coarseRenderer
        $coarseRows = (Get-Content -LiteralPath (Join-Path $coarseDirectory 'pairs.json') -Raw | ConvertFrom-Json).rows
        $coarseSheet = New-Object System.Drawing.Bitmap(1200,3000)
        $coarseDrawing = [System.Drawing.Graphics]::FromImage($coarseSheet)
        try {
            $coarseDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
            for ($coarseIndex=0; $coarseIndex -lt $coarseRows.Count; $coarseIndex++) {
                $coarseRow = $coarseRows[$coarseIndex]
                $coarseY = $coarseIndex*500
                $coarseLabel = '{0}: prior source {1:N0} / coarse {2:N0} triangles' -f $coarseNames[$coarseRow.vehicle],$coarseRow.before,$coarseRow.after
                $coarseDrawing.DrawString($coarseLabel,$coarseFont,[System.Drawing.Brushes]::White,10,$coarseY)
                for ($coarseColumn=0; $coarseColumn -lt 2; $coarseColumn++) {
                    $coarseSuffix = @('before','after')[$coarseColumn]
                    $coarseImage = [System.Drawing.Image]::FromFile((Join-Path $coarseDirectory ($coarseRow.vehicle+'-front-'+$coarseSuffix+'.png')))
                    try { $coarseDrawing.DrawImage($coarseImage,($coarseColumn*600),($coarseY+35),600,456) }
                    finally { $coarseImage.Dispose() }
                }
            }
            $coarseSheet.Save((Join-Path $coarseOut ($coarseRenderer+'-before-after.png')))
        } finally { $coarseDrawing.Dispose(); $coarseSheet.Dispose() }
    }
    Write-Output 'COARSE_COMPARISONS: six before/after rows per desktop renderer.'
} finally { $coarseFont.Dispose() }
