[CmdletBinding()]
param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 8000,
    [switch]$NoReload,
    [switch]$SkipAIService
)

$ErrorActionPreference = "Stop"

$runDevServer = Join-Path $PSScriptRoot "run_dev_server.ps1"
if (-not (Test-Path $runDevServer)) {
    throw "Integrated development server script was not found at $runDevServer"
}

& $runDevServer `
    -HostAddress $Bind `
    -Port $Port `
    -NoReload:$NoReload `
    -SkipAIService:$SkipAIService
