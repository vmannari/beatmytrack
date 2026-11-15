param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Garage70Images {
    public static double[] Compare(string left,string right) {
        using(var a=new Bitmap(left)) using(var b=new Bitmap(right)) {
            if(a.Size!=b.Size) throw new Exception("Image sizes differ");
            var rect=new Rectangle(0,0,a.Width,a.Height);
            var x=a.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            var y=b.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            try {
                byte[] p=new byte[Math.Abs(x.Stride)*a.Height],q=new byte[Math.Abs(y.Stride)*b.Height];
                Marshal.Copy(x.Scan0,p,0,p.Length);Marshal.Copy(y.Scan0,q,0,q.Length);
                long total=0,changed=0,over8=0;int maximum=0;
                for(int row=0;row<a.Height;row++) for(int col=0;col<a.Width;col++) {
                    int dmax=0;
                    for(int c=0;c<3;c++) {
                        int d=Math.Abs(p[row*Math.Abs(x.Stride)+col*4+c]-q[row*Math.Abs(y.Stride)+col*4+c]);
                        total+=d;dmax=Math.Max(dmax,d);
                    }
                    if(dmax>0)changed++;if(dmax>8)over8++;maximum=Math.Max(maximum,dmax);
                }
                double pixels=(double)a.Width*a.Height;
                return new double[]{total/(pixels*3),over8/pixels,changed/pixels,maximum};
            } finally {a.UnlockBits(x);b.UnlockBits(y);}
        }
    }
}
'@ -ReferencedAssemblies System.Drawing
$rows=@()
foreach($file in Get-ChildItem -LiteralPath (Join-Path $Directory 'before') -Filter '*.png') {
    $values=[Garage70Images]::Compare($file.FullName,(Join-Path (Join-Path $Directory 'after') $file.Name))
    $rows+= [PSCustomObject]@{image=$file.Name;mean_rgb=$values[0];over8_fraction=$values[1];changed_fraction=$values[2];maximum=$values[3];prior_appearance_gate=($values[0] -lt 0.25 -and $values[1] -lt 0.005)}
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Directory 'image-comparison.json') -Encoding UTF8
$rows | Sort-Object mean_rgb -Descending | Select-Object -First 12 | Format-Table -AutoSize
Write-Output ("Compared {0} pairs; prior tight gate passes {1}" -f $rows.Count,@($rows | Where-Object prior_appearance_gate).Count)
