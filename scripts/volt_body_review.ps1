# Native Garage contact sheets and pixel differences; built-in Windows drawing.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class VoltBodyReview {
    public static int Difference(string left, string right, int threshold = 12) {
        using (Bitmap a = new Bitmap(left)) using (Bitmap b = new Bitmap(right)) {
            Rectangle rect = new Rectangle(0, 0, a.Width, a.Height);
            BitmapData ad = a.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData bd = b.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                byte[] aa = new byte[Math.Abs(ad.Stride)*a.Height];
                byte[] bb = new byte[Math.Abs(bd.Stride)*b.Height];
                Marshal.Copy(ad.Scan0, aa, 0, aa.Length);
                Marshal.Copy(bd.Scan0, bb, 0, bb.Length);
                int count=0;
                for (int y=0; y<a.Height; y++) for (int x=0; x<a.Width; x++) {
                    int p=y*ad.Stride+x*4, q=y*bd.Stride+x*4;
                    if (Math.Abs(aa[p]-bb[q])>threshold || Math.Abs(aa[p+1]-bb[q+1])>threshold || Math.Abs(aa[p+2]-bb[q+2])>threshold) count++;
                }
                return count;
            } finally { a.UnlockBits(ad); b.UnlockBits(bd); }
        }
    }
}
'@
$reviewRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/volt-body-refinement-2026-11-03'
$choices = @('street','sport','club','touring','track','endurance','carbon','blade','sweep','wide','split','gt','aero','stealth','race')
$font = New-Object System.Drawing.Font('Segoe UI', 11)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#d5e2e7'))
$sheet = New-Object System.Drawing.Bitmap(1280,3030)
$drawing = [System.Drawing.Graphics]::FromImage($sheet)
$drawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#131c22'))
$drawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$rows = @()
for ($row=0; $row -lt $choices.Count; $row++) {
    $name = 'volt_' + $choices[$row]
    $views = @('quarter','side','rear_quarter')
    $drawing.DrawString($choices[$row].ToUpper(),$font,$brush,[single]12,[single]($row*202+2))
    for ($column=0; $column -lt 3; $column++) {
        $path = Join-Path $reviewRoot ('compatibility/silver_' + $name + '_' + $views[$column] + '.png')
        $picture = [System.Drawing.Image]::FromFile($path)
        try { $drawing.DrawImage($picture,[int]($column*426),[int]($row*202+22),426,180) } finally { $picture.Dispose() }
    }
    $before = Join-Path $reviewRoot ('before/silver_' + $name + '_quarter.png')
    $figures = ''
    if (Test-Path -LiteralPath $before) { $figures += '<figure><img src="before/silver_' + $name + '_quarter.png"><figcaption>Before</figcaption></figure>' }
    foreach ($view in $views) { $figures += '<figure><img src="compatibility/silver_' + $name + '_' + $view + '.png"><figcaption>' + $view.Replace('_',' ') + '</figcaption></figure>' }
    $rows += '<section><h2>' + $choices[$row] + '</h2><div>' + $figures + '</div></section>'
}
$sheet.Save((Join-Path $reviewRoot 'all-body-kits.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
$drawing.Dispose(); $sheet.Dispose()
$pairs = @(@('sport','quarter'),@('sport','side'),@('gt','rear_quarter'),@('carbon','quarter'),@('race','side'),@('race','rear'))
$sheet = New-Object System.Drawing.Bitmap(1280,2280)
$drawing = [System.Drawing.Graphics]::FromImage($sheet)
$drawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#131c22'))
$drawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($row=0; $row -lt $pairs.Count; $row++) {
    $option,$view = $pairs[$row]
    $drawing.DrawString(($option.ToUpper() + ' / ' + $view + '    BEFORE / AFTER'),$font,$brush,[single]12,[single]($row*380+2))
    for ($column=0; $column -lt 2; $column++) {
        $folder = @('before','compatibility')[$column]
        $picture = [System.Drawing.Image]::FromFile((Join-Path $reviewRoot ($folder+'/silver_volt_'+$option+'_'+$view+'.png')))
        try { $drawing.DrawImage($picture,[int]($column*640),[int]($row*380+20),640,360) } finally { $picture.Dispose() }
    }
}
$sheet.Save((Join-Path $reviewRoot 'before-after.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
$drawing.Dispose(); $sheet.Dispose(); $font.Dispose(); $brush.Dispose()
$html = '<!doctype html><meta charset="utf-8"><title>Volt body kit review</title><style>body{background:#131c22;color:#d5e2e7;font:16px system-ui;margin:30px}section{margin:35px 0}section div{display:flex;flex-wrap:wrap}figure{margin:5px;flex:1;min-width:300px}img{width:100%}figcaption{padding:8px}h2{font-size:21px}</style><h1>Volt body kits</h1><p>Native Garage captures, 3 November 2026. All revised options in Compatibility, with original comparisons where captured. Desktop Mobile images are in the adjacent mobile folder.</p>'
[IO.File]::WriteAllText((Join-Path $reviewRoot 'review.html'),($html + ($rows -join "`n")))
$measurements = [ordered]@{}
foreach ($view in @('quarter','front','side','rear_quarter','rear')) {
    $original = Join-Path $reviewRoot ('compatibility/silver_stock_'+$view+'.png')
    foreach ($choice in $choices) {
        $name = 'silver_volt_'+$choice+'_'+$view+'.png'
        $measurements[$name] = [VoltBodyReview]::Difference($original,(Join-Path $reviewRoot ('compatibility/'+$name)))
    }
}
$minimum = ($measurements.Values | Measure-Object -Minimum).Minimum
$result = @{threshold=12; required_pixels=1500; min_pixels=$minimum; views=$measurements.Count; values=$measurements}
[IO.File]::WriteAllText((Join-Path $reviewRoot 'visible-differences.json'),(($result | ConvertTo-Json -Depth 5) + "`n"))
$originals = [ordered]@{}
foreach ($colour in @('silver','blue')) {
    foreach ($view in @('quarter','front','side','rear_quarter','rear')) {
        $name = $colour + '_stock_' + $view + '.png'
        $originals[$name] = [VoltBodyReview]::Difference((Join-Path $reviewRoot ('before/'+$name)),(Join-Path $reviewRoot ('compatibility/'+$name)),0)
    }
}
[IO.File]::WriteAllText((Join-Path $reviewRoot 'original-pixel-differences.json'),(($originals | ConvertTo-Json) + "`n"))
Write-Output ("Saved review, contact sheets and " + $measurements.Count + " pixel comparisons; minimum=" + $minimum)
Write-Output ("Original changed RGB pixels across ten views: " + (($originals.Values | Measure-Object -Sum).Sum))
if ($minimum -lt 1500) { throw 'A body-kit view is below the existing visibility gate.' }
