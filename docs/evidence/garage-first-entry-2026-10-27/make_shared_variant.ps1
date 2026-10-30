$ErrorActionPreference='Stop'
$workspacePath=(Resolve-Path -LiteralPath "$PSScriptRoot/../../..").Path
$variantPath=Join-Path $workspacePath 'build/garage-first-entry-variants/shared'
New-Item -ItemType Directory -Path $variantPath -Force | Out-Null
foreach ($sourceDirectory in Get-ChildItem -LiteralPath (Join-Path $workspacePath 'game') -Directory) {
    if ($sourceDirectory.Name -eq 'ui') { continue }
    $linkPath=Join-Path $variantPath $sourceDirectory.Name
    if (!(Test-Path -LiteralPath $linkPath)) { New-Item -ItemType Junction -Path $linkPath -Target $sourceDirectory.FullName | Out-Null }
}
New-Item -ItemType Directory -Path (Join-Path $variantPath 'ui') -Force | Out-Null
foreach ($sourceFile in Get-ChildItem -LiteralPath (Join-Path $workspacePath 'game/ui') -File) {
    Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $variantPath 'ui') -Force
}
foreach ($sourceDirectory in Get-ChildItem -LiteralPath (Join-Path $workspacePath 'game/ui') -Directory) {
    $linkPath=Join-Path $variantPath ('ui/'+$sourceDirectory.Name)
    if (!(Test-Path -LiteralPath $linkPath)) { New-Item -ItemType Junction -Path $linkPath -Target $sourceDirectory.FullName | Out-Null }
}
Copy-Item -LiteralPath (Join-Path $workspacePath 'game/project.godot') -Destination (Join-Path $variantPath 'project.godot') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'room_program.gdshader') -Destination (Join-Path $variantPath 'ui/room_program.gdshader') -Force
Write-Output $variantPath
