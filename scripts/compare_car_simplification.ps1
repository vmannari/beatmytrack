$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$carSimpleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-simplification-2026-11-13'
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
public static class CarSimplePixels {
 public static double[] Compare(string first,string second) {
  using(var a=new Bitmap(first)) using(var b=new Bitmap(second)) {
   if(a.Size!=b.Size) throw new Exception("Image dimensions differ");
   long changed=0, significant=0, sum=0;
   for(int y=0;y<a.Height;y++) for(int x=0;x<a.Width;x++) {
    Color p=a.GetPixel(x,y),q=b.GetPixel(x,y);
    int r=Math.Abs(p.R-q.R),g=Math.Abs(p.G-q.G),z=Math.Abs(p.B-q.B);
    int peak=Math.Max(r,Math.Max(g,z));
    if(peak>0) changed++; if(peak>8) significant++; sum+=r+g+z;
   }
   return new double[]{changed,significant,(double)sum/(a.Width*a.Height*3)};
  }
 }
}
'@
$carSimpleRows = @()
foreach ($carSimpleId in @('compact','kart','forklift','electric','hovercraft')) {
 foreach ($carSimpleView in @('front','rear','side','overhead')) {
  $carSimpleName = $carSimpleId+'-'+$carSimpleView+'.png'
  $carSimpleValues = [CarSimplePixels]::Compare((Join-Path $carSimpleRoot ('before/gl_compatibility/'+$carSimpleName)),(Join-Path $carSimpleRoot ('final/gl_compatibility/'+$carSimpleName)))
  $carSimpleRows += @{ vehicle=$carSimpleId; view=$carSimpleView; changed_pixels=$carSimpleValues[0]; significant_pixels=$carSimpleValues[1]; rgb_mae_255=$carSimpleValues[2] }
 }
}
$carSimpleRows | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $carSimpleRoot 'native-comparisons.json')
$carSimpleSheet = New-Object System.Drawing.Bitmap(1200,2450)
$carSimpleDrawing = [System.Drawing.Graphics]::FromImage($carSimpleSheet)
$carSimpleDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#18232c'))
$carSimpleFont = New-Object System.Drawing.Font('Segoe UI',16)
$carSimpleIds = @('compact','kart','forklift','electric','hovercraft')
for ($carSimpleRow=0; $carSimpleRow -lt 5; $carSimpleRow++) {
 $carSimpleY = $carSimpleRow*490
 $carSimpleDrawing.DrawString(($carSimpleIds[$carSimpleRow]+' | BEFORE / AFTER'),$carSimpleFont,[System.Drawing.Brushes]::White,[single]8,[single]$carSimpleY)
 for ($carSimpleColumn=0; $carSimpleColumn -lt 2; $carSimpleColumn++) {
  $carSimplePhase = @('before','final')[$carSimpleColumn]
  $carSimplePath = Join-Path $carSimpleRoot ($carSimplePhase+'/gl_compatibility/'+$carSimpleIds[$carSimpleRow]+'-front.png')
  $carSimpleImage = [System.Drawing.Image]::FromFile($carSimplePath)
  $carSimpleDrawing.DrawImage($carSimpleImage,[int]($carSimpleColumn*600),[int]($carSimpleY+28),600,456)
  $carSimpleImage.Dispose()
 }
}
$carSimpleSheet.Save((Join-Path $carSimpleRoot 'before-after.png'))
$carSimpleDrawing.Dispose(); $carSimpleSheet.Dispose(); $carSimpleFont.Dispose()
Write-Output 'CAR_SIMPLIFICATION_COMPARISONS: 20 measured image pairs; five-car sheet saved.'
