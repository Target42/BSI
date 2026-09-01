# Kopiert Binary, Migrationen, Katalog und Install-Dateien auf einen Linux-Rechner.
# Zielbenutzer und Host kommen aus Umgebungsvariablen (nicht aus der Kommandozeile).
#
# Pflicht:
#   $env:ISMS_USER = "ubuntu"
#   $env:ISMS_HOST = "192.168.1.10"
#   .\scripts\copy-to-linux.ps1
#
# Optional:
#   $env:ISMS_REMOTE_DIR = "isms-server"   # Default: ~/isms-server
#   $env:ISMS_SSH_PORT   = "22"
#   $env:CATALOG_XML_PATH = "D:\pfad\XML_Kompendium_2023.xml"
#
#   .\scripts\copy-to-linux.ps1 -SkipBuild
#   .\scripts\copy-to-linux.ps1 -IncludeEnv   # kopiert auch lokale .env

[CmdletBinding()]
param(
    [switch] $SkipBuild,
    [switch] $IncludeEnv
)

$ErrorActionPreference = "Stop"

$user = [string]$env:ISMS_USER
$hostName = [string]$env:ISMS_HOST
$remoteDir = [string]$env:ISMS_REMOTE_DIR
$sshPort = [string]$env:ISMS_SSH_PORT

if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($hostName)) {
    throw @"
ISMS_USER und ISMS_HOST müssen gesetzt sein.

  `$env:ISMS_USER = `"ubuntu`"
  `$env:ISMS_HOST = `"mein-linux-host`"
  .\scripts\copy-to-linux.ps1
"@
}

if ([string]::IsNullOrWhiteSpace($remoteDir)) {
    $remoteDir = "isms-server"
}
if ([string]::IsNullOrWhiteSpace($sshPort)) {
    $sshPort = "22"
}

foreach ($cmd in @("ssh", "scp")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd nicht im PATH. OpenSSH-Client unter Windows aktivieren."
    }
}

$repoServerDir = Split-Path -Parent $PSScriptRoot
$linuxBin = Join-Path $repoServerDir "dist\isms-server-linux-amd64"

if (-not $SkipBuild -or -not (Test-Path $linuxBin)) {
    Write-Host "Linux-Binary bauen…"
    & "$PSScriptRoot\build.ps1" -Targets linux
    if ($LASTEXITCODE -ne 0) {
        throw "Linux-Build fehlgeschlagen (Exit $LASTEXITCODE)."
    }
}

if (-not (Test-Path $linuxBin)) {
    throw "Linux-Binary fehlt: $linuxBin"
}

