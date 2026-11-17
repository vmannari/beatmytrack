$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class CarPass10Restoration {
 public static Dictionary<string,object> Compare(string first,string second) {
  using(var a0=new Bitmap(first)) using(var b0=new Bitmap(second)) {
   if(a0.Size!=b0.Size) throw new Exception("Image sizes differ");
   using(var a=new Bitmap(a0.Width,a0.Height,PixelFormat.Format32bppArgb))
   using(var b=new Bitmap(b0.Width,b0.Height,PixelFormat.Format32bppArgb)) {
    using(var g=Graphics.FromImage(a))g.DrawImageUnscaled(a0,0,0);
    using(var g=Graphics.FromImage(b))g.DrawImageUnscaled(b0,0,0);
    var rect=new Rectangle(0,0,a.Width,a.Height);
    var ad=a.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    var bd=b.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    try {
     byte[] ap=new byte[ad.Stride*a.Height],bp=new byte[bd.Stride*b.Height];
     Marshal.Copy(ad.Scan0,ap,0,ap.Length);Marshal.Copy(bd.Scan0,bp,0,bp.Length);
     int pixels=0,maximum=0;long squared=0;
     for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++) {
      bool different=false;
      for(int c=0;c<4;c++) {int d=Math.Abs(ap[y*ad.Stride+x*4+c]-bp[y*bd.Stride+x*4+c]);maximum=Math.Max(maximum,d);squared+=(long)d*d;different|=d!=0;}
      if(different)pixels++;
     }
     return new Dictionary<string,object>{{"changed_pixels",pixels},{"maximum_channel_delta_255",maximum},{"rms_255",Math.Sqrt((double)squared/(a.Width*a.Height*4))},{"width",a.Width},{"height",a.Height}};
    } finally {a.UnlockBits(ad);b.UnlockBits(bd);}
   }
  }
 }
}
'@
$passRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-pass10-2026-11-16'
$passRows=@()
foreach($passFolder in @('prepared-mobile-decorated','garage-prepared-mobile-decorated-sweep-initial')) {
 $passDirectory=Join-Path $passRoot $passFolder
 $passData=Get-Content -LiteralPath (Join-Path $passDirectory 'comparisons.json') -Raw | ConvertFrom-Json
 foreach($passPair in $passData.pairs) {
  if($passPair.restored_exact) {continue}
  $passDifference=[CarPass10Restoration]::Compare((Join-Path $passDirectory $passPair.before_image),(Join-Path $passDirectory $passPair.restoration_image))
  $passRows+=@{folder=$passFolder;label=$passPair.label;difference=$passDifference}
 }
}
$passRows | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $passRoot 'mobile-restoration-differences.json') -Encoding utf8
$passRows | ConvertTo-Json -Depth 10
