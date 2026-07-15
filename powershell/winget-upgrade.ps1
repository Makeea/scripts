# ===============================
# Winget Unattended Upgrade Script
# ===============================

$ErrorActionPreference = "Continue"

$RootDir = $PSScriptRoot
$LogDir  = "$RootDir\logs\winget"
$LogFile = "$LogDir\upgrade-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Update sources silently
winget source update `
    --disable-interactivity `
    | Out-Null

# Run upgrades
winget upgrade --all `
    --include-unknown `
    --silent `
    --force `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity `
    | Tee-Object -FilePath $LogFile

# Detect reboot requirement
$rebootPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
)
if ($rebootPaths | Where-Object { Test-Path $_ }) {
    Add-Content $LogFile "REBOOT REQUIRED"
}
