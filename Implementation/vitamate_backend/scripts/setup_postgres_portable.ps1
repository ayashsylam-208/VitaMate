param(
    [string]$Version = "17.9-3",
    [string]$ArchiveUrl = "https://get.enterprisedb.com/postgresql/postgresql-17.9-3-windows-x64-binaries.zip",
    [long]$ExpectedArchiveBytes = 331137607,
    [string]$SuperUser = "postgres",
    [string]$SuperPassword = "VitaMatePg#2026",
    [string]$DbName = "vitamate",
    [string]$DbUser = "vitamate",
    [string]$DbPassword = "vitamate",
    [string]$PgHost = "localhost",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$localRoot = Join-Path $repoRoot ".local"
$archiveDir = Join-Path $workspaceRoot "tmp_postgres_portable"
$archivePath = Join-Path $archiveDir "postgresql-$Version-windows-x64-binaries.zip"
$extractRoot = Join-Path $localRoot "postgresql-$Version"
$dataDir = Join-Path $localRoot "postgres-data"
$logPath = Join-Path $localRoot "postgres.log"
$bootstrapScript = Join-Path $PSScriptRoot "bootstrap_postgres.ps1"

New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
New-Item -ItemType Directory -Force -Path $localRoot | Out-Null

function Download-Archive {
    param(
        [string]$Url,
        [string]$Destination
    )

    $downloadErrors = @()

    try {
        $resumeSupported = Test-Path $Destination
        if ($resumeSupported) {
            $existingBytes = (Get-Item $Destination).Length
            if ($existingBytes -gt 0 -and $existingBytes -lt $ExpectedArchiveBytes) {
                Write-Output "Resuming PostgreSQL binaries download with curl from byte $existingBytes..."
                & curl.exe -L --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 7200 -C - -o $Destination $Url
            } else {
                Remove-Item $Destination -Force
                Write-Output "Downloading PostgreSQL binaries with curl..."
                & curl.exe -L --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 7200 -o $Destination $Url
            }
        } else {
            Write-Output "Downloading PostgreSQL binaries with curl..."
            & curl.exe -L --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 7200 -o $Destination $Url
        }
        if ($LASTEXITCODE -eq 0 -and (Test-ArchiveLooksComplete $Destination)) {
            return
        }
        $actualBytes = if (Test-Path $Destination) { (Get-Item $Destination).Length } else { 0 }
        throw "curl did not finish the archive download successfully. bytes=$actualBytes expected=$ExpectedArchiveBytes exit=$LASTEXITCODE"
    } catch {
        $downloadErrors += "curl: $($_.Exception.Message)"
    }

    try {
        if (Test-Path $Destination) {
            Remove-Item $Destination -Force
        }
        Write-Output "Downloading PostgreSQL binaries with BITS..."
        Start-BitsTransfer -Source $Url -Destination $Destination
        if (Test-ArchiveLooksComplete $Destination) {
            return
        }
        $actualBytes = if (Test-Path $Destination) { (Get-Item $Destination).Length } else { 0 }
        throw "BITS did not finish the archive download successfully. bytes=$actualBytes expected=$ExpectedArchiveBytes"
    } catch {
        $downloadErrors += "BITS: $($_.Exception.Message)"
    }

    throw ("Failed to download PostgreSQL binaries.`n" + ($downloadErrors -join "`n"))
}

function Test-ArchiveLooksComplete {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    $actualBytes = (Get-Item $Path).Length
    return $actualBytes -eq $ExpectedArchiveBytes
}

if (-not (Test-ArchiveLooksComplete $archivePath)) {
    if (Test-Path $archivePath) {
        Write-Output "Existing binaries archive size mismatch. Re-downloading a fresh copy..."
        Remove-Item $archivePath -Force
    }
    Download-Archive -Url $ArchiveUrl -Destination $archivePath
}

if (-not (Test-ArchiveLooksComplete $archivePath)) {
    throw "Downloaded PostgreSQL binaries archive size does not match the expected release payload."
}

if (-not (Test-Path $extractRoot)) {
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
}

$existingInitDb = Get-ChildItem -Path $extractRoot -Recurse -Filter initdb.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $existingInitDb) {
    Write-Output "Extracting PostgreSQL binaries..."
    tar -xf $archivePath -C $extractRoot
}

$initDb = Get-ChildItem -Path $extractRoot -Recurse -Filter initdb.exe -ErrorAction Stop | Select-Object -First 1
$pgCtl = Join-Path $initDb.DirectoryName "pg_ctl.exe"
$binDir = $initDb.DirectoryName

if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
}

if (-not (Test-Path (Join-Path $dataDir "PG_VERSION"))) {
    $pwFile = Join-Path $localRoot "postgres-superuser.pw"
    Set-Content -Path $pwFile -Value $SuperPassword -Encoding ascii
    try {
        Write-Output "Initializing PostgreSQL data directory..."
        & $initDb.FullName -D $dataDir -U $SuperUser -A scram-sha-256 --pwfile=$pwFile
    } finally {
        Remove-Item $pwFile -Force -ErrorAction SilentlyContinue
    }

    $confPath = Join-Path $dataDir "postgresql.conf"
    $confText = Get-Content $confPath -Raw
    $confText = $confText -replace "(?m)^#?\s*listen_addresses\s*=.*$", "listen_addresses = 'localhost'"
    $confText = $confText -replace "(?m)^#?\s*port\s*=.*$", "port = $Port"
    Set-Content -Path $confPath -Value $confText -Encoding ascii
}

& $pgCtl -D $dataDir status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output "Starting PostgreSQL server..."
    & $pgCtl -D $dataDir -l $logPath -w -t 60 start
}

& $bootstrapScript `
    -PgBinDir $binDir `
    -SuperUser $SuperUser `
    -SuperPassword $SuperPassword `
    -DbName $DbName `
    -DbUser $DbUser `
    -DbPassword $DbPassword `
    -PgHost $PgHost `
    -Port $Port

Write-Output "Portable PostgreSQL is ready."
Write-Output "Data directory: $dataDir"
Write-Output "Log file: $logPath"