function Find-CatalogXml {
    $candidates = @()
    if ($env:CATALOG_XML_PATH) {
        $candidates += $env:CATALOG_XML_PATH
    }
    $envFile = Join-Path $repoServerDir ".env"
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            if ($line -match '^\s*CATALOG_XML_PATH\s*=\s*(.+)\s*$') {
                $candidates += $Matches[1].Trim().Trim('"').Trim("'")
            }
        }
    }
    $candidates += @(
        (Join-Path $repoServerDir "catalog\XML_Kompendium_2023.xml"),
        (Join-Path (Split-Path $repoServerDir) "xml\XML_Kompendium_2023.xml"),
        (Join-Path $env:USERPROFILE "Documents\XML_Kompendium_2023.xml"),
        (Join-Path $env:USERPROFILE "Dokumente\XML_Kompendium_2023.xml")
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path) -and -not (Get-Item $path).PSIsContainer) {
            return $path
        }
    }
    return $null
}

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("isms-copy-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "migrations") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "deploy") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "catalog") | Out-Null

try {
    Copy-Item $linuxBin (Join-Path $stage "isms-server")
    Copy-Item (Join-Path $repoServerDir "migrations\*.sql") (Join-Path $stage "migrations")
    Copy-Item (Join-Path $repoServerDir ".env.example") (Join-Path $stage ".env.example")
    if ($IncludeEnv -and (Test-Path (Join-Path $repoServerDir ".env"))) {
        Copy-Item (Join-Path $repoServerDir ".env") (Join-Path $stage ".env")
        Write-Host "Lokale .env wird mitkopiert (enthält Secrets)."
    }
    Copy-Item (Join-Path $PSScriptRoot "install-systemd.sh") (Join-Path $stage "scripts")
    Copy-Item (Join-Path $PSScriptRoot "isms-server.service") (Join-Path $stage "scripts")
    Copy-Item (Join-Path $PSScriptRoot "setup-local-db.sql") (Join-Path $stage "scripts")
    Copy-Item (Join-Path $PSScriptRoot "start-linux.sh") (Join-Path $stage "scripts")
    Copy-Item (Join-Path $PSScriptRoot "build-linux.sh") (Join-Path $stage "scripts") -ErrorAction SilentlyContinue

    $deployDir = Join-Path $repoServerDir "deploy"
    if (Test-Path $deployDir) {
        Copy-Item (Join-Path $deployDir "*") (Join-Path $stage "deploy") -ErrorAction SilentlyContinue
    }

    $catalog = Find-CatalogXml
    if ($catalog) {
        Copy-Item $catalog (Join-Path $stage "catalog\XML_Kompendium_2023.xml")
        Write-Host "Katalog: $catalog"
    } else {
        Write-Host "Kein Katalog-XML gefunden — CATALOG_XML_PATH setzen oder Datei nach Documents legen."
    }

    $sshTarget = "${user}@${hostName}"
    $sshArgs = @("-p", $sshPort, "-o", "StrictHostKeyChecking=accept-new")
    $scpArgs = @("-P", $sshPort, "-o", "StrictHostKeyChecking=accept-new")

    Write-Host "Zielverzeichnis anlegen: ${sshTarget}:$remoteDir"
    & ssh @sshArgs $sshTarget "mkdir -p -- '$remoteDir'"
    if ($LASTEXITCODE -ne 0) {
        throw "ssh mkdir fehlgeschlagen (Exit $LASTEXITCODE)."
    }

    Write-Host "Kopiere nach ${sshTarget}:$remoteDir …"
    & scp @scpArgs -r `
        (Join-Path $stage "isms-server"), `
        (Join-Path $stage ".env.example"), `
        (Join-Path $stage "migrations"), `
        (Join-Path $stage "scripts"), `
        (Join-Path $stage "deploy"), `
        (Join-Path $stage "catalog") `
        "${sshTarget}:$remoteDir/"
    if ($LASTEXITCODE -ne 0) {
        throw "scp fehlgeschlagen (Exit $LASTEXITCODE)."
    }

    if ($IncludeEnv -and (Test-Path (Join-Path $stage ".env"))) {
        & scp @scpArgs (Join-Path $stage ".env") "${sshTarget}:$remoteDir/.env"
        if ($LASTEXITCODE -ne 0) {
            throw "scp .env fehlgeschlagen (Exit $LASTEXITCODE)."
        }
    }

    & ssh @sshArgs $sshTarget "chmod +x -- '$remoteDir/isms-server' '$remoteDir/scripts/'*.sh"
    if ($LASTEXITCODE -ne 0) {
        throw "ssh chmod fehlgeschlagen (Exit $LASTEXITCODE)."
    }

    Write-Host ""
    Write-Host "Fertig. Auf dem Zielrechner:"
    Write-Host "  ssh -p $sshPort $sshTarget"
    Write-Host "  cd $remoteDir"
    Write-Host "  chmod +x isms-server scripts/*.sh"
    Write-Host "  cp .env.example .env && nano .env"
    Write-Host "  # optional: sudo -u postgres psql -f scripts/setup-local-db.sql"
    Write-Host "  ./scripts/start-linux.sh"
    Write-Host "  # oder Dienst: sudo ./scripts/install-systemd.sh"
} finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
