$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
foreach ($renderer in @('gl_compatibility','mobile')) {
    $folder = Join-Path $PSScriptRoot $renderer
    $report = Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json
    foreach ($view in @('overhead','close')) {
        $canvas = New-Object System.Drawing.Bitmap(1000,1260)
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        $graphics.Clear([System.Drawing.Color]::FromArgb(27,31,35))
        $font = New-Object System.Drawing.Font('Arial',14)
        $cases = @(@('winter','ice_compact'),@('winter','snow_castle'),@('pine','container'))
        for ($index = 0; $index -lt $cases.Count; $index++) {
            $theme = $cases[$index][0]; $kind = $cases[$index][1]
            $row = $report.rows | Where-Object { $_.theme -eq $theme -and $_.kind -eq $kind -and $_.view -eq $view }
            $graphics.DrawString("$kind | primitives $($row.before_primitives) to $($row.after_primitives)",$font,[System.Drawing.Brushes]::White,12,($index*420+5))
            for ($column = 0; $column -lt 2; $column++) {
                $version = if ($column -eq 0) { 'before' } else { 'after' }
                $image = [System.Drawing.Image]::FromFile((Join-Path $folder "$theme-$kind-$view-$version.png"))
                $graphics.DrawString($(if ($column -eq 0) { 'Original' } else { 'Optimized' }),$font,[System.Drawing.Brushes]::White,($column*500+12),($index*420+32))
                if ($view -eq 'overhead') {
                    $source = New-Object System.Drawing.Rectangle(420,180,500,360)
                    $destination = New-Object System.Drawing.Rectangle(($column*500),($index*420+60),500,360)
                } else {
                    $source = New-Object System.Drawing.Rectangle(0,0,1280,720)
                    $destination = New-Object System.Drawing.Rectangle(($column*500+10),($index*420+75),480,270)
                }
                $graphics.DrawImage($image,$destination,$source,[System.Drawing.GraphicsUnit]::Pixel)
                $image.Dispose()
            }
        }
        $canvas.Save((Join-Path $folder "comparison-$view.png"),[System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $font.Dispose(); $canvas.Dispose()
    }
}
