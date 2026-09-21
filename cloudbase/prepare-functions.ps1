$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'functions/orbit-sync-common/index.js'
$targets = @(
  'orbit-sync-push',
  'orbit-sync-pull',
  'orbit-sync-delete-data',
  'orbit-api'
)

foreach ($target in $targets) {
  Copy-Item -LiteralPath $source -Destination (
    Join-Path $PSScriptRoot "functions/$target/sync-common.js"
  ) -Force
}

Write-Host 'Prepared four self-contained CloudBase function directories.'
