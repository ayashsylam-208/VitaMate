param(
    [string]$PgBinDir = "C:\Program Files\PostgreSQL\17\bin",
    [string]$SuperUser = "postgres",
    [Parameter(Mandatory = $true)]
    [string]$SuperPassword,
    [string]$DbName = "vitamate",
    [string]$DbUser = "vitamate",
    [string]$DbPassword = "vitamate",
    [string]$PgHost = "localhost",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$psql = Join-Path $PgBinDir "psql.exe"
$python = Join-Path $repoRoot ".venv\Scripts\python.exe"
$envFile = Join-Path $repoRoot ".env"

if (-not (Test-Path $psql)) {
    throw "psql.exe was not found at $psql. Install PostgreSQL first or pass -PgBinDir."
}

if (-not (Test-Path $python)) {
    throw "Python virtualenv executable was not found at $python."
}

$env:PGPASSWORD = $SuperPassword

function Invoke-PsqlScalar {
    param([string]$Sql)

    $result = & $psql -h $PgHost -p $Port -U $SuperUser -d postgres -tAc $Sql
    if ($null -eq $result) {
        return ""
    }
    return "$result".Trim()
}

$roleExists = Invoke-PsqlScalar "SELECT 1 FROM pg_roles WHERE rolname = '$DbUser'"
if ($roleExists -ne "1") {
    & $psql -h $PgHost -p $Port -U $SuperUser -d postgres -c "CREATE ROLE $DbUser WITH LOGIN PASSWORD '$DbPassword' CREATEDB;"
} else {
    & $psql -h $PgHost -p $Port -U $SuperUser -d postgres -c "ALTER ROLE $DbUser WITH LOGIN PASSWORD '$DbPassword' CREATEDB;"
}

$dbExists = Invoke-PsqlScalar "SELECT 1 FROM pg_database WHERE datname = '$DbName'"
if ($dbExists -ne "1") {
    & $psql -h $PgHost -p $Port -U $SuperUser -d postgres -c "CREATE DATABASE $DbName OWNER $DbUser;"
}

@(
    "DJANGO_ENV=dev"
    "DJANGO_SECRET_KEY=change-me"
    "DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2,testserver"
    "DJANGO_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000"
    "POSTGRES_DB=$DbName"
    "POSTGRES_USER=$DbUser"
    "POSTGRES_PASSWORD=$DbPassword"
    "POSTGRES_HOST=$PgHost"
    "POSTGRES_PORT=$Port"
) | Set-Content -Path $envFile -Encoding ascii

Push-Location $repoRoot
try {
    & $python manage.py migrate
} finally {
    Pop-Location
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Output "PostgreSQL bootstrap completed."
Write-Output "Environment file written to $envFile"
