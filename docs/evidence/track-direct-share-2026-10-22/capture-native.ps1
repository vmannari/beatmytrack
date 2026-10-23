$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class TrackShareWindowCapture {
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 public delegate bool WindowVisitor(IntPtr hwnd,IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumWindows(WindowVisitor callback,IntPtr data);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr window,StringBuilder name,int count);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 public static IntPtr FindShare() {IntPtr found=IntPtr.Zero;EnumWindows((w,d)=>{if(!IsWindowVisible(w))return true;var name=new StringBuilder(512);GetWindowText(w,name,512);uint pid;GetWindowThreadProcessId(w,out pid);var process=System.Diagnostics.Process.GetProcessById((int)pid).ProcessName;var cls=new StringBuilder(512);GetClassName(w,cls,512);if(process.ToLower().Contains("share") || name.ToString().ToLower().Contains("share")){Console.WriteLine(process+" / "+name.ToString()+" / "+cls.ToString());if(process.ToLower().Contains("share") || name.ToString().Contains("share validation"))found=w;}return true;},IntPtr.Zero);return found;}
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [StructLayout(LayoutKind.Sequential)] public struct Point {public int X,Y;}
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point point);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window,IntPtr hdc,uint flags);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window,out Rect rect);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window,StringBuilder title,int count);
}
"@
[void][TrackShareWindowCapture]::SetProcessDPIAware()
$repo = (Get-Location).Path
$env:APPDATA = Join-Path $repo 'build/track-direct-share/native-capture-user'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$log = Join-Path $repo 'build/track-direct-share/native-capture.log'
$errors = Join-Path $repo 'build/track-direct-share/native-capture-errors.log'
$arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $repo 'scripts/dev.ps1')+'"'),'-Action','TestScript','-ScriptPath','res://tests/test_track_direct_share.gd','-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--native-share-click')
$process = Start-Process powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
$timer = [Diagnostics.Stopwatch]::StartNew()
while ($timer.Elapsed.TotalSeconds -lt 55 -and -not $process.HasExited) {
 if ((Test-Path -LiteralPath $log) -and (Select-String -LiteralPath $log -SimpleMatch 'WINDOWS_SHARE_CLICK_READY' -Quiet)) { break }
 Start-Sleep -Milliseconds 200
}
$fixture = [TrackShareWindowCapture]::FindShare()
if ($fixture -eq [IntPtr]::Zero) { throw 'Owned share fixture was not found; no click performed.' }
$fixtureTitle = New-Object System.Text.StringBuilder 512
[void][TrackShareWindowCapture]::GetWindowText($fixture,$fixtureTitle,512)
if ($fixtureTitle.ToString() -ne 'Beat my track - share validation (DEBUG)') { throw 'Refusing click outside the owned fixture.' }
$bounds = New-Object TrackShareWindowCapture+Rect
[void][TrackShareWindowCapture]::GetWindowRect($fixture,[ref]$bounds)
$cursor = New-Object TrackShareWindowCapture+Point
[void][TrackShareWindowCapture]::GetCursorPos([ref]$cursor)
[void][TrackShareWindowCapture]::SetCursorPos([int](($bounds.Left+$bounds.Right)/2),[int](($bounds.Top+$bounds.Bottom)/2))
[TrackShareWindowCapture]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[TrackShareWindowCapture]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
[void][TrackShareWindowCapture]::SetCursorPos($cursor.X,$cursor.Y)
Start-Sleep -Milliseconds 4000
$window = [TrackShareWindowCapture]::GetForegroundWindow()
if ($window -eq [IntPtr]::Zero) { throw "No visible Windows share window was found after the native call." }
$title = New-Object System.Text.StringBuilder 512
[void][TrackShareWindowCapture]::GetWindowText($window,$title,512)
Write-Output ('Share window: '+$title.ToString())

$rect = New-Object TrackShareWindowCapture+Rect
[void][TrackShareWindowCapture]::GetWindowRect($window,[ref]$rect)
$bitmap = New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
$bitmap.Save((Join-Path $repo 'docs/evidence/track-direct-share-2026-10-22/windows-share-click-screen.png'))
$hdc = $graphics.GetHdc()
$printed = [TrackShareWindowCapture]::PrintWindow($window,$hdc,2)
$graphics.ReleaseHdc($hdc)
$bitmap.Save((Join-Path $repo 'docs/evidence/track-direct-share-2026-10-22/windows-share-parent-print.png'))
Write-Output ('PrintWindow: '+$printed)
$graphics.Dispose()
$bitmap.Dispose()
Write-Output 'Captured foreground window after native handoff; inspect before classifying it as the chooser.'
