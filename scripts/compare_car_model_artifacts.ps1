$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$artifactRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-model-artifacts-2026-11-14'
$artifactFrames = Join-Path $artifactRoot 'prepared-gl_compatibility'
$artifactFont = New-Object System.Drawing.Font('Arial',12)
function Draw-ArtifactFrame($graphics, $name, $crop, $left, $top, $width, $height) {
    $frame = [System.Drawing.Image]::FromFile((Join-Path $artifactFrames ($name+'.png')))
    try {
        if ($null -eq $crop) { $crop = @(0,0,$frame.Width,$frame.Height) }
        $scale = [Math]::Min($width/$crop[2],$height/$crop[3])
        $target = New-Object System.Drawing.RectangleF(($left+($width-$crop[2]*$scale)/2),($top+($height-$crop[3]*$scale)/2),($crop[2]*$scale),($crop[3]*$scale))
        $sourceRect = New-Object System.Drawing.RectangleF([single]$crop[0],[single]$crop[1],[single]$crop[2],[single]$crop[3])
        $graphics.DrawImage($frame,$target,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
    } finally { $frame.Dispose() }
}
$shots = @(
    @('Kart helmet','kart-stock-helmet-side',@(280,235,460,400)),
    @('Rally windshield','compact-stock-windshield',@(170,120,650,500)),
    @('Volt roof joint','electric-stock-roof-left',@(70,310,900,255)),
    @('Forklift tyres','forklift-stock-front',@(200,290,540,410)),
    @('Rally wheel arch','compact-stock-rear',@(400,280,450,410))
)
$artifactCanvas = New-Object System.Drawing.Bitmap(1040,1600)
$artifactGraphics = [System.Drawing.Graphics]::FromImage($artifactCanvas)
try {
    $artifactGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#171d24'))
    $artifactGraphics.DrawString('BEFORE',$artifactFont,[System.Drawing.Brushes]::White,15,14)
    $artifactGraphics.DrawString('REPAIRED',$artifactFont,[System.Drawing.Brushes]::White,535,14)
    for ($row=0; $row -lt $shots.Count; $row++) {
        $top=50+$row*310
        $artifactGraphics.DrawString($shots[$row][0],$artifactFont,[System.Drawing.Brushes]::LightBlue,15,$top)
        Draw-ArtifactFrame $artifactGraphics ($shots[$row][1]+'-before') $shots[$row][2] 10 ($top+26) 500 275
        Draw-ArtifactFrame $artifactGraphics ($shots[$row][1]+'-after') $shots[$row][2] 530 ($top+26) 500 275
    }
    $artifactCanvas.Save((Join-Path $artifactRoot 'repairs-before-after.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
} finally { $artifactGraphics.Dispose(); $artifactCanvas.Dispose() }
$artifactCanvas = New-Object System.Drawing.Bitmap(1000,2025)
$artifactGraphics = [System.Drawing.Graphics]::FromImage($artifactCanvas)
try {
    $artifactGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#171d24'))
    $cars=@('compact','kart','forklift','electric','hovercraft')
    for ($row=0; $row -lt $cars.Count; $row++) {
        $artifactGraphics.DrawString($cars[$row],$artifactFont,[System.Drawing.Brushes]::White,10,($row*405+4))
        Draw-ArtifactFrame $artifactGraphics ($cars[$row]+'-stock-front-after') $null 0 ($row*405+25) 500 380
        Draw-ArtifactFrame $artifactGraphics ($cars[$row]+'-stock-rear-after') $null 500 ($row*405+25) 500 380
    }
    $artifactCanvas.Save((Join-Path $artifactRoot 'five-car-review.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
} finally { $artifactGraphics.Dispose(); $artifactCanvas.Dispose(); $artifactFont.Dispose() }
