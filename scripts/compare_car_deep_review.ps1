$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class DeepCarPixels {
    public static double[] Compare(string aPath, string bPath, int x, int y, int width, int height) {
        using (var sourceA = new Bitmap(aPath)) using (var sourceB = new Bitmap(bPath)) {
            if (width==0 || height==0) { x=0;y=0;width=sourceA.Width;height=sourceA.Height; }
            var rect = new Rectangle(x,y,width,height);
            using (var a = sourceA.Clone(rect,PixelFormat.Format32bppArgb))
            using (var b = sourceB.Clone(rect,PixelFormat.Format32bppArgb)) {
                var area = new Rectangle(0,0,width,height);
                var ad=a.LockBits(area,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
                var bd=b.LockBits(area,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
                try {
                    var aa=new byte[ad.Stride*height];var bb=new byte[bd.Stride*height];
                    Marshal.Copy(ad.Scan0,aa,0,aa.Length);Marshal.Copy(bd.Scan0,bb,0,bb.Length);
                    long changed=0,over8=0,total=0,alphaChanged=0;int maximum=0,alphaMaximum=0;
                    for (int row=0;row<height;row++) for (int col=0;col<width;col++) {
                        int peak=0;
                        for (int c=0;c<3;c++) {
                            int d=Math.Abs(aa[row*ad.Stride+col*4+c]-bb[row*bd.Stride+col*4+c]);
                            total+=d;peak=Math.Max(peak,d);
                        }
                        if (peak>0) changed++;if (peak>8) over8++;maximum=Math.Max(maximum,peak);
                        int alpha=Math.Abs(aa[row*ad.Stride+col*4+3]-bb[row*bd.Stride+col*4+3]);
                        if (alpha>0) alphaChanged++;alphaMaximum=Math.Max(alphaMaximum,alpha);
                    }
                    return new double[]{changed,over8,(double)total/(width*height*3),maximum,alphaChanged,alphaMaximum,width*height};
                } finally { a.UnlockBits(ad);b.UnlockBits(bd); }
            }
        }
    }
}
'@
$deepRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-deep-review-2026-11-14'
$deepMetrics = @()
$deepNames = @{ compact='Rally'; kart='Kart'; forklift='Forklift'; electric='Volt'; hovercraft='Hover'; super_rally='Challenger' }
$deepSelections = @('forklift-axial-front','forklift-hardware-front','compact-hardware-front','forklift-enclosed-front','compact-zero_area-front','forklift-ghost-race-distance','kart-ghost-race-distance')
$deepFont = New-Object System.Drawing.Font('Segoe UI',15)
function Get-DeepDifference($directory,$a,$b,$crop) {
    $raw = [DeepCarPixels]::Compare((Join-Path $directory $a),(Join-Path $directory $b),[int]$crop[0],[int]$crop[1],[int]$crop[2],[int]$crop[3])
    return @{changed_pixels=$raw[0];pixels_over_8=$raw[1];mean_rgb_delta_255=$raw[2];maximum_rgb_delta_255=$raw[3];alpha_changed_pixels=$raw[4];maximum_alpha_delta_255=$raw[5];crop_pixels=$raw[6]}
}
try {
    foreach ($deepRenderer in @('gl_compatibility','mobile','gl_compatibility-shadows','mobile-shadows')) {
        $deepDirectory = Join-Path $deepRoot $deepRenderer
        $deepPairs = @()
        foreach ($deepFile in @('comparisons.json','hardware-comparisons.json')) {
            $deepPath = Join-Path $deepDirectory $deepFile
            if (Test-Path -LiteralPath $deepPath) { $deepPairs += (Get-Content -LiteralPath $deepPath -Raw | ConvertFrom-Json).pairs }
        }
        foreach ($deepPair in $deepPairs) {
            $deepDelta = Get-DeepDifference $deepDirectory $deepPair.before_image $deepPair.candidate_image $deepPair.crop
            $deepFullDelta = Get-DeepDifference $deepDirectory $deepPair.before_image $deepPair.candidate_image @(0,0,0,0)
            $deepRepeat = if ($deepPair.repeat_image) { Get-DeepDifference $deepDirectory $deepPair.before_image $deepPair.repeat_image $deepPair.crop } else { $null }
            $deepRestored = if ($deepPair.restoration_image) { Get-DeepDifference $deepDirectory $deepPair.before_image $deepPair.restoration_image $deepPair.crop } else { $null }
            $deepMetrics += @{renderer=$deepRenderer;label=$deepPair.label;vehicle=$deepPair.vehicle;mode=$deepPair.mode;view=$deepPair.view;before_triangles=$deepPair.master_before;candidate_triangles=$deepPair.master_candidate;dynamic_shadow=$deepPair.dynamic_shadow;difference=$deepDelta;full_difference=$deepFullDelta;repeat=$deepRepeat;restoration=$deepRestored;stable_reference=$deepPair.stable_reference;restored_exact=$deepPair.restored_exact;saved_viewport_primitives=($deepPair.visible_primitives_before-$deepPair.visible_primitives_candidate)}
        }
        if ($deepRenderer.EndsWith('-shadows')) { continue }
        $deepSheet = New-Object System.Drawing.Bitmap(1200,($deepSelections.Count*510))
        $deepDrawing = [System.Drawing.Graphics]::FromImage($deepSheet)
        try {
            $deepDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
            for ($deepRow=0; $deepRow -lt $deepSelections.Count; $deepRow++) {
                $deepPair = $deepPairs | Where-Object { $_.label -eq $deepSelections[$deepRow] } | Select-Object -First 1
                if (-not $deepPair) { continue }
                $deepY = $deepRow*510
                $deepLabel = '{0}: {1} | {2:N0} -> {3:N0} triangles' -f $deepNames[$deepPair.vehicle],$deepPair.mode,$deepPair.master_before,$deepPair.master_candidate
                $deepDrawing.DrawString($deepLabel,$deepFont,[System.Drawing.Brushes]::White,10,$deepY)
                for ($deepColumn=0; $deepColumn -lt 2; $deepColumn++) {
                    $deepImageName = @($deepPair.before_image,$deepPair.candidate_image)[$deepColumn]
                    $deepImage = [System.Drawing.Image]::FromFile((Join-Path $deepDirectory $deepImageName))
                    try { $deepDrawing.DrawImage($deepImage,($deepColumn*600),($deepY+35),600,456) }
                    finally { $deepImage.Dispose() }
                }
            }
            $deepSheet.Save((Join-Path $deepRoot ($deepRenderer+'-comparisons.png')))
        } finally { $deepDrawing.Dispose();$deepSheet.Dispose() }
    }
    $deepMetrics | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $deepRoot 'native-pixel-metrics.json') -Encoding UTF8
    Write-Output ('DEEP_PIXELS: '+$deepMetrics.Count+' car-crop pairs and reference/restoration diagnostics.')
} finally { $deepFont.Dispose() }
