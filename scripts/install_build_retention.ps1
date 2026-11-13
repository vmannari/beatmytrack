[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$cleaner = Join-Path $PSScriptRoot 'clean_build.ps1'
$hash = [Security.Cryptography.SHA256]::Create()
try { $suffix = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($repo)))).Replace('-', '').Substring(0, 12) }
finally { $hash.Dispose() }
$taskName = "BeatMyTrack-BuildRetention-$suffix"
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $cleaner + '" -Apply') -WorkingDirectory $repo
$triggers = @((New-ScheduledTaskTrigger -Daily -At '12:00'), (New-ScheduledTaskTrigger -AtLogOn -User $user))
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$description = 'Prune disposable Beat my track build output: 7 days / 20 GiB target, 24-hour active grace; preserve pins, backups and tracked files.'
$task = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description $description -Force
$task | Select-Object TaskName, State
