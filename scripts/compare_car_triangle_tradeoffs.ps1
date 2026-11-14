$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class TriangleImageDiff {
    public static long[] Compare(string originalPath, string candidatePath) {
        using (var a = new Bitmap(originalPath)) using (var b = new Bitmap(candidatePath)) {
            if (a.Size != b.Size) throw new Exception("Image dimensions differ");
            var rect = new Rectangle(0, 0, a.Width, a.Height);
            var ad = a.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var bd = b.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                var aa = new byte[ad.Stride * a.Height]; var bb = new byte[bd.Stride * b.Height];
                Marshal.Copy(ad.Scan0, aa, 0, aa.Length); Marshal.Copy(bd.Scan0, bb, 0, bb.Length);
                long changed = 0, over8 = 0, total = 0, maximum = 0;
                for (int y = 0; y < a.Height; y++) for (int x = 0; x < a.Width; x++) {
                    int peak = 0;
                    for (int c = 0; c < 3; c++) {
                        int d = Math.Abs(aa[y*ad.Stride+x*4+c] - bb[y*bd.Stride+x*4+c]);
                        peak = Math.Max(peak, d); total += d;
                    }
                    if (peak > 0) changed++; if (peak > 8) over8++; maximum = Math.Max(maximum, peak);
                }
                return new long[] { changed, over8, total, maximum, a.Width * a.Height * 3L };
            } finally { a.UnlockBits(ad); b.UnlockBits(bd); }
        }
    }
}
'@
$triangleOut = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-triangle-review-2026-11-14'
$triangleMetrics = @{}
$triangleNames = @{ compact='Rally'; kart='Kart'; forklift='Forklift'; electric='Volt'; hovercraft='Hover'; super_rally='Challenger' }
$triangleFont = New-Object System.Drawing.Font('Segoe UI', 14)
$triangleSmallFont = New-Object System.Drawing.Font('Segoe UI', 12)
try {
    foreach ($triangleRenderer in @('gl_compatibility','mobile')) {
        $triangleDirectory = Join-Path $triangleOut $triangleRenderer
        $triangleData = Get-Content -LiteralPath (Join-Path $triangleDirectory 'native.json') -Raw | ConvertFrom-Json
        foreach ($triangleRow in $triangleData.rows) {
            foreach ($triangleView in $triangleRow.views) {
                $trianglePairs = @()
                $trianglePairs += ,@($triangleView.master.image,$triangleView.restored.image)
                foreach ($triangleLevel in $triangleView.lod_levels) { $trianglePairs += ,@($triangleView.production.image,$triangleLevel.image) }
                foreach ($triangleVariant in $triangleRow.candidates) {
                    $triangleCapture = $triangleVariant.captures | Where-Object { $_.image -like ('*-'+$triangleView.view+'-*') }
                    $trianglePairs += ,@($triangleView.master.image,$triangleCapture.image)
                }
                foreach ($trianglePair in $trianglePairs) {
                    $triangleDiff = [TriangleImageDiff]::Compare((Join-Path $triangleDirectory $trianglePair[0]), (Join-Path $triangleDirectory $trianglePair[1]))
                    $triangleMetrics[($triangleRenderer+'/'+$trianglePair[1])] = @{
                        changed_pixels=$triangleDiff[0]; pixels_over_8=$triangleDiff[1]
                        mean_rgb_delta_255=[Math]::Round($triangleDiff[2]/$triangleDiff[4],6); max_delta_255=$triangleDiff[3]
                    }
                }
            }
        }
        foreach ($triangleShot in @('front','distant')) {
            $triangleSheet = New-Object System.Drawing.Bitmap(1480,1995)
            $triangleGraphics = [System.Drawing.Graphics]::FromImage($triangleSheet)
            try {
                $triangleGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
                $triangleHeaders = @('Current master','Mild candidate','Medium candidate','Coarse candidate')
                for ($triangleColumn=0; $triangleColumn -lt 4; $triangleColumn++) {
                    $triangleGraphics.DrawString($triangleHeaders[$triangleColumn],$triangleFont,[System.Drawing.Brushes]::White,($triangleColumn*370+10),12)
                }
                for ($triangleIndex=0; $triangleIndex -lt $triangleData.rows.Count; $triangleIndex++) {
                    $triangleRow = $triangleData.rows[$triangleIndex]
                    $triangleLevels = @('master','mild','medium','coarse')
                    $triangleCounts = @($triangleRow.baseline.triangles) + @($triangleRow.candidates | ForEach-Object { $_.triangles })
                    for ($triangleColumn=0; $triangleColumn -lt 4; $triangleColumn++) {
                        $triangleImage = [System.Drawing.Image]::FromFile((Join-Path $triangleDirectory ($triangleRow.vehicle+'-'+$triangleShot+'-'+$triangleLevels[$triangleColumn]+'.png')))
                        try {
                            $triangleX = $triangleColumn*370
                            $triangleY = 45+$triangleIndex*325
                            $triangleRectangle = New-Object System.Drawing.Rectangle($triangleX,$triangleY,370,281)
                            $triangleGraphics.DrawImage($triangleImage,$triangleRectangle,0,0,1000,760,[System.Drawing.GraphicsUnit]::Pixel)
                            $triangleSaved = 100*(1-$triangleCounts[$triangleColumn]/$triangleRow.baseline.triangles)
                            $triangleLabel = '{0}  {1:N0} triangles  (-{2:N1}%)' -f $triangleNames[$triangleRow.vehicle],$triangleCounts[$triangleColumn],$triangleSaved
                            $triangleGraphics.DrawString($triangleLabel,$triangleSmallFont,[System.Drawing.Brushes]::White,($triangleX+10),($triangleY+286))
                        } finally { $triangleImage.Dispose() }
                    }
                }
                $triangleSheet.Save((Join-Path $triangleOut ($triangleRenderer+'-'+$triangleShot+'-comparison.png')))
            } finally { $triangleGraphics.Dispose(); $triangleSheet.Dispose() }
        }
    }
    $triangleMetrics | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $triangleOut 'pixel-metrics.json') -Encoding UTF8
    Write-Output ('CTR_IMAGES: '+$triangleMetrics.Count+' comparisons; four native contact sheets.')
} finally { $triangleFont.Dispose(); $triangleSmallFont.Dispose() }
