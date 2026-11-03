param([string]$Folder='review-gl',[string]$Prefix='review')
Add-Type -AssemblyName System.Drawing
$source=Join-Path $PSScriptRoot $Folder
foreach($category in @('hood','aero','rims','body')) {
    $sheet=New-Object System.Drawing.Bitmap(1280,1080)
    $graphics=[System.Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([System.Drawing.Color]::FromArgb(16,27,35))
    $font=New-Object System.Drawing.Font('Arial',12)
    $index=0
    foreach($file in (Get-ChildItem -LiteralPath $source -Filter "$category-*.png" | Sort-Object Name)) {
        $pixels=[System.Drawing.Image]::FromFile($file.FullName)
        $x=($index % 4)*320
        $y=[math]::Floor($index/4)*270
        $destination=New-Object System.Drawing.Rectangle($x,$y,320,240)
        $graphics.DrawImage($pixels,$destination)
        $graphics.DrawString($file.BaseName,$font,[System.Drawing.Brushes]::White,$x+5,$y+242)
        $pixels.Dispose()
        $index++
    }
    $sheet.Save((Join-Path $PSScriptRoot "$Prefix-$category.jpg"),[System.Drawing.Imaging.ImageFormat]::Jpeg)
    $font.Dispose(); $graphics.Dispose(); $sheet.Dispose()
}
