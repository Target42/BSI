#Requires -RunAsAdministrator
# Entfernt den per install-windows-service.ps1 eingerichteten Autostart.
# Dateien unter -InstallDir bleiben erhalten (Datenbank ist unabhängig).

[CmdletBinding()]
param(
    [string] $InstallDir = (Join-Path $env:ProgramData "ISMS"),
    [string] $ServiceName = "ISMSServer",
    [string] $TaskName = "ISMS Server",
    [switch] $RemoveFiles
)

$ErrorActionPreference = "Stop"

$nssm = Get-Command nssm -ErrorAction SilentlyContinue
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    if ($nssm) {
        & nssm stop $ServiceName
        & nssm remove $ServiceName confirm
    } else {
        Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $ServiceName | Out-Null
    }
    Write-Host "Dienst '$ServiceName' entfernt."
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Geplante Aufgabe '$TaskName' entfernt."
}

if ($RemoveFiles -and (Test-Path $InstallDir)) {
    Remove-Item -Recurse -Force $InstallDir
    Write-Host "Ordner gelöscht: $InstallDir"
} else {
    Write-Host "Dateien bleiben in $InstallDir (entfernen mit -RemoveFiles)."
}
