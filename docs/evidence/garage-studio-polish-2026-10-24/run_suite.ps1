$ErrorActionPreference='Stop'
$studioCases=@(
    @('test_garage_studio_polish','headless'),
    @('test_garage_studio_polish','gl_compatibility'),
    @('test_garage_studio_polish','mobile'),
    @('test_garage_tuning_layout','gl_compatibility'),
    @('test_garage_hose','gl_compatibility'),
    @('test_garage_hose','mobile'),
    @('test_garage_clean_customisation','headless'),
    @('test_garage_customisation_speed','headless'),
    @('test_app','headless'),
    @('test_script_parse','headless')
)
$studioFailed=0
foreach ($studioCase in $studioCases) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_validation.ps1') -Test $studioCase[0] -Mode $studioCase[1]
    if ($LASTEXITCODE -ne 0) {$studioFailed++}
}
Write-Output "GARAGE_STUDIO_SUITE: $studioFailed failed commands"
exit $(if ($studioFailed) {1} else {0})
