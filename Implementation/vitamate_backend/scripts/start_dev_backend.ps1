[CmdletBinding()]
param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 8000,
    [switch]$NoReload
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $backendRoot ".venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    throw "Python virtual environment interpreter was not found at $python"
}

$runArgs = @(
    "manage.py",
    "runserver",
    "${Bind}:${Port}"
)

if ($NoReload) {
    $runArgs += "--noreload"
}

& $python @runArgs
