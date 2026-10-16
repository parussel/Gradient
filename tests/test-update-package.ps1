$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$changed = Join-Path $root 'CHANGED'

if (-not (Test-Path -LiteralPath $changed -PathType Leaf)) {
    throw 'CHANGED is missing; FHEM update check would receive a 404 response.'
}

$content = Get-Content -Raw -LiteralPath $changed
if ([string]::IsNullOrWhiteSpace($content) -or $content -match '404:\s*Not Found') {
    throw 'CHANGED does not contain a usable FHEM update history.'
}

Write-Host 'GRADIENT_UPDATE_PACKAGE_OK'
