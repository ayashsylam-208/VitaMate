param(
    [string]$InstallerPassword = "VitaMatePg#2026",
    [string]$DbName = "vitamate",
    [string]$DbUser = "vitamate",
    [string]$DbPassword = "vitamate",
    [string]$PgHost = "localhost",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

$portableScript = Join-Path $PSScriptRoot "setup_postgres_portable.ps1"

Write-Output "The installer-based setup is deprecated for this workspace."
Write-Output "Switching automatically to the portable PostgreSQL setup..."

& $portableScript `
    -SuperPassword $InstallerPassword `
    -DbName $DbName `
    -DbUser $DbUser `
    -DbPassword $DbPassword `
    -PgHost $PgHost `
    -Port $Port
