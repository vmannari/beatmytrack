$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$shots = @(
    @{Title='Rear'; Shot='rear'; Crop=[Drawing.Rectangle]::new(500,325,620,395)},
    @{Title='Door lower corner'; Shot='door-corner'; Crop=[Drawing.Rectangle]::new(125,315,685,335)},
    @{Title='Grille and nose'; Shot='front'; Crop=[Drawing.Rectangle]::new(500,325,620,385)},
    @{Title='Bonnet'; Shot='overhead'; Crop=[Drawing.Rectangle]::new(330,275,520,470)}
)
$heading = [Drawing.Font]::new('Segoe UI',16)
$caption = [Drawing.Font]::new('Segoe UI',12)
$muted = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(169,196,220))
try {
    foreach ($method in @('gl_compatibility','mobile')) {
        $bitmap = [Drawing.Bitmap]::new(1280,1540)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(17,26,35))
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias
            $graphics.DrawString('Before',$heading,[Drawing.Brushes]::White,20,15)
            $graphics.DrawString('After - prepared production car',$heading,[Drawing.Brushes]::White,660,15)
            for ($row = 0; $row -lt $shots.Count; $row++) {
                $shot = $shots[$row]
                $top = 60+$row*365
                $graphics.DrawString($shot.Title,$caption,$muted,20,$top)
                for ($column = 0; $column -lt 2; $column++) {
                    $stage = @('before','prepared')[$column]
                    $path = Join-Path $PSScriptRoot "$stage/$method/simple/white-$($shot.Shot).png"
                    $source = [Drawing.Image]::FromFile($path)
                    try {
                        $scale = [Math]::Min(620.0/$shot.Crop.Width,320.0/$shot.Crop.Height)
                        $width = [int][Math]::Floor($shot.Crop.Width*$scale)
                        $height = [int][Math]::Floor($shot.Crop.Height*$scale)
                        $target = [Drawing.Rectangle]::new([int]($column*640+10+(620-$width)/2),[int]($top+28+(320-$height)/2),$width,$height)
                        $graphics.DrawImage($source,$target,$shot.Crop,[Drawing.GraphicsUnit]::Pixel)
                    } finally { $source.Dispose() }
                }
            }
            $bitmap.Save((Join-Path $PSScriptRoot "comparison-$method.png"),[Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $heading.Dispose(); $caption.Dispose(); $muted.Dispose() }
Write-Output 'Native before/after contact sheets saved.'
