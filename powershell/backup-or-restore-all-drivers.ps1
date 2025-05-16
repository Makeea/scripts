# ============================
# Self-elevating driver backup/restore script (optional ZIP)
# ============================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "This script needs Administrator privileges. Relaunching..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Set paths
$date = Get-Date -Format "yyyy-MM-dd"
$desktop = [Environment]::GetFolderPath("Desktop")
$backupFolder = "$desktop\DriverBackup-$date"
$zipFile = "$desktop\DriverBackup-$date.zip"

# Menu
Write-Host "`n=== DRIVER BACKUP TOOL ==="
Write-Host "1. Backup ALL installed drivers"
Write-Host "2. Restore drivers from folder or ZIP"
$choice = Read-Host "Choose an option (1 or 2)"

# ============================
# BACKUP MODE
# ============================
if ($choice -eq "1") {
    Write-Host "`n[!] Backing up ALL installed drivers..."

    New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null

    try {
        Export-WindowsDriver -Online -Destination $backupFolder -ErrorAction Stop
        Write-Host "`n✔ Drivers exported to: $backupFolder"
    } catch {
        Write-Warning "❌ Failed to export drivers: $_"
        exit
    }

    # Ask user if they want to compress the folder
    $zipChoice = Read-Host "Do you want to compress the backup into a .zip file? (y/N)"

    if ($zipChoice -match '^(y|Y)$') {
        try {
            Write-Host "Compressing to ZIP..."
            Compress-Archive -Path "$backupFolder\*" -DestinationPath $zipFile -Force
            Write-Host "✔ ZIP created at: $zipFile"
        } catch {
            Write-Warning "❌ Failed to zip drivers: $_"
        }
    } else {
        Write-Host "Skipping ZIP compression (you can zip it later manually)."
    }

    Write-Host "`n✅ Backup complete!"
}

# ============================
# RESTORE MODE
# ============================
elseif ($choice -eq "2") {
    $restoreSource = Read-Host "Enter full path to folder OR .zip file to restore from"

    if (-not (Test-Path $restoreSource)) {
        Write-Warning "Path does not exist. Please check and try again."
        exit
    }

    $workingPath = ""

    if ($restoreSource -like "*.zip") {
        $tempPath = Join-Path $env:TEMP "DriverRestore-$date"
        Write-Host "Extracting ZIP to temp folder: $tempPath"
        Expand-Archive -Path $restoreSource -DestinationPath $tempPath -Force
        $workingPath = $tempPath
    } else {
        $workingPath = $restoreSource
    }

    $driverFiles = Get-ChildItem -Path $workingPath -Recurse -Include *.inf
    if ($driverFiles.Count -eq 0) {
        Write-Warning "No .inf driver files found. Aborting restore."
        exit
    }

    foreach ($file in $driverFiles) {
        Write-Host "Installing: $($file.FullName)"
        try {
            pnputil /add-driver "$($file.FullName)" /install
        } catch {
            Write-Warning "❌ Failed to install: $($file.FullName)"
        }
    }

    Write-Host "`n✅ Restore complete!"
}

# ============================
# INVALID OPTION
# ============================
else {
    Write-Warning "Invalid option. Please run the script again and choose 1 or 2."
}
