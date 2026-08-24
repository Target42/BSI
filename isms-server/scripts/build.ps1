# Baut den ISMS-Go-Server für Linux und/oder Windows (amd64).
# Cross-Compile ohne CGO — von Windows oder Linux aus nutzbar.
#
# Beispiele:
#   .\scripts\build.ps1
#   .\scripts\build.ps1 -Targets windows
#   .\scripts\build.ps1 -Targets linux,windows -OutDir .\release

[CmdletBinding()]
param(
    [string[]] $Targets = @("linux", "windows"),
    [string] $Arch = "amd64",
    [string] $OutDir = ""
)

$ErrorActionPreference = "Stop"

$repoServerDir = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) {
    $OutDir = Join-Path $repoServerDir "dist"
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw "go nicht im PATH. Go 1.22+ installieren und Terminal neu öffnen."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Push-Location $repoServerDir
try {
    $env:CGO_ENABLED = "0"
    $failed = $false

    foreach ($os in $Targets) {
        $os = $os.Trim().ToLowerInvariant()
        if ($os -notin @("linux", "windows")) {
            Write-Error "Unbekanntes Target: $os (erlaubt: linux, windows)"
            $failed = $true
            continue
        }

        $name = if ($os -eq "windows") {
            "isms-server-windows-$Arch.exe"
        } else {
            "isms-server-linux-$Arch"
        }
        $out = Join-Path $OutDir $name

        Write-Host "Bauen: GOOS=$os GOARCH=$Arch -> $out"
        $env:GOOS = $os
        $env:GOARCH = $Arch
        go build -trimpath -ldflags="-s -w" -o $out ./cmd/isms-server
        if ($LASTEXITCODE -ne 0) {
            Write-Error "go build fehlgeschlagen für $os/$Arch (Exit $LASTEXITCODE)."
            $failed = $true
        }
    }

    if ($failed) {
        throw "Mindestens ein Build ist fehlgeschlagen."
    }

    Write-Host ""
    Write-Host "Fertig. Ausgaben in $OutDir :"
    Get-ChildItem $OutDir -Filter "isms-server-*" | ForEach-Object {
        Write-Host ("  {0}  ({1:N0} bytes)" -f $_.Name, $_.Length)
    }
} finally {
    Remove-Item Env:GOOS -ErrorAction SilentlyContinue
    Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
    Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
    Pop-Location
}
