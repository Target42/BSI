# Kopiert die gebauten Pakete und Binaries nach /tmp/isms auf einem Linux-Rechner.
# Der private Schlüssel wird einmal über ssh-agent entsperrt. Danach fragen ssh und scp
# nicht erneut nach dem Kennwort. Ein Port-Tunnel transportiert diese Dateien nicht.
#
# Pflicht:
#   $env:ISMS_USER = "ubuntu"
#   $env:ISMS_HOST = "192.168.1.10"
#   $env:ISMS_SSH_KEY = "$env:USERPROFILE\.ssh\id_ed25519"
#   .\scripts\stage-to-linux.ps1
#
# Optional:
#   $env:ISMS_SSH_PORT = "22"
#   $env:ISMS_REMOTE_DIR = "/tmp/isms"
#   .\scripts\stage-to-linux.ps1 -QtClient "D:\pfad\ISMS.exe"

[CmdletBinding()]
param(
    [string] $IdentityFile,
    [string] $QtClient
)

$ErrorActionPreference = "Stop"

$user = [string]$env:ISMS_USER
$hostName = [string]$env:ISMS_HOST
$sshPort = [string]$env:ISMS_SSH_PORT
$remoteDir = [string]$env:ISMS_REMOTE_DIR
if ([string]::IsNullOrWhiteSpace($IdentityFile)) {
    $IdentityFile = [string]$env:ISMS_SSH_KEY
}

if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($hostName)) {
    throw @"
ISMS_USER und ISMS_HOST müssen gesetzt sein.

  `$env:ISMS_USER = `"ubuntu`"
  `$env:ISMS_HOST = `"mein-linux-host`"
  `$env:ISMS_SSH_KEY = `"`$env:USERPROFILE\.ssh\id_ed25519`"
  .\scripts\stage-to-linux.ps1
"@
}
if ([string]::IsNullOrWhiteSpace($IdentityFile)) {
    throw "ISMS_SSH_KEY oder -IdentityFile fehlt. Pfad zum privaten Schlüssel angeben."
}
if (-not (Test-Path -LiteralPath $IdentityFile)) {
    throw "Privater Schlüssel nicht gefunden: $IdentityFile"
}
if ([string]::IsNullOrWhiteSpace($sshPort)) {
    $sshPort = "22"
}
if ([string]::IsNullOrWhiteSpace($remoteDir)) {
    $remoteDir = "/tmp/isms"
}
if ($remoteDir -notmatch '^/[A-Za-z0-9_./-]+$') {
    throw "ISMS_REMOTE_DIR enthält ungültige Zeichen: $remoteDir"
}

foreach ($cmd in @("ssh", "scp", "ssh-add")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd nicht im PATH. OpenSSH-Client unter Windows aktivieren."
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]

$packageDir = Join-Path $repoRoot "dist\packages"
if (Test-Path -LiteralPath $packageDir) {
    Get-ChildItem -LiteralPath $packageDir -File |
        Where-Object { $_.Extension -in ".deb", ".rpm" } |
        ForEach-Object { $files.Add($_) }
}

foreach ($rel in @(
        "isms-server\dist\isms-server-linux-amd64",
        "isms-server\dist\isms-server-windows-amd64.exe"
    )) {
    $path = Join-Path $repoRoot $rel
    if (Test-Path -LiteralPath $path) {
        $files.Add((Get-Item -LiteralPath $path))
    }
}

if (-not [string]::IsNullOrWhiteSpace($QtClient)) {
    if (-not (Test-Path -LiteralPath $QtClient)) {
        throw "Qt-Client nicht gefunden: $QtClient"
    }
    $files.Add((Get-Item -LiteralPath $QtClient))
}
else {
    $buildDir = Join-Path $repoRoot "build"
    if (Test-Path -LiteralPath $buildDir) {
        $qt = Get-ChildItem -LiteralPath $buildDir -Recurse -Filter "ISMS.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\[Dd]ebug\\' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($qt) {
            $files.Add($qt)
        }
    }
}

if ($files.Count -eq 0) {
    throw "Nichts zu kopieren. Zuerst Pakete oder Binaries bauen."
}

function Unlock-SshKey {
    param([string] $KeyPath)

    $agent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if ($null -eq $agent) {
        throw "Der Dienst ssh-agent fehlt. OpenSSH-Authentication-Agent installieren."
    }
    if ($agent.Status -ne "Running") {
        try {
            Start-Service ssh-agent
        }
        catch {
            throw @"
ssh-agent läuft nicht und konnte nicht gestartet werden.
Einmal als Administrator:

  Set-Service ssh-agent -StartupType Manual
  Start-Service ssh-agent

Danach dieses Skript erneut starten. Die Passphrase wird dann einmal abgefragt.
"@
        }
    }

    Write-Host "Schlüssel entsperren (Passphrase einmal eingeben): $KeyPath"
    & ssh-add -- $KeyPath
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-add fehlgeschlagen (Exit $LASTEXITCODE)."
    }
}

Unlock-SshKey -KeyPath $IdentityFile

$sshTarget = "${user}@${hostName}"
$sshArgs = @(
    "-p", $sshPort,
    "-i", $IdentityFile,
    "-o", "IdentitiesOnly=yes",
    "-o", "StrictHostKeyChecking=accept-new"
)
$scpArgs = @(
    "-P", $sshPort,
    "-i", $IdentityFile,
    "-o", "IdentitiesOnly=yes",
    "-o", "StrictHostKeyChecking=accept-new"
)

Write-Host "Zielverzeichnis anlegen: ${sshTarget}:$remoteDir"
& ssh @sshArgs $sshTarget "mkdir -p -- '$remoteDir'"
if ($LASTEXITCODE -ne 0) {
    throw "ssh mkdir fehlgeschlagen (Exit $LASTEXITCODE)."
}

Write-Host "Kopiere $($files.Count) Dateien nach ${sshTarget}:$remoteDir"
foreach ($file in $files) {
    Write-Host ("  {0}  ({1:N0} Bytes)" -f $file.Name, $file.Length)
}

& scp @scpArgs @($files.FullName) "${sshTarget}:${remoteDir}/"
if ($LASTEXITCODE -ne 0) {
    throw "scp fehlgeschlagen (Exit $LASTEXITCODE)."
}

Write-Host "Fertig. Auf dem Server:"
Write-Host "  ssh -p $sshPort -i `"$IdentityFile`" $sshTarget"
Write-Host "  ls -l $remoteDir"
