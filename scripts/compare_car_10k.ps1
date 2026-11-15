$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class DetailPixels {
    public static double[] Compare(string aPath,string bPath,int x,int y,int width,int height) {
        using(var sa=new Bitmap(aPath)) using(var sb=new Bitmap(bPath)) {
            if(width==0 || height==0) { x=0;y=0;width=sa.Width;height=sa.Height; }
            var rect=new Rectangle(x,y,width,height);
            using(var a=sa.Clone(rect,PixelFormat.Format32bppArgb)) using(var b=sb.Clone(rect,PixelFormat.Format32bppArgb)) {
                var area=new Rectangle(0,0,width,height);
                var ad=a.LockBits(area,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
                var bd=b.LockBits(area,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
                try {
                    var aa=new byte[ad.Stride*height];var bb=new byte[bd.Stride*height];
                    Marshal.Copy(ad.Scan0,aa,0,aa.Length);Marshal.Copy(bd.Scan0,bb,0,bb.Length);
                    long changed=0,over8=0,sum=0,alphaChanged=0;int maximum=0,alphaMaximum=0;
                    for(int row=0;row<height;row++) for(int col=0;col<width;col++) {
                        int peak=0;
                        for(int c=0;c<3;c++) { int d=Math.Abs(aa[row*ad.Stride+col*4+c]-bb[row*bd.Stride+col*4+c]);sum+=d;peak=Math.Max(peak,d); }
                        if(peak>0)changed++;if(peak>8)over8++;maximum=Math.Max(maximum,peak);
                        int alpha=Math.Abs(aa[row*ad.Stride+col*4+3]-bb[row*bd.Stride+col*4+3]);
                        if(alpha>0)alphaChanged++;alphaMaximum=Math.Max(alphaMaximum,alpha);
                    }
                    return new double[]{changed,over8,(double)sum/(width*height*3),maximum,alphaChanged,alphaMaximum,width*height};
                } finally { a.UnlockBits(ad);b.UnlockBits(bd); }
            }
        }
    }
}
'@
$detailRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-10k-models-2026-11-14'
$detailRows = @()
$detailSelections = @('forklift-stock-front','compact-stock-front','compact-stock-plate','forklift-fitted-rear','kart-stock-front','forklift-ghost-distance')
$detailFont = New-Object System.Drawing.Font('Segoe UI',15)
function Get-DetailDelta($directory,$a,$b,$crop) {
    $raw = [DetailPixels]::Compare((Join-Path $directory $a),(Join-Path $directory $b),[int]$crop[0],[int]$crop[1],[int]$crop[2],[int]$crop[3])
    return @{changed_pixels=$raw[0];pixels_over_8=$raw[1];mean_rgb_delta_255=$raw[2];maximum_rgb_delta_255=$raw[3];alpha_changed_pixels=$raw[4];maximum_alpha_delta_255=$raw[5];pixels=$raw[6]}
}
try {
    foreach ($detailRenderer in @('gl_compatibility','mobile')) {
        $detailDirectory = Join-Path $detailRoot ('prepared-'+$detailRenderer)
        $detailPairs = (Get-Content -LiteralPath (Join-Path $detailDirectory 'comparisons.json') -Raw | ConvertFrom-Json).pairs
        foreach ($detailPair in $detailPairs) {
            $detailCrop = Get-DetailDelta $detailDirectory $detailPair.before_image $detailPair.after_image $detailPair.crop
            $detailFull = Get-DetailDelta $detailDirectory $detailPair.before_image $detailPair.after_image @(0,0,0,0)
            $detailRepeat = if ($detailPair.repeat_image) { Get-DetailDelta $detailDirectory $detailPair.before_image $detailPair.repeat_image $detailPair.crop } else { $null }
            $detailRestored = if ($detailPair.restoration_image) { Get-DetailDelta $detailDirectory $detailPair.before_image $detailPair.restoration_image $detailPair.crop } else { $null }
            $detailRows += @{renderer=$detailRenderer;label=$detailPair.label;vehicle=$detailPair.vehicle;mode=$detailPair.mode;view=$detailPair.view;before_triangles=$detailPair.master_before;after_triangles=$detailPair.master_after;crop=$detailCrop;whole_frame=$detailFull;repeat=$detailRepeat;restoration=$detailRestored;stable_reference=$detailPair.stable_reference;restored_exact=$detailPair.restored_exact;visible_primitives_before=$detailPair.visible_primitives_before;visible_primitives_after=$detailPair.visible_primitives_after}
        }
        $detailSheet = New-Object System.Drawing.Bitmap(1200,($detailSelections.Count*510))
        $detailDrawing = [System.Drawing.Graphics]::FromImage($detailSheet)
        try {
            $detailDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#192129'))
            for ($detailRow=0; $detailRow -lt $detailSelections.Count; $detailRow++) {
                $detailPair = $detailPairs | Where-Object { $_.label -eq $detailSelections[$detailRow] } | Select-Object -First 1
                if (-not $detailPair) { continue }
                $detailY = $detailRow*510
                $detailLabel = '{0}: {1:N0} -> {2:N0} triangles | current / reduced' -f $detailPair.label,$detailPair.master_before,$detailPair.master_after
                $detailDrawing.DrawString($detailLabel,$detailFont,[System.Drawing.Brushes]::White,10,$detailY)
                for ($detailColumn=0; $detailColumn -lt 2; $detailColumn++) {
                    $detailName = @($detailPair.before_image,$detailPair.after_image)[$detailColumn]
                    $detailImage = [System.Drawing.Image]::FromFile((Join-Path $detailDirectory $detailName))
                    try { $detailDrawing.DrawImage($detailImage,($detailColumn*600),($detailY+35),600,456) }
                    finally { $detailImage.Dispose() }
                }
            }
            $detailSheet.Save((Join-Path $detailRoot ($detailRenderer+'-comparison.png')))
        } finally { $detailDrawing.Dispose();$detailSheet.Dispose() }
    }
    $detailRows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $detailRoot 'native-pixel-metrics.json') -Encoding UTF8
    Write-Output ('DETAIL_PIXELS '+$detailRows.Count+' pairs; crop, whole frame and control measurements.')
} finally { $detailFont.Dispose() }
