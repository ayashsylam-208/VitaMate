param(
    [string]$HostAddress = "0.0.0.0",
    [int]$Port = 8000,
    [int]$AIServicePort = 8010,
    [switch]$SkipAIService,
    [switch]$NoReload
)

$ErrorActionPreference = "Stop"

$BackendRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $BackendRoot

$env:DJANGO_SETTINGS_MODULE = "vitamate_project.settings_dev"
$env:DJANGO_DEV_ALLOW_ALL_HOSTS = if ($env:DJANGO_DEV_ALLOW_ALL_HOSTS) { $env:DJANGO_DEV_ALLOW_ALL_HOSTS } else { "1" }
$env:DJANGO_DEV_CORS_ALLOW_ALL = if ($env:DJANGO_DEV_CORS_ALLOW_ALL) { $env:DJANGO_DEV_CORS_ALLOW_ALL } else { "1" }

$Python = Join-Path $BackendRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    $Python = "python"
}

if (-not $SkipAIService) {
    $AIListener = Get-NetTCPConnection `
        -State Listen `
        -LocalPort $AIServicePort `
        -ErrorAction SilentlyContinue
    if (-not $AIListener) {
        $AIRuntime = Join-Path (Split-Path $BackendRoot -Parent) ".local\vitamate_ai_runtime"
        $AIRuntimePython = Join-Path $AIRuntime ".venv\Scripts\python.exe"
        if (Test-Path $AIRuntimePython) {
            $AILogDirectory = Join-Path $AIRuntime "logs"
            New-Item -ItemType Directory -Force -Path $AILogDirectory | Out-Null
            $AIStartScript = Join-Path $BackendRoot "scripts\run_ai_service.ps1"
            Write-Host "Starting VitaMate AI service on 127.0.0.1:${AIServicePort}"
            $AIProcess = Start-Process `
                -FilePath "powershell.exe" `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
                    "-File", $AIStartScript,
                    "-PackageRoot", $AIRuntime,
                    "-Port", $AIServicePort
                ) `
                -WorkingDirectory $BackendRoot `
                -WindowStyle Hidden `
                -RedirectStandardOutput (Join-Path $AILogDirectory "service.stdout.log") `
                -RedirectStandardError (Join-Path $AILogDirectory "service.stderr.log") `
                -PassThru

            $Deadline = (Get-Date).AddSeconds(45)
            do {
                Start-Sleep -Milliseconds 500
                $AIListener = Get-NetTCPConnection `
                    -State Listen `
                    -LocalPort $AIServicePort `
                    -ErrorAction SilentlyContinue
            } while (-not $AIListener -and -not $AIProcess.HasExited -and (Get-Date) -lt $Deadline)

            if (-not $AIListener) {
                $AIErrorLog = Join-Path $AILogDirectory "service.stderr.log"
                if (Test-Path $AIErrorLog) {
                    Get-Content -LiteralPath $AIErrorLog -Tail 40 | Write-Host
                }
                throw "VitaMate AI service failed to start on port $AIServicePort."
            }
        } else {
            throw "AI runtime is not installed. Run scripts\install_ai_service.ps1, or explicitly use -SkipAIService."
        }
    }

    Write-Host "Waiting for the VitaMate AI pipeline to become ready..."
    try {
        $AIReady = Invoke-RestMethod `
            -Uri "http://127.0.0.1:${AIServicePort}/readyz" `
            -TimeoutSec 300
    } catch {
        $AIErrorLog = Join-Path `
            (Join-Path (Split-Path $BackendRoot -Parent) ".local\vitamate_ai_runtime\logs") `
            "service.stderr.log"
        if (Test-Path $AIErrorLog) {
            Get-Content -LiteralPath $AIErrorLog -Tail 40 | Write-Host
        }
        throw "VitaMate AI service is running but its model pipeline is not ready: $($_.Exception.Message)"
    }
    if ($AIReady.status -ne "ready") {
        throw "VitaMate AI service returned an unexpected readiness status: $($AIReady.status)"
    }
    Write-Host "VitaMate AI service is ready on 127.0.0.1:${AIServicePort}."
}

$virtualInterfacePattern = "vEthernet|WSL|VirtualBox|VMware|Loopback|Bluetooth|Proton|VPN|Tailscale|ZeroTier|Hyper-V|TAP"
$adapterDescriptions = @{}
Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
    $adapterDescriptions[$_.Name] = $_.InterfaceDescription
}

Write-Host "Starting VitaMate backend with settings_dev on ${HostAddress}:${Port}"
Write-Host "Phone over USB: run adb reverse tcp:${Port} tcp:${Port}, then use http://127.0.0.1:${Port}"
Write-Host "Phone over Wi-Fi: use one of these LAN addresses if adb reverse is not available:"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $description = if ($adapterDescriptions.ContainsKey($_.InterfaceAlias)) {
            $adapterDescriptions[$_.InterfaceAlias]
        } else {
            ""
        }
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown" -and
        $_.InterfaceAlias -notmatch $virtualInterfacePattern -and
        $description -notmatch $virtualInterfacePattern
    } |
    ForEach-Object { Write-Host "  http://$($_.IPAddress):${Port}" }

$RunArgs = @("manage.py", "runserver", "${HostAddress}:${Port}")
if ($NoReload) {
    $RunArgs += "--noreload"
}
& $Python @RunArgs
