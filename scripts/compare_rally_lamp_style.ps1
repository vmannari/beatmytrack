$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$lampRoot=Split-Path -Parent $PSScriptRoot
$lampEvidence=Join-Path $lampRoot 'docs/evidence/rally-lamp-style-2026-11-15'
$lampCurrent=Join-Path $lampEvidence 'prepared-gl_compatibility'
$lampEarlier=Join-Path $lampRoot 'docs/evidence/rally-front-2026-11-15/prepared-gl_compatibility'
$lampCanvas=New-Object System.Drawing.Bitmap(2400,1290)
$lampGraphics=[System.Drawing.Graphics]::FromImage($lampCanvas)
$lampFont=New-Object System.Drawing.Font('Segoe UI',19)
try {
    $lampGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
    $lampLabels=@('EARLIER LAMPS','OPAQUE REVISION','RESTORED REFLECTOR STYLE')
    for($lampColumn=0;$lampColumn -lt 3;$lampColumn++) {
        $lampGraphics.DrawString($lampLabels[$lampColumn],$lampFont,[System.Drawing.Brushes]::White,($lampColumn*800+15),10)
        for($lampRow=0;$lampRow -lt 2;$lampRow++) {
            $lampShot=@('head-on','lamp-close')[$lampRow]
            $lampPath=if($lampColumn -eq 0) { Join-Path $lampEarlier ('compact-stock-'+$lampShot+'-before.png') }
                elseif($lampColumn -eq 1) { Join-Path $lampCurrent ('compact-stock-'+$lampShot+'-before.png') }
                else { Join-Path $lampCurrent ('compact-stock-'+$lampShot+'-after.png') }
            $lampImage=[System.Drawing.Image]::FromFile($lampPath)
            try {$lampGraphics.DrawImage($lampImage,($lampColumn*800),(60+$lampRow*608),800,608)}
            finally {$lampImage.Dispose()}
        }
    }
    $lampCanvas.Save((Join-Path $lampEvidence 'lamp-style-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
}
finally {$lampFont.Dispose();$lampGraphics.Dispose();$lampCanvas.Dispose()}
