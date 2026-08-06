param(
    [string]$BackendUrl = "",
    [string]$CandidateUrls = "",
    [int]$Port = 8000,
    [switch]$SkipAdbReverse,
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"

$FrontendRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $FrontendRoot

$defaultUsbUrl = "http://127.0.0.1:${Port}"
$emulatorUrl = "http://10.0.2.2:${Port}"
$virtualInterfacePattern = "vEthernet|WSL|VirtualBox|VMware|Loopback|Bluetooth|ProTUN|Proton|VPN|Tailscale|ZeroTier|Hyper-V|TAP"

$adapterDescriptions = @{}
Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
    $adapterDescriptions[$_.Name] = $_.InterfaceDescription
}

$lanUrls = @(
    Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $description = if ($adapterDescriptions.ContainsKey($_.InterfaceAlias)) {
                $adapterDescriptions[$_.InterfaceAlias]
            } else {
                ""
            }
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.InterfaceAlias -notmatch $virtualInterfacePattern -and
            $description -notmatch $virtualInterfacePattern
        } |
        Sort-Object -Property PrefixOrigin, InterfaceAlias |
        ForEach-Object { "http://$($_.IPAddress):${Port}" }
)

$adb = Get-Command adb -ErrorAction SilentlyContinue
$connectedAndroidDevices = @()
if ($adb) {
    $connectedAndroidDevices = @(
        & adb devices |
            Select-Object -Skip 1 |
            Where-Object { $_ -match "^\S+\s+device$" } |
            ForEach-Object { ($_ -split "\s+")[0] }
    )
}

$canUseUsbReverse = -not $SkipAdbReverse -and $adb -and $connectedAndroidDevices.Count -gt 0

if ([string]::IsNullOrWhiteSpace($BackendUrl)) {
    if ($canUseUsbReverse) {
        $BackendUrl = $defaultUsbUrl
    } elseif ($lanUrls.Count -gt 0) {
        $BackendUrl = $lanUrls[0]
    } else {
        $BackendUrl = $emulatorUrl
    }
}

$candidateList = New-Object System.Collections.Generic.List[string]
$explicitCandidateUrls = @()
if (-not [string]::IsNullOrWhiteSpace($CandidateUrls)) {
    $explicitCandidateUrls = $CandidateUrls -split ","
}

foreach ($url in @($BackendUrl) + $explicitCandidateUrls + @($defaultUsbUrl, $emulatorUrl) + $lanUrls) {
    $trimmed = "$url".Trim()
    if ($trimmed -and -not $candidateList.Contains($trimmed)) {
        $candidateList.Add($trimmed)
    }
}
$candidateDefine = [string]::Join(",", $candidateList)

if (-not $SkipAdbReverse) {
    if (-not $adb) {
        Write-Warning "adb was not found in PATH. Continuing with the LAN backend URL."
    } elseif ($connectedAndroidDevices.Count -eq 0) {
        Write-Warning "No authorized Android USB device was found. Continuing with the LAN backend URL."
    } else {
        Write-Host "Configuring adb reverse tcp:${Port} -> tcp:${Port}"
        & adb reverse "tcp:${Port}" "tcp:${Port}" | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb reverse failed. Reconnect and authorize the Android device, then retry."
        }
    }
}

try {
    $healthResponse = Invoke-WebRequest `
        -UseBasicParsing `
        -Uri "${BackendUrl}/api/health/" `
        -TimeoutSec 3
    if ($healthResponse.StatusCode -ne 200) {
        throw "Unexpected health status $($healthResponse.StatusCode)."
    }
    Write-Host "Backend health check passed at ${BackendUrl}"
} catch {
    throw "Backend is not reachable at ${BackendUrl}. Start Django first. $($_.Exception.Message)"
}

Write-Host "Starting Flutter Android with API_BASE_URL=$BackendUrl"
Write-Host "Backend candidates:"
foreach ($url in $candidateList) {
    Write-Host "  $url"
}

if ($PrintOnly) {
    return
}

flutter run `
    --dart-define=API_BASE_URL=$BackendUrl `
    --dart-define=API_BASE_URL_CANDIDATES=$candidateDefine `
    --dart-define=API_BASE_URL_STRICT=false
