$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'scripts/dev.ps1').Path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'dev.ps1 parse failure' }
$export = $tree.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Export-Android' }, $true)
$script:fixtureScripts = (Resolve-Path 'scripts').Path
Invoke-Expression ($export.Extent.Text.Replace('$PSScriptRoot', '$script:fixtureScripts'))
$script:seen = [System.Collections.Generic.List[string]]::new()
$script:godot = 'unused-engine'
$AndroidPreset = 'Android Debug'
function python {
    $name = Split-Path -Leaf $args[0]
    $script:seen.Add($name)
    $global:LASTEXITCODE = if ($name -eq 'check_garage_workshop.py') { 1 } else { 0 }
}
function Test-AndroidTools { throw 'Export passed a rejected workshop' }
try { Export-Android; throw 'Expected workshop rejection' }
catch {
    if ($_.Exception.Message -notlike 'Garage workshop is stale*') { throw }
}
if (($script:seen -join ',') -ne 'check_android_delivery.py,check_garage_workshop.py') { throw 'Unexpected preflight ordering' }
Write-Output 'WORKSHOP_EXPORT_REJECTION: actual Export-Android stops on workshop failure before preparation/tools/export'
