$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$passRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-pass12-2026-11-16'
$passFrames=Join-Path $passRoot 'prepared-gl_compatibility-decorated'
$passCanvas=New-Object System.Drawing.Bitmap(1400,2810)
$passGraphics=[System.Drawing.Graphics]::FromImage($passCanvas)
$passFont=New-Object System.Drawing.Font('Segoe UI',16)
try {
 $passGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
 $passGraphics.DrawString('Before',$passFont,[System.Drawing.Brushes]::White,12,6)
 $passGraphics.DrawString('After',$passFont,[System.Drawing.Brushes]::White,712,6)
 $passCars=@('compact','kart','forklift','electric','hovercraft')
 $passLabels=@('Rally: 14,908 to 13,341 (-10.5%)','Kart: 18,531 to 16,628 (-10.3%)','Forklift: 20,314 to 18,116 (-10.8%)','Volt: 21,309 to 19,071 (-10.5%)','Hover: 16,882 to 14,856 (-12.0%)')
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
