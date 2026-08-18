#Requires -RunAsAdministrator
# Installiert den ISMS-Go-Server mit Autostart.
# Bevorzugt NSSM (echter Dienst). Fallback: geplante Aufgabe beim Systemstart.
#
# Beispiel:
#   .\scripts\install-windows-service.ps1
#   .\scripts\install-windows-service.ps1 -InstallDir D:\ISMS

[CmdletBinding()]
param(
    [string] $InstallDir = (Join-Path $env:ProgramData "ISMS"),
    [string] $ServiceName = "ISMSServer",
    [string] $TaskName = "ISMS Server",
    [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"

$repoServerDir = Split-Path -Parent $PSScriptRoot
$exeName = "isms-server.exe"
$sourceExe = Join-Path $repoServerDir $exeName

Write-Host "ISMS-Server nach $InstallDir installieren…"

if (-not $SkipBuild) {
    Push-Location $repoServerDir
    try {
        Write-Host "go build ./cmd/isms-server"
        go build -o $exeName ./cmd/isms-server
        if ($LASTEXITCODE -ne 0) {
            throw "go build fehlgeschlagen (Exit $LASTEXITCODE)."
        }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $sourceExe)) {
    throw "Binary nicht gefunden: $sourceExe (ohne -SkipBuild wird gebaut)."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "logs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "migrations") | Out-Null

Copy-Item -Force $sourceExe (Join-Path $InstallDir $exeName)
Copy-Item -Force (Join-Path $repoServerDir "migrations\*.sql") (Join-Path $InstallDir "migrations")

$envSource = Join-Path $repoServerDir ".env"
$envExample = Join-Path $repoServerDir ".env.example"
$envTarget = Join-Path $InstallDir ".env"
if (-not (Test-Path $envTarget)) {
    if (Test-Path $envSource) {
        Copy-Item $envSource $envTarget
        Write-Host "Bestehende .env nach $envTarget kopiert."
    } elseif (Test-Path $envExample) {
        Copy-Item $envExample $envTarget
        Write-Host "Vorlage .env.example nach $envTarget kopiert — bitte anpassen."
    }
}

$installedExe = Join-Path $InstallDir $exeName
$nssm = Get-Command nssm -ErrorAction SilentlyContinue

function Unregister-ScheduledTaskIfPresent {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

if ($nssm) {
    Write-Host "NSSM gefunden — Windows-Dienst '$ServiceName' einrichten."
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        & nssm stop $ServiceName
        & nssm remove $ServiceName confirm
    }
    Unregister-ScheduledTaskIfPresent

    & nssm install $ServiceName $installedExe
    & nssm set $ServiceName AppDirectory $InstallDir
    & nssm set $ServiceName DisplayName "ISMS Server"
    & nssm set $ServiceName Description "IT-Grundschutz ISMS API (Go)"
    & nssm set $ServiceName Start SERVICE_AUTO_START
    & nssm set $ServiceName AppStdout (Join-Path $InstallDir "logs\stdout.log")
    & nssm set $ServiceName AppStderr (Join-Path $InstallDir "logs\stderr.log")
    & nssm set $ServiceName AppRotateFiles 1
    & nssm set $ServiceName AppRotateBytes 10485760
    & nssm set $ServiceName AppExit Default Restart
    & nssm set $ServiceName AppRestartDelay 5000
    & nssm start $ServiceName

    Write-Host "Dienst gestartet. Status: $((Get-Service $ServiceName).Status)"
    Write-Host "Logs: $(Join-Path $InstallDir 'logs')"
} else {
    Write-Host "NSSM nicht im PATH — geplante Aufgabe '$TaskName' (Autostart) einrichten."
    Write-Host "Tipp: choco install nssm  oder  winget install NSSM.NSSM  für einen echten Dienst."

    $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existingService) {
        throw "Dienst '$ServiceName' existiert bereits (NSSM?). Erst uninstall-windows-service.ps1 ausführen."
    }
    Unregister-ScheduledTaskIfPresent

    $action = New-ScheduledTaskAction -Execute $installedExe -WorkingDirectory $InstallDir
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -RestartCount 999 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description "IT-Grundschutz ISMS API (Go)" | Out-Null
    Start-ScheduledTask -TaskName $TaskName

    Write-Host "Aufgabe gestartet. Prüfung: Get-ScheduledTask -TaskName '$TaskName'"
}

Write-Host ""
Write-Host "Healthcheck:  curl http://localhost:8080/health"
Write-Host "Konfiguration: $envTarget"
Write-Host "Installationsordner: $InstallDir"
