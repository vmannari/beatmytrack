param([string]$Base = 'build/garage-model-review-2026-11-12', [string]$Before = 'before', [string]$After = 'after')
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class GarageImageCompare {
 public static double[] Compare(string left, string right) {
  using(var a = new Bitmap(left)) using(var b = new Bitmap(right)) {
   if(a.Width!=b.Width || a.Height!=b.Height) throw new Exception("image size mismatch");
   var rect = new Rectangle(0,0,a.Width,a.Height);
   var x = a.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   var y = b.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   long total=0, changed=0, over=0; int peak=0;
   try {
    var xa=new byte[x.Stride*a.Height]; var ya=new byte[y.Stride*b.Height];
    Marshal.Copy(x.Scan0,xa,0,xa.Length); Marshal.Copy(y.Scan0,ya,0,ya.Length);
    for(int row=0;row<a.Height;row++) for(int col=0;col<a.Width;col++) {
     int max=0;
     for(int c=0;c<3;c++) { int d=Math.Abs(xa[row*x.Stride+col*4+c]-ya[row*y.Stride+col*4+c]); total+=d; max=Math.Max(max,d); }
     if(max>0) changed++; if(max>8) over++; peak=Math.Max(peak,max);
    }
   } finally { a.UnlockBits(x); b.UnlockBits(y); }
   return new double[]{total/(a.Width*a.Height*3.0),changed,over/(a.Width*a.Height*1.0),peak};
  }
 }
}
'@
$rows = foreach ($renderer in @('gl_compatibility','mobile')) {
 foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Base "$Before/$renderer") -Filter '*.png') {
  $target = Join-Path $Base "$After/$renderer/$($file.Name)"
  if (-not (Test-Path -LiteralPath $target)) { continue }
  $values = [GarageImageCompare]::Compare($file.FullName,(Resolve-Path -LiteralPath $target).Path)
  [pscustomobject]@{renderer=$renderer;image=$file.Name;mean=$values[0];changed=$values[1];over8=$values[2];peak=$values[3]}
 }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Base "images-$Before-$After.json") -Encoding UTF8
$rows | Sort-Object mean -Descending | Select-Object -First 12 | Format-Table
