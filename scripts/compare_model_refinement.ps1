$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$modelComparisonRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-model-refinement-2026-11-12'
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
public static class ModelRefinementPixels {
 public static int Count(string a,string b) {
  using(var x=new Bitmap(a)) using(var y=new Bitmap(b)) {
   if(x.Size!=y.Size) return -1;
   int count=0;
   for(int j=0;j<x.Height;j++) for(int i=0;i<x.Width;i++)
    if(x.GetPixel(i,j).ToArgb()!=y.GetPixel(i,j).ToArgb()) count++;
   return count;
  }
 }
}
'@
$modelComparisonRows = @()
foreach ($modelComparisonRenderer in @('gl_compatibility','mobile')) {
 foreach ($modelComparisonView in @('front','rear','side','overhead')) {
  $modelComparisonName = 'super_rally-'+$modelComparisonView+'.png'
  $modelComparisonBefore = Join-Path $modelComparisonRoot ('before/'+$modelComparisonRenderer+'/'+$modelComparisonName)
  $modelComparisonAfter = Join-Path $modelComparisonRoot ('after/'+$modelComparisonRenderer+'/'+$modelComparisonName)
  $modelComparisonDifference = [ModelRefinementPixels]::Count($modelComparisonBefore,$modelComparisonAfter)
  $modelComparisonRows += @{ renderer=$modelComparisonRenderer; view=$modelComparisonView; changed_pixels=$modelComparisonDifference }
 }
}
$modelComparisonRows | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $modelComparisonRoot 'challenger-pixel-controls.json')
$modelComparisonCars = @('compact','kart','forklift','electric','hovercraft')
$modelComparisonSheet = New-Object System.Drawing.Bitmap(1200,2380)
$modelComparisonDrawing = [System.Drawing.Graphics]::FromImage($modelComparisonSheet)
$modelComparisonDrawing.Clear([System.Drawing.ColorTranslator]::FromHtml('#18232c'))
$modelComparisonFont = New-Object System.Drawing.Font('Segoe UI',16)
for ($modelComparisonIndex=0; $modelComparisonIndex -lt 5; $modelComparisonIndex++) {
 $modelComparisonY = $modelComparisonIndex*476
 $modelComparisonDrawing.DrawString(($modelComparisonCars[$modelComparisonIndex]+'   BEFORE / AFTER'),$modelComparisonFont,[System.Drawing.Brushes]::White,[single]8,[single]$modelComparisonY)
 for ($modelComparisonColumn=0; $modelComparisonColumn -lt 2; $modelComparisonColumn++) {
  $modelComparisonPhase = @('before','after')[$modelComparisonColumn]
  $modelComparisonFolder = if ($modelComparisonPhase -eq 'after' -and (Test-Path -LiteralPath (Join-Path $modelComparisonRoot 'final/gl_compatibility'))) { 'final' } else { $modelComparisonPhase }
  $modelComparisonPath = Join-Path $modelComparisonRoot ($modelComparisonFolder+'/gl_compatibility/'+$modelComparisonCars[$modelComparisonIndex]+'-front.png')
  $modelComparisonImage = [System.Drawing.Image]::FromFile($modelComparisonPath)
  $modelComparisonDrawing.DrawImage($modelComparisonImage,[int]($modelComparisonColumn*600),[int]($modelComparisonY+25),600,450)
  $modelComparisonImage.Dispose()
 }
}
$modelComparisonSheet.Save((Join-Path $modelComparisonRoot 'before-after.png'))
$modelComparisonDrawing.Dispose()
$modelComparisonSheet.Dispose()
$modelComparisonFont.Dispose()
Write-Output 'CHALLENGER_PIXELS: eight comparisons recorded; concurrent protected-source edits must be checked against the source receipt. Five-car before/after sheet saved.'
if (@($modelComparisonRows | Where-Object { $_.changed_pixels -ne 0 }).Count -gt 0) { throw 'Original Challenger pixel-identity gate remains unmet; concurrent Challenger source/mesh changes are retained and excluded from the authored refinement.' }
