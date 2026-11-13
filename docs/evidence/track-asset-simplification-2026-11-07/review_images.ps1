$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class TrackReviewPixels {
    public static int[] Inspect(string first, string second) {
        using (var a = new Bitmap(first)) using (var b = new Bitmap(second)) {
            int w = a.Width, h = a.Height;
            var region = new Rectangle(0, 0, w, h);
            var pa = a.LockBits(region, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var pb = b.LockBits(region, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var aa = new byte[pa.Stride * h]; var bb = new byte[pb.Stride * h];
            Marshal.Copy(pa.Scan0, aa, 0, aa.Length); Marshal.Copy(pb.Scan0, bb, 0, bb.Length);
            int changed = 0, foreground = 0, lowX = w, lowY = h, highX = 0, highY = 0;
            int bg = 20 * pa.Stride + 20 * 4;
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int i = y * pa.Stride + x * 4;
                bool diff = false, objectA = false, objectB = false;
                for (int channel = 0; channel < 3; channel++) {
                    diff |= Math.Abs(aa[i + channel] - bb[i + channel]) > 8;
                    objectA |= Math.Abs(aa[i + channel] - aa[bg + channel]) > 8;
                    objectB |= Math.Abs(bb[i + channel] - bb[bg + channel]) > 8;
                }
                if (diff) changed++;
                if (objectA) foreground++;
                if (objectA || objectB) { lowX = Math.Min(lowX, x); lowY = Math.Min(lowY, y); highX = Math.Max(highX, x); highY = Math.Max(highY, y); }
            }
            a.UnlockBits(pa); b.UnlockBits(pb);
            return new int[] { changed, foreground, lowX, lowY, highX, highY };
        }
    }
}
'@
$basePath = $PSScriptRoot
$observations = New-Object System.Collections.Generic.List[object]
foreach ($renderer in @('gl_compatibility', 'mobile')) {
    $folder = Join-Path $basePath $renderer
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'report.json'))) { continue }
    $report = Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json
    foreach ($row in $report.rows) {
        $stem = "$($row.theme)-$($row.kind)-$($row.view)"
        foreach ($version in @('lod', 'firstlod')) {
            $pixels = [TrackReviewPixels]::Inspect((Join-Path $folder "$stem-original.png"), (Join-Path $folder "$stem-$version.png"))
            $observations.Add([pscustomobject]@{renderer=$renderer; theme=$row.theme; kind=$row.kind; view=$row.view; version=$version; changed_pixels_over_8=$pixels[0]; foreground_and_shadow_pixels=$pixels[1]; changed_to_foreground_ratio=([double]$pixels[0]/[Math]::Max(1,$pixels[1]))})
        }
    }
    $sets = @(
        @('winter-ice_compact','winter-snow_castle','pine-container','night_city-abandoned_warehouse','pine-parked_car','pine-tree'),
        @('desert-egypt_pyramid','winter-igloo','desert-egypt_column','pine-grandstand','pine-crate','pine-tyre_wall')
    )
    for ($set = 0; $set -lt $sets.Count; $set++) {
        foreach ($view in @('race_front','close_front')) {
            $canvas = New-Object System.Drawing.Bitmap(1000, 1980)
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            $graphics.Clear([System.Drawing.Color]::FromArgb(27,31,35))
            $font = New-Object System.Drawing.Font('Arial', 13)
            for ($index = 0; $index -lt $sets[$set].Count; $index++) {
                $stem = "$($sets[$set][$index])-$view"
                $originalPath = Join-Path $folder "$stem-original.png"
                $reducedPath = Join-Path $folder "$stem-firstlod.png"
                $pixels = [TrackReviewPixels]::Inspect($originalPath,$reducedPath)
                $left = [Math]::Max(0,$pixels[2]-16); $top = [Math]::Max(0,$pixels[3]-16)
                $width = [Math]::Min(1280,$pixels[4]+17)-$left; $height = [Math]::Min(720,$pixels[5]+17)-$top
                $row = $report.rows | Where-Object { "$($_.theme)-$($_.kind)-$($_.view)" -eq $stem }
                $title = "$($row.kind) | primitives $($row.original_primitives) to $($row.first_lod_primitives)"
                $graphics.DrawString($title,$font,[System.Drawing.Brushes]::White,15,($index*330+4))
                for ($column = 0; $column -lt 2; $column++) {
                    $path = if ($column -eq 0) { $originalPath } else { $reducedPath }
                    $image = [System.Drawing.Image]::FromFile($path)
                    $scale = [Math]::Min(1.0,[Math]::Min(480.0/$width,275.0/$height))
                    $destWidth = [int]($width*$scale); $destHeight = [int]($height*$scale)
                    $destination = New-Object System.Drawing.Rectangle(($column*500+(500-$destWidth)/2),($index*330+48+(275-$destHeight)/2),$destWidth,$destHeight)
                    $source = New-Object System.Drawing.Rectangle($left,$top,$width,$height)
                    $graphics.DrawImage($image,$destination,$source,[System.Drawing.GraphicsUnit]::Pixel)
                    $label = if ($column -eq 0) { 'Original' } else { 'Forced first LOD prototype' }
                    $graphics.DrawString($label,$font,[System.Drawing.Brushes]::White,($column*500+15),($index*330+27))
                    $image.Dispose()
                }
            }
            $canvas.Save((Join-Path $folder "comparison-$set-$view.png"),[System.Drawing.Imaging.ImageFormat]::Png)
            if ($set -eq 0 -and $view -eq 'race_front') {
                $crop = $canvas.Clone((New-Object System.Drawing.Rectangle(0,0,1000,990)),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $crop.Save((Join-Path $folder 'recommended-racing-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
                $crop.Dispose()
            }
            $graphics.Dispose(); $font.Dispose(); $canvas.Dispose()
        }
    }
}
$observations | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $basePath 'pixel-observations.json') -Encoding UTF8
Write-Output "Pixel comparisons: $($observations.Count)"
