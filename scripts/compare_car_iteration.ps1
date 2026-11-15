$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iterationRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-iteration-01-2026-11-15'
$iterationFrames = Join-Path $iterationRoot 'prepared-gl_compatibility'
$iterationFont = New-Object System.Drawing.Font('Segoe UI',15)
$iterationShots = @('front','rear','hardware-rear')
$iterationCanvas = New-Object System.Drawing.Bitmap(1200,1480)
$iterationGraphics = [System.Drawing.Graphics]::FromImage($iterationCanvas)
try {
    $iterationGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $iterationGraphics.DrawString('BEFORE: 26,472 triangles',$iterationFont,[System.Drawing.Brushes]::White,10,8)
    $iterationGraphics.DrawString('ITERATION 1: 23,370 (-11.7%)',$iterationFont,[System.Drawing.Brushes]::White,610,8)
    for ($iterationRow=0; $iterationRow -lt $iterationShots.Count; $iterationRow++) {
        for ($iterationColumn=0; $iterationColumn -lt 2; $iterationColumn++) {
            $iterationSuffix = @('before','after')[$iterationColumn]
            $iterationPath = Join-Path $iterationFrames ('forklift-stock-'+$iterationShots[$iterationRow]+'-'+$iterationSuffix+'.png')
            $iterationImage = [System.Drawing.Image]::FromFile($iterationPath)
            try { $iterationGraphics.DrawImage($iterationImage,($iterationColumn*600),(40+$iterationRow*480),600,456) }
            finally { $iterationImage.Dispose() }
        }
    }
    $iterationCanvas.Save((Join-Path $iterationRoot 'forklift-before-after.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
} finally { $iterationGraphics.Dispose(); $iterationCanvas.Dispose(); $iterationFont.Dispose() }
Write-Output 'ITERATION_COMPARISONS: three matching before/after Forklift views.'
