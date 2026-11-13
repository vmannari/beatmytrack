$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
foreach ($folder in Get-ChildItem -LiteralPath $PSScriptRoot -Directory -Filter 'capture-*') {
    foreach ($category in @('hood','aero','rims','body')) {
        $views = @(Get-ChildItem -LiteralPath (Join-Path $folder.FullName $category) -Filter '*-detail.png' | Sort-Object Name)
        if ($views.Count -eq 0) { continue }
        $sheet = New-Object System.Drawing.Bitmap(960,([int][Math]::Ceiling($views.Count/2.0)*324))
        $graphics = [System.Drawing.Graphics]::FromImage($sheet)
        $graphics.Clear([System.Drawing.Color]::FromArgb(24,33,42))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $font = New-Object System.Drawing.Font('Arial',12)
        for ($index=0; $index -lt $views.Count; $index++) {
            $x = [int](($index % 2)*480)
            $y = [int]([Math]::Floor($index/2.0)*324)
            $graphics.DrawString($views[$index].BaseName,$font,[System.Drawing.Brushes]::White,$x+8,$y+3)
            $original = [System.Drawing.Image]::FromFile($views[$index].FullName)
            $graphics.DrawImage($original,$x,($y+24),480,300)
            $original.Dispose()
        }
        $sheet.Save((Join-Path $PSScriptRoot ($folder.Name+'-'+$category+'-sheet.png')),[System.Drawing.Imaging.ImageFormat]::Png)
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}
