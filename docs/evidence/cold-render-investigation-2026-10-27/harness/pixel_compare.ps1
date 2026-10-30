$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class ColdRenderPixels {
 public static double[] Compare(string left,string right) {
  using(var a=new Bitmap(left)) using(var b=new Bitmap(right)) {
   if(a.Size!=b.Size)throw new Exception("Image sizes differ");
   var rect=new Rectangle(0,0,a.Width,a.Height);
   var ad=a.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   var bd=b.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   try {
    long sum=0,changed=0;int max=0;var aa=new byte[a.Width*4];var bb=new byte[b.Width*4];
    for(int y=0;y<a.Height;y++) {
     Marshal.Copy(IntPtr.Add(ad.Scan0,y*ad.Stride),aa,0,aa.Length);
     Marshal.Copy(IntPtr.Add(bd.Scan0,y*bd.Stride),bb,0,bb.Length);
     for(int x=0;x<a.Width;x++) {bool different=false;for(int c=0;c<4;c++) {int diff=Math.Abs(aa[x*4+c]-bb[x*4+c]);sum+=diff;max=Math.Max(max,diff);different|=diff!=0;}if(different)changed++;}
    }
    return new double[]{a.Width,a.Height,changed,max,(double)sum/(a.Width*a.Height*4)};
   }finally {a.UnlockBits(ad);b.UnlockBits(bd);}
  }
 }
}
'@
$lab=Split-Path -Parent $PSCommandPath
$baseline=Join-Path $lab 'results/original-standalone/studio.png'
$rows=@()
foreach($label in @('split-standalone','cache-reuse','representatives-split','separate-thread','rename-callback','mobile-original')) {
 $values=[ColdRenderPixels]::Compare($baseline,(Join-Path $lab "results/$label/studio.png"))
 $rows+= [PSCustomObject]@{label=$label;width=$values[0];height=$values[1];changed_pixels=$values[2];max_byte_delta=$values[3];mean_absolute_RGBA_byte_delta=$values[4]}
}
$rows | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $lab 'pixel-comparison.json') -Encoding UTF8
$rows | Format-Table -AutoSize
