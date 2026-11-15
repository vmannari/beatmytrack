$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
$smoothRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/volt-reflection-smoothing-2026-11-15'
$smoothFrames=Join-Path $smoothRoot 'garage-source-gl_compatibility-decorated-sweep'
$smoothFont=New-Object System.Drawing.Font('Segoe UI',18)
$smoothGif=New-Object Windows.Media.Imaging.GifBitmapEncoder
$smoothSequence=0
try {
    foreach($smoothAngle in @(0,1,2,3,4,5,6,7,6,5,4,3,2,1)) {
        $smoothCanvas=New-Object System.Drawing.Bitmap(1600,1280)
        $smoothGraphics=[System.Drawing.Graphics]::FromImage($smoothCanvas)
        try {
            $smoothGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
            $smoothGraphics.DrawString('Before: 15,254 triangles',$smoothFont,[System.Drawing.Brushes]::White,12,10)
            $smoothGraphics.DrawString('After: 21,309 triangles',$smoothFont,[System.Drawing.Brushes]::White,812,10)
            for($smoothRow=0;$smoothRow -lt 2;$smoothRow++) {
                $smoothView=@('front-arch-left','corner-right')[$smoothRow]
                for($smoothColumn=0;$smoothColumn -lt 2;$smoothColumn++) {
                    $smoothSuffix=@('before','after')[$smoothColumn]
                    $smoothImage=[System.Drawing.Image]::FromFile((Join-Path $smoothFrames ('electric-stock-'+$smoothView+'-sweep-'+$smoothAngle+'-'+$smoothSuffix+'.png')))
                    try {$smoothGraphics.DrawImage($smoothImage,($smoothColumn*800),(55+$smoothRow*610),800,608)}
                    finally {$smoothImage.Dispose()}
                }
            }
            $smoothPath=Join-Path $smoothRoot ('reflection-frame-'+$smoothSequence+'.png')
            $smoothCanvas.Save($smoothPath,[System.Drawing.Imaging.ImageFormat]::Png)
            if($smoothAngle -eq 0) {$smoothCanvas.Save((Join-Path $smoothRoot 'reflection-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)}
        } finally {$smoothGraphics.Dispose();$smoothCanvas.Dispose()}
        $smoothBitmap=[Windows.Media.Imaging.BitmapFrame]::Create([uri]$smoothPath)
        $smoothMetadata=New-Object Windows.Media.Imaging.BitmapMetadata('gif')
        $smoothMetadata.SetQuery('/grctlext/Delay',[uint16]45)
        $smoothFrame=[Windows.Media.Imaging.BitmapFrame]::Create($smoothBitmap,$smoothBitmap.Thumbnail,$smoothMetadata,$smoothBitmap.ColorContexts)
        $smoothGif.Frames.Add($smoothFrame)
        $smoothSequence++
    }
    $smoothStream=[IO.File]::Create((Join-Path $smoothRoot 'reflection-sweep.gif'))
    try {$smoothGif.Save($smoothStream)} finally {$smoothStream.Dispose()}
} finally {$smoothFont.Dispose()}
