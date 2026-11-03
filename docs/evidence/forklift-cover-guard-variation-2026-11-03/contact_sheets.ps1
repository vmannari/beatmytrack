param([string]$Folder='native',[string]$Prefix='')
Add-Type -AssemblyName System.Drawing
$choices=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'choices.json') -Raw | ConvertFrom-Json
foreach($category in @('hood','aero')) {
    $sheet=New-Object System.Drawing.Bitmap(1600,1320)
    $graphics=[System.Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([System.Drawing.Color]::FromArgb(16,27,35))
    $font=New-Object System.Drawing.Font('Arial',14)
    $index=0
    foreach($choice in $choices.$category) {
        $pixels=[System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot "$Folder/$category-$($choice.id).png"))
        $x=($index % 4)*400
        $y=[math]::Floor($index/4)*330
        $graphics.DrawImage($pixels,(New-Object System.Drawing.Rectangle($x,$y,400,300)))
        $graphics.DrawString($choice.name,$font,[System.Drawing.Brushes]::White,$x+6,$y+304)
        $pixels.Dispose()
        $index++
    }
    $sheet.Save((Join-Path $PSScriptRoot "$Prefix$category-overview.jpg"),[System.Drawing.Imaging.ImageFormat]::Jpeg)
    $font.Dispose(); $graphics.Dispose(); $sheet.Dispose()
}
