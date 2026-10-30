param([string]$Left,[string]$Right,[string]$Output)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
public static class ProgramPixels {
 public static double[] Compare(string left,string right) {
  using(var a=new Bitmap(left)) using(var b=new Bitmap(right)) {
   if(a.Size!=b.Size)throw new Exception("Image sizes differ");
   long sum=0,changed=0;int max=0;
   for(int y=0;y<a.Height;y++) for(int x=0;x<a.Width;x++) {
    var p=a.GetPixel(x,y);var q=b.GetPixel(x,y);int[] values={Math.Abs(p.R-q.R),Math.Abs(p.G-q.G),Math.Abs(p.B-q.B),Math.Abs(p.A-q.A)};
    bool different=false;foreach(int d in values){sum+=d;max=Math.Max(max,d);different|=d!=0;}if(different)changed++;
   }
   return new double[]{a.Width,a.Height,changed,max,(double)sum/(a.Width*a.Height*4)};
  }
 }
}
'@
$v=[ProgramPixels]::Compare($Left,$Right)
$r=[ordered]@{left=$Left;right=$Right;width=$v[0];height=$v[1];changed_pixels=$v[2];max_byte_delta=$v[3];mean_absolute_RGBA_byte_delta=$v[4]}
$r | ConvertTo-Json | Set-Content -LiteralPath $Output -Encoding UTF8
$r | ConvertTo-Json
