param(
    [string]$PackageRoot = $env:VITAMATE_AI_PACKAGE_ROOT,
    [int]$Port = 8010
)

$ErrorActionPreference = "Stop"
$BackendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $PackageRoot) {
    $PackageRoot = Join-Path (Split-Path $BackendRoot -Parent) ".local\vitamate_ai_runtime"
}
$PackageRoot = (Resolve-Path $PackageRoot).Path
$VenvPython = Join-Path $PackageRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    throw "AI virtual environment is missing at $VenvPython. Run install_ai_service.ps1 first."
}

$EnvPath = Join-Path $BackendRoot ".env"
if (-not $env:AI_MEALS_SERVICE_TOKEN -and (Test-Path $EnvPath)) {
    $TokenLine = Get-Content -LiteralPath $EnvPath | Where-Object {
        $_ -match '^AI_MEALS_SERVICE_TOKEN='
    } | Select-Object -First 1
    if ($TokenLine) {
        $env:AI_MEALS_SERVICE_TOKEN = $TokenLine.Substring(
            $TokenLine.IndexOf('=') + 1
        ).Trim()
    }
}
if (-not $env:AI_MEALS_SERVICE_TOKEN -or $env:AI_MEALS_SERVICE_TOKEN.Length -lt 32) {
    throw "Set AI_MEALS_SERVICE_TOKEN in vitamate_backend/.env to a 32+ character token."
}

$env:PYTHONPATH = "$BackendRoot;$PackageRoot\src"
$env:HF_HOME = Join-Path $PackageRoot "models\hf_home"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
if (-not $env:AI_RUNTIME_MAX_CONCURRENCY) {
    $env:AI_RUNTIME_MAX_CONCURRENCY = "1"
}
if (-not $env:AI_RUNTIME_MAX_QUEUE_SIZE) {
    $env:AI_RUNTIME_MAX_QUEUE_SIZE = "2"
}

Push-Location $PackageRoot
try {
    & $VenvPython -m uvicorn ai_service_runtime.secure_app:app `
        --host 127.0.0.1 `
        --port $Port `
        --workers 1
} finally {
    Pop-Location
}
