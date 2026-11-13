$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$reviewRoot = Join-Path (Get-Location).Path 'docs/evidence/asset-review-2026-11-08'
$pairs = @(
    @('Road packing: 72.5% fewer buffer bytes', 'indexed-road-close'),
    @('Winter tree packing: 20.2% fewer buffer bytes', 'indexed-winter-tree-close'),
    @('Tyres, 16 sides: 22.7% fewer triangles', 'radial-tyres-16-close'),
    @('Tyres, 12 sides: 34.7% fewer triangles', 'radial-tyres-12-close')
)
$sheet = New-Object System.Drawing.Bitmap(1280, 1610)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(18,27,34))
$font = New-Object System.Drawing.Font('Segoe UI', 18)
$title = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$brush = [System.Drawing.Brushes]::White
$graphics.DrawString('CURRENT', $title, $brush, 20, 12)
$graphics.DrawString('REVIEW CANDIDATE', $title, $brush, 656, 12)
for ($index=0; $index -lt $pairs.Count; $index++) {
    $top = 56 + $index*386
    $graphics.DrawString($pairs[$index][0], $font, $brush, 20, $top)
    foreach ($side in @(0,1)) {
        $suffix = if ($side -eq 0) { 'original' } else { 'candidate' }
        $path = Join-Path $reviewRoot ('candidates-gl-accepted/'+$pairs[$index][1]+'-'+$suffix+'.png')
        $bitmap = [System.Drawing.Image]::FromFile($path)
        $graphics.DrawImage($bitmap, [System.Drawing.RectangleF]::new([single](16+$side*636),[single]($top+36),[single]620,[single]348.75))
        $bitmap.Dispose()
    }
}
$sheet.Save((Join-Path $reviewRoot 'comparisons.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $sheet.Dispose(); $font.Dispose(); $title.Dispose()
Write-Output 'Saved current/candidate comparison sheet.'
