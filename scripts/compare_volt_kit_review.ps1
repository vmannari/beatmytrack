param([string]$Phase = 'before', [string]$Renderer = 'gl_compatibility', [string]$Shot = 'detail')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$reviewRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/volt-kit-review-2026-11-17'
$reviewFrames = Join-Path $reviewRoot ($Phase + '-' + $Renderer)
$reviewFont = New-Object System.Drawing.Font('Segoe UI', 12)
try {
    foreach ($reviewCategory in @('hood', 'aero', 'rims', 'body')) {
        if ($Shot -eq 'extra' -and $reviewCategory -eq 'aero') { continue }
        foreach ($reviewQuality in @('full', 'simple')) {
            $reviewFiles = @(Get-ChildItem -LiteralPath $reviewFrames -Filter ($reviewCategory + '-*-' + $reviewQuality + '-' + $Shot + '.png') | Sort-Object Name)
            if ($reviewFiles.Count -ne 16) { throw 'Sixteen options are required in each sheet.' }
            $reviewCanvas = New-Object System.Drawing.Bitmap(1280, 920)
            $reviewGraphics = [System.Drawing.Graphics]::FromImage($reviewCanvas)
            try {
                $reviewGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#172129'))
                for ($reviewIndex = 0; $reviewIndex -lt 16; $reviewIndex++) {
                    $reviewX = ($reviewIndex % 4) * 320
                    $reviewY = [Math]::Floor($reviewIndex / 4) * 230
                    $reviewImage = [System.Drawing.Image]::FromFile($reviewFiles[$reviewIndex].FullName)
                    try { $reviewGraphics.DrawImage($reviewImage, $reviewX, $reviewY, 320, 204) }
                    finally { $reviewImage.Dispose() }
                    $reviewLabel = $reviewFiles[$reviewIndex].Name.Split('-')[1]
                    $reviewGraphics.DrawString($reviewLabel, $reviewFont, [System.Drawing.Brushes]::White, ($reviewX + 4), ($reviewY + 207))
                }
                $reviewSuffix = if ($Shot -eq 'detail') { '' } else { '-' + $Shot }
                $reviewCanvas.Save((Join-Path $reviewRoot ($Phase + '-' + $Renderer + '-' + $reviewCategory + '-' + $reviewQuality + $reviewSuffix + '.jpg')), [System.Drawing.Imaging.ImageFormat]::Jpeg)
            }
            finally {
                $reviewGraphics.Dispose()
                $reviewCanvas.Dispose()
            }
        }
    }
}
finally { $reviewFont.Dispose() }
