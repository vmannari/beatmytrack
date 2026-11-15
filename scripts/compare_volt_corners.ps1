$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$cornerRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/volt-rear-corners-2026-11-15'
$cornerFrames=Join-Path $cornerRoot 'prepared-gl_compatibility'
$cornerCanvas=New-Object System.Drawing.Bitmap(1600,1280)
$cornerGraphics=[System.Drawing.Graphics]::FromImage($cornerCanvas)
$cornerFont=New-Object System.Drawing.Font('Segoe UI',18)
try {
    $cornerGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $cornerGraphics.DrawString('Before: 14,217 triangles',$cornerFont,[System.Drawing.Brushes]::White,12,10)
    $cornerGraphics.DrawString('After local repair: 15,254 triangles',$cornerFont,[System.Drawing.Brushes]::White,812,10)
    for($cornerRow=0;$cornerRow -lt 2;$cornerRow++) {
        $cornerView=@('corner-left','corner-right')[$cornerRow]
        for($cornerColumn=0;$cornerColumn -lt 2;$cornerColumn++) {
            $cornerSuffix=@('before','after')[$cornerColumn]
            $cornerImage=[System.Drawing.Image]::FromFile((Join-Path $cornerFrames ('electric-stock-'+$cornerView+'-'+$cornerSuffix+'.png')))
            try {$cornerGraphics.DrawImage($cornerImage,($cornerColumn*800),(55+$cornerRow*610),800,608)}
            finally {$cornerImage.Dispose()}
        }
    }
    $cornerCanvas.Save((Join-Path $cornerRoot 'rear-corners-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$cornerFont.Dispose();$cornerGraphics.Dispose();$cornerCanvas.Dispose()}
