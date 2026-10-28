<# Open private staging Studio through an account-authenticated loopback proxy. #>
[CmdletBinding()]
param(
    [string]$Config = '.tools/gcp-staging/studio-identity.private.json',
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not [IO.Path]::IsPathRooted($Config)) { $Config = Join-Path $repoRoot $Config }
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw 'Studio identity is not configured yet. Complete the dedicated Google OAuth client setup first.'
}
$studioConfig = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
if (-not $studioConfig.admin_enabled -or -not $studioConfig.studio_identity_tenant) {
    throw 'The selected configuration has no private Studio identity tenant.'
}
$service = 'bmt-stg-' + $studioConfig.owner.Substring(0, 8) + '-studio'
$url = 'http://127.0.0.1:8182/admin'
$env:CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE = Join-Path $repoRoot '.tools/gcp-staging/windows-trust.pem'
$gcloud = (Get-Command gcloud.cmd -ErrorAction Stop).Source
$account = (& $gcloud auth list '--filter=status:ACTIVE' '--format=value(account)' --quiet).Trim()
if ($LASTEXITCODE -ne 0 -or $account -ne $studioConfig.studio_identity_login_hint) {
    throw 'Sign in to gcloud with the configured Studio owner account first.'
}
$listener = Get-NetTCPConnection -LocalPort 8182 -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
    $folder = Join-Path $repoRoot 'build/studio-proxy'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $sdkRoot = Split-Path (Split-Path $gcloud -Parent) -Parent
    $python = Join-Path $sdkRoot 'platform/bundledpython/python.exe'
    $entry = Join-Path $sdkRoot 'lib/gcloud.py'
    $arguments = @(('"' + $entry + '"'), 'run', 'services', 'proxy', $service,
        ('--project=' + $studioConfig.project), ('--region=' + $studioConfig.region), '--port=8182', '--quiet')
    $proxy = Start-Process -FilePath $python -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $folder 'stdout.log') -RedirectStandardError (Join-Path $folder 'stderr.log')
    $proxy.Id | Set-Content -LiteralPath (Join-Path $folder 'launcher.pid')
    $deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Milliseconds 300
        $proxy.Refresh()
        if ($proxy.HasExited) { throw ('Studio proxy exited. Inspect ' + (Join-Path $folder 'stderr.log')) }
        $listener = Get-NetTCPConnection -LocalPort 8182 -State Listen -ErrorAction SilentlyContinue
    } while (-not $listener -and (Get-Date) -lt $deadline)
    if (-not $listener) { throw 'Studio proxy did not start within 45 seconds. Inspect build/studio-proxy/stderr.log.' }
}
# A busy port is never taken over, and an unrelated service is never opened as Studio.
$identity = Invoke-RestMethod -Uri 'http://127.0.0.1:8182/v1/admin/auth/config' -TimeoutSec 30
if (-not $identity.configured -or $identity.tenantId -ne $studioConfig.studio_identity_tenant) {
    throw 'Port 8182 does not expose the configured Studio tenant; no existing process was stopped.'
}
if (-not $NoBrowser) { Start-Process $url }
Write-Host ('Private Studio: ' + $url)
