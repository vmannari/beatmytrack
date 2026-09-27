param([int]$Port = 18765, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'serve.py'), '--port', "$Port")
if ($NoBrowser) { $arguments += '--no-browser' }
& python @arguments
exit $LASTEXITCODE
