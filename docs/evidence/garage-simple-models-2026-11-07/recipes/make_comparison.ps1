param([string]$Zoom='close')
Add-Type -AssemblyName System.Drawing
$evidencePath=Join-Path (Get-Location) 'docs/evidence/garage-simple-models-2026-11-07'
$names=@('compact','kart','forklift','electric','hovercraft')
$labels=@('Rally','Kart','Forklift','Volt','Hovercraft')
$sheet=New-Object System.Drawing.Bitmap 1200,1100
$graphics=[System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(24,28,32))
$font=New-Object System.Drawing.Font 'Arial',14
for($row=0;$row -lt 5;$row++) {
    foreach($column in 0,1) {
        $quality=if($column -eq 0){'standard'}else{'reduced'}
        $file=Join-Path $evidencePath ('accepted-gl/'+$names[$row]+'-stock-'+$quality+'-'+$Zoom+'.png')
        $picture=[System.Drawing.Image]::FromFile($file)
        $scale=[Math]::Min(590.0/$picture.Width,190.0/$picture.Height)
        $width=[int]($picture.Width*$scale)
        $height=[int]($picture.Height*$scale)
        $graphics.DrawImage($picture,([int]($column*600+(600-$width)/2)),([int]($row*220+26)), $width,$height)
        $graphics.DrawString(($labels[$row]+' - '+$quality),$font,[System.Drawing.Brushes]::White,($column*600+10),($row*220+3))
        $picture.Dispose()
    }
}
$fileName=if($Zoom -eq 'close'){'garage-comparison.png'}else{'garage-normal-comparison.png'}
$sheet.Save((Join-Path $evidencePath $fileName))
$font.Dispose();$graphics.Dispose();$sheet.Dispose()
