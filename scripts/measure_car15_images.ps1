$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Car15Difference {
    public static double[] Compare(string first, string second, int x, int y, int width, int height) {
        using (var a = new Bitmap(first)) using (var b = new Bitmap(second)) {
            var bounds = new Rectangle(0,0,a.Width,a.Height);
            var aa = a.LockBits(bounds,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            var bb = b.LockBits(bounds,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            try {
                var av = new byte[aa.Stride*a.Height]; var bv = new byte[bb.Stride*b.Height];
                Marshal.Copy(aa.Scan0,av,0,av.Length); Marshal.Copy(bb.Scan0,bv,0,bv.Length);
                long sum=0,changed=0;
                for(int row=y;row<y+height;row++) for(int col=x;col<x+width;col++) {
                    int maximum=0;
                    for(int channel=0;channel<3;channel++) {
                        int difference=Math.Abs(av[row*aa.Stride+col*4+channel]-bv[row*bb.Stride+col*4+channel]);
                        sum+=difference; maximum=Math.Max(maximum,difference);
                    }
                    if(maximum>8)changed++;
                }
                return new double[] {(double)sum/(width*height*3),100.0*changed/(width*height)};
            } finally { a.UnlockBits(aa); b.UnlockBits(bb); }
        }
    }
}
'@
$car15Root=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car15-2026-11-15'
$car15Metrics=@{}
foreach($car15Renderer in @('gl_compatibility','mobile')) {
    $car15Folder=Join-Path $car15Root ('prepared-'+$car15Renderer)
    $car15Pairs=(Get-Content -LiteralPath (Join-Path $car15Folder 'comparisons.json') -Raw | ConvertFrom-Json).pairs
    $car15Rows=@{}
    foreach($car15Pair in $car15Pairs) {
        $car15Crop=$car15Pair.crop
        $car15Value=[Car15Difference]::Compare((Join-Path $car15Folder $car15Pair.before_image),(Join-Path $car15Folder $car15Pair.after_image),$car15Crop[0],$car15Crop[1],$car15Crop[2],$car15Crop[3])
        $car15Rows[$car15Pair.label]=@{ crop_mean_error_255=$car15Value[0]; crop_pixels_over_8_percent=$car15Value[1] }
    }
    $car15Metrics[$car15Renderer]=$car15Rows
}
$car15Metrics | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $car15Root 'image-metrics.json') -Encoding UTF8
