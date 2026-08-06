param(
    [string]$ZipPath = "",
    [string]$InstallRoot = "",
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"
$BackendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $ZipPath) {
    $ZipPath = Join-Path $BackendRoot "VitaMate_AI_Backend_Runtime_20260802.zip"
}
$ZipPath = (Resolve-Path $ZipPath).Path

if (-not $InstallRoot) {
    $InstallRoot = Join-Path (Split-Path $BackendRoot -Parent) ".local\vitamate_ai_runtime"
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)

if (Test-Path $InstallRoot) {
    if ((Get-ChildItem -LiteralPath $InstallRoot -Force | Select-Object -First 1)) {
        throw "InstallRoot is not empty: $InstallRoot"
    }
} else {
    New-Item -ItemType Directory -Path $InstallRoot | Out-Null
}

Write-Host "Extracting AI runtime to $InstallRoot"
Expand-Archive -LiteralPath $ZipPath -DestinationPath $InstallRoot

$VenvPython = Join-Path $InstallRoot ".venv\Scripts\python.exe"
& $PythonCommand -m venv (Join-Path $InstallRoot ".venv")
& $VenvPython -m pip install --upgrade "pip<26" "pip-tools==7.5.2"

$LockPath = Join-Path $InstallRoot "requirements-ai-runtime.lock.txt"
& $VenvPython -m piptools compile `
    --resolver backtracking `
    --output-file $LockPath `
    (Join-Path $InstallRoot "requirements-ai-package.txt") `
    (Join-Path $BackendRoot "ai_service_runtime\requirements-overlay.in")
& $VenvPython -m pip install -r $LockPath

$env:PYTHONPATH = (Join-Path $InstallRoot "src")
& $VenvPython (Join-Path $InstallRoot "scripts\check_ai_package_ready.py")
$BackendPython = Join-Path $BackendRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $BackendPython)) {
    throw "Backend virtual environment is missing at $BackendPython."
}
$env:DJANGO_SETTINGS_MODULE = if ($env:DJANGO_SETTINGS_MODULE) {
    $env:DJANGO_SETTINGS_MODULE
} else {
    "vitamate_project.settings_dev"
}
Push-Location $BackendRoot
try {
    & $BackendPython manage.py sync_ai_nutrition_catalog --package-root $InstallRoot
} finally {
    Pop-Location
}
Write-Host "AI runtime installed. Start it with scripts\run_ai_service.ps1."
