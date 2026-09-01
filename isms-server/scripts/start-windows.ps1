# Startet den ISMS-Server unter Windows.
# Nutzt die gebaute Binary in dist/, sonst „go run“.
#
#   .\scripts\start-windows.ps1
#   .\scripts\start-windows.ps1 -Build

[CmdletBinding()]
param(
    [switch] $Build
)

$ErrorActionPreference = "Stop"

$repoServerDir = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $repoServerDir "dist\isms-server-windows-amd64.exe"
$envExample = Join-Path $repoServerDir ".env.example"
$envFile = Join-Path $repoServerDir ".env"

if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        Write-Host ".env aus .env.example angelegt — bei Bedarf anpassen."
    } else {
        throw ".env fehlt und .env.example wurde nicht gefunden."
    }
}

if ($Build) {
    Write-Host "Binary bauen…"
    & "$PSScriptRoot\build-windows.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Build fehlgeschlagen (Exit $LASTEXITCODE)."
    }
}

Push-Location $repoServerDir
try {
    if (Test-Path $exe) {
        Write-Host "Starte $exe"
        & $exe
        exit $LASTEXITCODE
    }

    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        throw "Weder Binary ($exe) noch go im PATH. Zuerst .\scripts\build-windows.ps1 ausführen."
    }

    Write-Host "Starte: go run ./cmd/isms-server"
    go run ./cmd/isms-server
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
