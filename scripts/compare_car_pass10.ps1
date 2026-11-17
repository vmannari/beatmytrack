$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$passRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-pass10-2026-11-16'
$passFrames=Join-Path $passRoot 'source-gl_compatibility-decorated'
$passCanvas=New-Object System.Drawing.Bitmap(1400,2810)
$passGraphics=[System.Drawing.Graphics]::FromImage($passCanvas)
$passFont=New-Object System.Drawing.Font('Segoe UI',16)
try {
 $passGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
 $passGraphics.DrawString('Before',$passFont,[System.Drawing.Brushes]::White,12,6)
 $passGraphics.DrawString('After',$passFont,[System.Drawing.Brushes]::White,712,6)
 $passCars=@('compact','kart','forklift','electric','hovercraft')
 $passLabels=@('Rally: 13,341 to 13,114 (-1.70%)','Kart: 16,628 to 16,396 (-1.40%)','Forklift: 18,116 to 17,794 (-1.78%)','Volt: 19,071 to 18,867 (-1.07%)','Hover: 14,856 to 14,145 (-4.79%)')
 for($passRow=0;$passRow -lt 5;$passRow++) {
  $passName=$passCars[$passRow]
  $passGraphics.DrawString($passLabels[$passRow],$passFont,[System.Drawing.Brushes]::White,12,(35+$passRow*550))
  for($passColumn=0;$passColumn -lt 2;$passColumn++) {
   $passSuffix=@('before','after')[$passColumn]
   $passImage=[System.Drawing.Image]::FromFile((Join-Path $passFrames ($passName+'-stock-front-'+$passSuffix+'.png')))
   try {$passGraphics.DrawImage($passImage,($passColumn*700),(65+$passRow*550),700,532)}
   finally {$passImage.Dispose()}
  }
 }
 $passCanvas.Save((Join-Path $passRoot 'five-car-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$passFont.Dispose();$passGraphics.Dispose();$passCanvas.Dispose()}
