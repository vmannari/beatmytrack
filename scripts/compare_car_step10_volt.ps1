$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$stepRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-step10-2026-11-15'
$stepFrames=Join-Path $stepRoot 'prepared-gl_compatibility'
$stepCanvas=New-Object System.Drawing.Bitmap(2000,810)
$stepGraphics=[System.Drawing.Graphics]::FromImage($stepCanvas)
$stepFont=New-Object System.Drawing.Font('Segoe UI',18)
try {
    $stepGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $stepGraphics.DrawString('Before: buried/broken seams and handles',$stepFont,[System.Drawing.Brushes]::White,15,10)
    $stepGraphics.DrawString('After: refitted details and another 10% reduction',$stepFont,[System.Drawing.Brushes]::White,1015,10)
    for($stepSide=0;$stepSide -lt 2;$stepSide++) {
        $stepSuffix=@('before','after')[$stepSide]
        $stepImage=[System.Drawing.Image]::FromFile((Join-Path $stepFrames ('electric-stock-doors-left-'+$stepSuffix+'.png')))
        try {$stepGraphics.DrawImage($stepImage,($stepSide*1000),50,1000,760)}
        finally {$stepImage.Dispose()}
    }
    $stepCanvas.Save((Join-Path $stepRoot 'volt-door-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$stepFont.Dispose();$stepGraphics.Dispose();$stepCanvas.Dispose()}
