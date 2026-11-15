$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$rallyEvidence=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/rally-front-2026-11-15'
$rallyFrames=Join-Path $rallyEvidence 'prepared-gl_compatibility'
$rallyCanvas=New-Object System.Drawing.Bitmap(1600,2500)
$rallyGraphics=[System.Drawing.Graphics]::FromImage($rallyCanvas)
$rallyFont=New-Object System.Drawing.Font('Segoe UI',19)
try {
    $rallyGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $rallyGraphics.DrawString('BEFORE: grille + lamps 2,638 triangles',$rallyFont,[System.Drawing.Brushes]::White,15,8)
    $rallyGraphics.DrawString('REFINED: 1,846 (-30.0%)',$rallyFont,[System.Drawing.Brushes]::White,815,8)
    $rallyShots=@('head-on','lamp-close','grille-close','oblique-close')
    for($rallyRow=0;$rallyRow -lt $rallyShots.Count;$rallyRow++) {
        for($rallyColumn=0;$rallyColumn -lt 2;$rallyColumn++) {
            $rallySide=@('before','after')[$rallyColumn]
            $rallyImage=[System.Drawing.Image]::FromFile((Join-Path $rallyFrames ('compact-stock-'+$rallyShots[$rallyRow]+'-'+$rallySide+'.png')))
            try { $rallyGraphics.DrawImage($rallyImage,($rallyColumn*800),(55+$rallyRow*608),800,608) }
            finally {$rallyImage.Dispose()}
        }
    }
    $rallyCanvas.Save((Join-Path $rallyEvidence 'front-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$rallyGraphics.Dispose();$rallyCanvas.Dispose();$rallyFont.Dispose()}
