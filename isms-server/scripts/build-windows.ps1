# Baut den ISMS-Server unter Windows (amd64).
#
#   .\scripts\build-windows.ps1
#   .\scripts\build-windows.ps1 -OutDir .\release

[CmdletBinding()]
param(
    [string] $Arch = "amd64",
    [string] $OutDir = ""
)

& "$PSScriptRoot\build.ps1" -Targets windows -Arch $Arch -OutDir $OutDir
exit $LASTEXITCODE
