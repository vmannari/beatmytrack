$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$mechanicsRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-mechanics-2026-11-17'
$mechanicsFont = New-Object System.Drawing.Font('Segoe UI',14)
try {
    foreach ($mechanicsRenderer in @('gl_compatibility','mobile')) {
        $mechanicsFrames = Join-Path $mechanicsRoot ('prepared-'+$mechanicsRenderer)
        foreach ($mechanicsMode in @('stock','fitted')) {
            $mechanicsCanvas = New-Object System.Drawing.Bitmap(1000,1680)
            $mechanicsGraphics = [System.Drawing.Graphics]::FromImage($mechanicsCanvas)
            try {
                $mechanicsGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
                $mechanicsGraphics.DrawString('BEFORE / CURRENT - '+$mechanicsMode+' - '+$mechanicsRenderer,$mechanicsFont,[System.Drawing.Brushes]::White,8,6)
                $mechanicsRows = @(@('compact','front'),@('kart','helmet-side'),@('forklift','hardware-left'),@('hovercraft','rear'))
                for ($mechanicsRow=0; $mechanicsRow -lt $mechanicsRows.Count; $mechanicsRow++) {
                    $mechanicsRecord=$mechanicsRows[$mechanicsRow]
                    $mechanicsGraphics.DrawString(($mechanicsRecord -join ' / '),$mechanicsFont,[System.Drawing.Brushes]::White,8,(30+$mechanicsRow*410))
                    for ($mechanicsColumn=0; $mechanicsColumn -lt 2; $mechanicsColumn++) {
                        $mechanicsSuffix=@('before','after')[$mechanicsColumn]
                        $mechanicsName=$mechanicsRecord[0]+'-'+$mechanicsMode+'-'+$mechanicsRecord[1]+'-'+$mechanicsSuffix+'.png'
                        $mechanicsImage=[System.Drawing.Image]::FromFile((Join-Path $mechanicsFrames $mechanicsName))
                        try { $mechanicsGraphics.DrawImage($mechanicsImage,($mechanicsColumn*500),(56+$mechanicsRow*410),500,380) }
                        finally { $mechanicsImage.Dispose() }
                    }
                }
                $mechanicsCanvas.Save((Join-Path $mechanicsRoot ($mechanicsRenderer+'-'+$mechanicsMode+'-review.png')),[System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally { $mechanicsGraphics.Dispose(); $mechanicsCanvas.Dispose() }
        }
    }
}
finally { $mechanicsFont.Dispose() }
