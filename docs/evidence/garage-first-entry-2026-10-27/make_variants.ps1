$ErrorActionPreference='Stop'
$workspacePath=(Resolve-Path -LiteralPath "$PSScriptRoot/../../..").Path
$variantPath=Join-Path $workspacePath 'build/garage-first-entry-variants/no-cache'
New-Item -ItemType Directory -Path $variantPath -Force | Out-Null
foreach ($sourceDirectory in Get-ChildItem -LiteralPath (Join-Path $workspacePath 'game') -Directory) {
    $linkPath=Join-Path $variantPath $sourceDirectory.Name
    if (!(Test-Path -LiteralPath $linkPath)) { New-Item -ItemType Junction -Path $linkPath -Target $sourceDirectory.FullName | Out-Null }
}
$projectText=[IO.File]::ReadAllText((Join-Path $workspacePath 'game/project.godot'))
$projectText=$projectText.Replace('[rendering]',"[rendering]`nshader_compiler/shader_cache/enabled=false")
[IO.File]::WriteAllText((Join-Path $variantPath 'project.godot'),$projectText,[Text.UTF8Encoding]::new($false))
Write-Output $variantPath
