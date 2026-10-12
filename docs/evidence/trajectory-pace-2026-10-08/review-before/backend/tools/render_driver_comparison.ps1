param([string]$Evidence = 'docs/evidence/predictive-drivers-2026-10-07')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bmtRows = Import-Csv -LiteralPath (Join-Path $Evidence 'comparison.csv')
$bmtMaximum = ($bmtRows | ForEach-Object { [double]$_.old_seconds } | Measure-Object -Maximum).Maximum
$bmtBitmap = New-Object System.Drawing.Bitmap(1000,1040)
$bmtGraphics = [System.Drawing.Graphics]::FromImage($bmtBitmap)
$bmtGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bmtGraphics.Clear([System.Drawing.Color]::WhiteSmoke)
$bmtInk = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(23,34,56))
$bmtOld = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(134,144,159))
$bmtNew = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,169,43))
$bmtTitle = New-Object System.Drawing.Font('Arial',16)
$bmtFont = New-Object System.Drawing.Font('Arial',10)
$bmtSmall = New-Object System.Drawing.Font('Arial',8)
try {
    $bmtGraphics.DrawString('Five-lap artificial-driver benchmark - 27 tracks',$bmtTitle,$bmtInk,28,18)
    $bmtGraphics.DrawString('Identical canonical manifests; final recordings independently verified. Gray: old, gold: predictive.',$bmtFont,$bmtInk,28,48)
    for ($bmtIndex=0; $bmtIndex -lt $bmtRows.Count; $bmtIndex++) {
        $bmtRow = $bmtRows[$bmtIndex]
        $bmtY = 88+$bmtIndex*33
        $bmtGraphics.DrawString($bmtRow.track,$bmtFont,$bmtInk,28,$bmtY+3)
        if ($bmtRow.old_finished -eq 'True') {
            $bmtGraphics.FillRectangle($bmtOld,205,$bmtY,[single]([double]$bmtRow.old_seconds/$bmtMaximum*590),10)
        } else { $bmtGraphics.DrawString('Old driver did not finish',$bmtSmall,$bmtInk,205,$bmtY-2) }
        $bmtGraphics.FillRectangle($bmtNew,205,$bmtY+13,[single]([double]$bmtRow.new_seconds/$bmtMaximum*590),10)
        $bmtLabel = '{0:F2}s' -f [double]$bmtRow.new_seconds
        if ($bmtRow.gain_percent) {
            $bmtDirection = if ([double]$bmtRow.gain_percent -ge 0) { 'faster' } else { 'slower' }
            $bmtLabel += ' ({0:F1}% {1})' -f ([math]::Abs([double]$bmtRow.gain_percent)),$bmtDirection
        }
        $bmtGraphics.DrawString($bmtLabel,$bmtSmall,$bmtInk,805,$bmtY+10)
    }
    $bmtGraphics.DrawString('Reference/actual telemetry and exact inputs accompany the report. Desktop measurement; four tracks remain slower.',$bmtFont,$bmtInk,28,1010)
    $bmtBitmap.Save((Join-Path (Resolve-Path -LiteralPath $Evidence) 'comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $bmtGraphics.Dispose(); $bmtBitmap.Dispose()
    foreach ($bmtDisposable in @($bmtInk,$bmtOld,$bmtNew,$bmtTitle,$bmtFont,$bmtSmall)) { $bmtDisposable.Dispose() }
}
