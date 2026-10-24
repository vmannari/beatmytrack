param([ValidateSet('All','Headless','Boundary','Mobile','Higher')][string]$Mode='All')
$ErrorActionPreference='Stop'
$capacityRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$capacityEngine='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$capacityPin=[System.IO.File]::ReadAllText((Join-Path $capacityRoot 'godot-version.txt')).Trim()
if ((& $capacityEngine --version | Out-String).Trim() -ne $capacityPin) { throw 'Pinned engine mismatch' }
$env:APPDATA=Join-Path $capacityRoot 'build/creator-object-limit/appdata'
$env:BMT_API_URL='audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$capacityProject=Join-Path $capacityRoot 'build/creator-object-limit/probe-project'
New-Item -ItemType Directory -Path $capacityProject -Force | Out-Null
# Reuse source/assets without touching the live project's autoloads or imports.
foreach ($capacityDirectory in Get-ChildItem -LiteralPath (Join-Path $capacityRoot 'game') -Directory | Where-Object Name -ne '.godot') {
    $capacityLink=Join-Path $capacityProject $capacityDirectory.Name
    if (-not (Test-Path -LiteralPath $capacityLink)) { New-Item -ItemType Junction -Path $capacityLink -Target $capacityDirectory.FullName | Out-Null }
}
$capacityConfig=[System.IO.File]::ReadAllText((Join-Path $capacityRoot 'game/project.godot'))
$capacityConfig=[regex]::Replace($capacityConfig,'(?ms)^\[autoload\]\r?\n.*?(?=^\[|\z)','')
[System.IO.File]::WriteAllText((Join-Path $capacityProject 'project.godot'),$capacityConfig)
$capacityCache=Join-Path $capacityProject '.godot'
New-Item -ItemType Directory -Path $capacityCache -Force | Out-Null
foreach ($capacityCacheName in @('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg')) {
    $capacityCacheSource=Join-Path $capacityRoot ('game/.godot/'+$capacityCacheName)
    if (Test-Path -LiteralPath $capacityCacheSource) { Copy-Item -LiteralPath $capacityCacheSource -Destination (Join-Path $capacityCache $capacityCacheName) }
}
if (-not (Test-Path -LiteralPath (Join-Path $capacityCache 'imported'))) { New-Item -ItemType Junction -Path (Join-Path $capacityCache 'imported') -Target (Join-Path $capacityRoot 'game/.godot/imported') | Out-Null }
$capacityModes=if ($Mode -eq 'All') { @('Headless','Boundary','Mobile') } else { @($Mode) }
foreach ($capacityMode in $capacityModes) {
	$capacityOutput=if ($capacityMode -eq 'Higher') { Join-Path $PSScriptRoot '../creator-object-limit-higher-2026-10-23' } else { $PSScriptRoot }
	New-Item -ItemType Directory -Path $capacityOutput -Force | Out-Null
    $capacityArgs=@('--path',$capacityProject,'--audio-driver','Dummy','--script','res://tests/profile_creator_object_limit_bootstrap.gd')
    if ($capacityMode -eq 'Mobile') { $capacityArgs+=@('--rendering-method','mobile') }
    else { $capacityArgs=@('--headless')+$capacityArgs }
    $capacityArgs+=@('--',('--capacity-output='+$capacityOutput))
    if ($capacityMode -eq 'Mobile') { $capacityArgs+='--gpu-tyres' }
    if ($capacityMode -eq 'Boundary') { $capacityArgs+='--tyre-boundary' }
    if ($capacityMode -eq 'Higher') { $capacityArgs+='--higher-counts' }
    $capacityLog=Join-Path $capacityOutput ($capacityMode.ToLower()+'.log')
    $ErrorActionPreference='Continue'
    & $capacityEngine @capacityArgs *> $capacityLog
    $capacityExit=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $capacityErrors=@(Get-Content -LiteralPath $capacityLog | Where-Object { $_ -match '(^| : )(SCRIPT ERROR:|ERROR:|Parse Error:)|^FAIL ' -and $_ -notmatch 'Failed to read the root certificate store|^ERROR: Access denied$' })
    if ($capacityExit -ne 0 -or $capacityErrors.Count -gt 0) { throw ($capacityMode+' failed: exit '+$capacityExit+', unexpected diagnostics '+$capacityErrors.Count) }
    Write-Output ($capacityMode+' complete; '+$capacityLog)
}
