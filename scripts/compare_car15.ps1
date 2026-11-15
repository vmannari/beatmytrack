$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$car15Evidence = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car15-2026-11-15'
$car15Frames = Join-Path $car15Evidence 'prepared-gl_compatibility'
$car15Font = New-Object System.Drawing.Font('Segoe UI',15)
$car15Rows = @(
    @('compact','Rally 19,074 to 16,653 (-12.7%)','windshield'),
    @('kart','Kart 24,223 to 20,590 (-15.0%)','helmet-side'),
    @('forklift','Forklift 26,472 to 22,502 (-15.0%)','hardware-rear'),
    @('electric','Volt 19,826 to 17,015 (-14.2%)','roof-left'),
    @('hovercraft','Hover 22,068 to 18,758 (-15.0%)','rear')
)
try {
    foreach ($car15Sheet in @('front','details')) {
        $car15Canvas = New-Object System.Drawing.Bitmap(1200,2500)
        $car15Graphics = [System.Drawing.Graphics]::FromImage($car15Canvas)
        try {
            $car15Graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
            $car15Graphics.DrawString('BEFORE THIS STEP (Forklift already -11.7%)',$car15Font,[System.Drawing.Brushes]::White,10,8)
            $car15Graphics.DrawString('REVIEWED CANDIDATE',$car15Font,[System.Drawing.Brushes]::White,610,8)
            for ($car15Row=0; $car15Row -lt $car15Rows.Count; $car15Row++) {
                $car15Record=$car15Rows[$car15Row]
                $car15Shot=if ($car15Sheet -eq 'front') { 'front' } else { $car15Record[2] }
                $car15Graphics.DrawString($car15Record[1]+'; '+$car15Shot,$car15Font,[System.Drawing.Brushes]::White,10,(48+$car15Row*490))
                for ($car15Column=0; $car15Column -lt 2; $car15Column++) {
                    $car15Suffix=@('before','after')[$car15Column]
                    $car15Image=[System.Drawing.Image]::FromFile((Join-Path $car15Frames ($car15Record[0]+'-stock-'+$car15Shot+'-'+$car15Suffix+'.png')))
                    try { $car15Graphics.DrawImage($car15Image,($car15Column*600),(80+$car15Row*490),600,456) }
                    finally { $car15Image.Dispose() }
                }
            }
            $car15Canvas.Save((Join-Path $car15Evidence ($car15Sheet+'-comparison.png')),[System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $car15Graphics.Dispose(); $car15Canvas.Dispose() }
    }
}
finally { $car15Font.Dispose() }
