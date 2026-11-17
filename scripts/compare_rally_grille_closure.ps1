$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$cornerRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/rally-grille-closure-2026-11-16'
$cornerFrames=Join-Path $cornerRoot 'views-gl_compatibility'
$cornerCanvas=New-Object System.Drawing.Bitmap(1600,1660)
$cornerGraphics=[System.Drawing.Graphics]::FromImage($cornerCanvas)
$cornerFont=New-Object System.Drawing.Font('Segoe UI',18)
try {
    $cornerGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $cornerGraphics.DrawString('Before fascia repair',$cornerFont,[System.Drawing.Brushes]::White,12,10)
    $cornerGraphics.DrawString('After fascia repair',$cornerFont,[System.Drawing.Brushes]::White,812,10)
    for($cornerRow=0;$cornerRow -lt 2;$cornerRow++) {
        $cornerView=@('front','low-left')[$cornerRow]
        for($cornerColumn=0;$cornerColumn -lt 2;$cornerColumn++) {
            $cornerSuffix=@('before','after')[$cornerColumn]
            $cornerImage=[System.Drawing.Image]::FromFile((Join-Path $cornerFrames ('stock-'+$cornerView+'-'+$cornerSuffix+'.png')))
            try {$cornerGraphics.DrawImage($cornerImage,($cornerColumn*800),(55+$cornerRow*800),800,800)}
            finally {$cornerImage.Dispose()}
        }
    }
    $cornerCanvas.Save((Join-Path $cornerRoot 'grille-closure-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$cornerFont.Dispose();$cornerGraphics.Dispose();$cornerCanvas.Dispose()}
