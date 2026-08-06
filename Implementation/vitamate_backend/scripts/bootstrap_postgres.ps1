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
    & $psql -h $PgHost -p $Port -U $SuperUser -d postgres -c "CREATE DATABASE $DbName OWNER $DbUser ENCODING 'UTF8' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C';"
}

$dbEncoding = Invoke-PsqlScalar "SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = '$DbName'"
if ($dbEncoding -ne "UTF8") {
    throw "Database $DbName uses $dbEncoding instead of UTF8. Migrate it before starting VitaMate."
}

$envUpdates = [ordered]@{
    "DJANGO_ENV" = "dev"
    "POSTGRES_DB" = $DbName
    "POSTGRES_USER" = $DbUser
    "POSTGRES_PASSWORD" = $DbPassword
    "POSTGRES_HOST" = $PgHost
    "POSTGRES_PORT" = "$Port"
}
$existingLines = if (Test-Path $envFile) { Get-Content $envFile } else { @() }
$updatedKeys = @{}
$updatedLines = foreach ($line in $existingLines) {
    if ($line -match '^([A-Z0-9_]+)=') {
        $key = $Matches[1]
        if ($envUpdates.Contains($key)) {
            $updatedKeys[$key] = $true
            "$key=$($envUpdates[$key])"
            continue
        }
    }
    $line
}
foreach ($entry in $envUpdates.GetEnumerator()) {
    if (-not $updatedKeys.ContainsKey($entry.Key)) {
        $updatedLines += "$($entry.Key)=$($entry.Value)"
    }
}
$updatedLines | Set-Content -Path $envFile -Encoding ascii

Push-Location $repoRoot
try {
    & $python manage.py migrate
} finally {
    Pop-Location
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Output "PostgreSQL bootstrap completed."
Write-Output "Database settings updated in $envFile"
