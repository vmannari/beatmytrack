$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $repo
$env:APPDATA = Join-Path $repo 'build/challenge-entry-user'
$env:BMT_CHALLENGE_ENTRY_OUTPUT = Join-Path $PSScriptRoot 'entry'
$env:BMT_CHALLENGE_DISCOVERY_OUTPUT = Join-Path $PSScriptRoot 'browser'
$env:BMT_CHALLENGE_CAPTURE_DIR = Join-Path $PSScriptRoot 'creation'
$receipts = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $receipts -Force | Out-Null
$cases = @(
    @{ Name = 'entry-compatibility'; Script = 'test_challenge_entry.gd'; Mode = 'gl_compatibility' },
    @{ Name = 'browser-compatibility'; Script = 'test_challenge_discovery.gd'; Mode = 'gl_compatibility' },
    @{ Name = 'cards-compatibility'; Script = 'test_challenge_cards.gd'; Mode = 'gl_compatibility' },
    @{ Name = 'challenges-headless'; Script = 'test_challenges.gd'; Mode = '' },
    @{ Name = 'free-race-headless'; Script = 'test_free_race_list.gd'; Mode = '' },
    @{ Name = 'parser'; Script = 'test_script_parse.gd'; Mode = '' },
    @{ Name = 'entry-mobile'; Script = 'test_challenge_entry.gd'; Mode = 'mobile' },
    @{ Name = 'cards-mobile'; Script = 'test_challenge_cards.gd'; Mode = 'mobile' }
)
foreach ($case in $cases) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/dev.ps1', '-Action', 'TestScript', '-ScriptPath', "res://tests/$($case.Script)")
    if ($case.Mode) { $arguments += @('-Graphical', '-RenderingMethod', $case.Mode) }
    $receipt = Join-Path $receipts "$($case.Name).log"
    "powershell $($arguments -join ' ')" | Set-Content -LiteralPath $receipt -Encoding UTF8
    & powershell @arguments 2>&1 | ForEach-Object {
        $_
        [System.IO.File]::AppendAllText($receipt, $_.ToString()+[Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    }
    if ($LASTEXITCODE -ne 0) { throw "$($case.Name) failed: exit $LASTEXITCODE" }
}
