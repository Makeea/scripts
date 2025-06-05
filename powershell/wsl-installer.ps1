# WSL Management Script for Windows 11 24H2
# Author: Claire Rosario
# Created: June 4, 2025
# Version: 1.3
#
# This script will automatically install/manage Windows Subsystem for Linux (WSL) 
# with your choice of Linux distribution on your Windows 11 computer.
#
# IMPORTANT: You MUST run this script as Administrator!
#
# How to use this script:
# 1. Save this script as wsl-installer.ps1
# 2. Right-click PowerShell and select "Run as Administrator"
# 3. Navigate to the folder where you saved the script
# 4. Use one of these 3 methods to run the script:
#
# Method 1 (Recommended):
# powershell -ExecutionPolicy Bypass -File .\wsl-installer.ps1
#
# Method 2 (Alternative):
# Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
# .\wsl-installer.ps1
#
# Method 3 (Direct Command):
# powershell -Command "& {Set-ExecutionPolicy Bypass -Scope Process; .\wsl-installer.ps1}"
#
# Optional parameters:
# -Force        : Reinstall even if distribution is already installed
# -Distribution : Skip menu and install specific distribution
# -Action       : Specify action (Install, Uninstall, View, RemoveWSL)
#
# Examples:
# powershell -ExecutionPolicy Bypass -File .\wsl-installer.ps1 -Force
# powershell -ExecutionPolicy Bypass -File .\wsl-installer.ps1 -Distribution "Ubuntu-22.04"
# powershell -ExecutionPolicy Bypass -File .\wsl-installer.ps1 -Action "View"
#
# CHANGE LOG
# Version 1.3 - June 4, 2025 - Added WSL management and uninstall features
# - Added main menu with Install/Uninstall/View options
# - Added ability to uninstall individual Linux distributions
# - Added complete WSL removal option to clean system state
# - Shows all installed distributions with detailed status
# - Enhanced user experience with comprehensive WSL management
# - Fixed distribution parsing and added menu loop functionality
#
# Version 1.2 - June 4, 2025 - Added dynamic distribution fetching
# - Script now queries WSL for latest available distributions in real-time
# - Automatically stays up-to-date with Microsoft's official distribution list
# - Keeps hardcoded fallback list in case WSL query fails
# - Improved menu with both technical names and friendly descriptions
#
# Version 1.1 - June 4, 2025 - Added distribution selection menu
# - Added interactive menu to choose from 13 available Linux distributions
# - Default remains Ubuntu LTS (latest) for simplicity
# - Added support for Ubuntu variants, AlmaLinux, Oracle Linux, SUSE, Debian, Kali
# - Updated parameter handling to work with distribution selection
#
# Version 1.0 - June 4, 2025 - Initial script creation

# Script parameters
param(
    [switch]$Force,
    [string]$Distribution = "",
    [string]$Action = ""
)

# Helper Functions

# Check if PowerShell is running with Administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Print colored text to make output easier to read
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if WSL is already working
function Test-WSLInstallation {
    try {
        $wslOutput = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Check if a Linux distribution is installed
function Test-DistributionInstalled {
    param([string]$DistName)
    try {
        $distributions = wsl --list --quiet 2>$null
        if ($distributions -match $DistName) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Check if a Linux distribution is set up and ready to use
function Test-DistributionSetup {
    param([string]$DistName)
    try {
        $result = wsl -d $DistName -e echo "test" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -eq "test") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Get latest available distributions from WSL
function Get-LatestDistributions {
    Write-ColorOutput "Fetching latest distribution list from Microsoft..." "Cyan"
    
    try {
        # Query WSL for the latest available distributions
        $wslOutput = wsl --list --online 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $wslOutput) {
            $distributions = @{}
            $counter = 1
            $foundDistributions = $false
            
            foreach ($line in $wslOutput) {
                # Skip header lines and empty lines
                if ($line -match "^\s*NAME\s+FRIENDLY" -or 
                    $line -match "^The following is a list" -or 
                    $line -match "^Install using" -or 
                    [string]::IsNullOrWhiteSpace($line) -or
                    $line -match "^-+") {
                    continue
                }
                
                # Parse distribution lines (format: NAME    FRIENDLY NAME)
                if ($line -match "^(\S+)\s+(.+)$") {
                    $name = $matches[1].Trim()
                    $friendlyName = $matches[2].Trim()
                    
                    # Prioritize Ubuntu as option 1
                    if ($name -eq "Ubuntu") {
                        $distributions["1"] = @{ 
                            Name = $name
                            FriendlyName = "$friendlyName (Recommended)" 
                        }
                        $foundDistributions = $true
                    } else {
                        # Find next available number (skip 1 if Ubuntu exists)
                        while ($distributions.ContainsKey($counter.ToString())) {
                            $counter++
                        }
                        $distributions[$counter.ToString()] = @{ 
                            Name = $name
                            FriendlyName = $friendlyName 
                        }
                        $counter++
                        $foundDistributions = $true
                    }
                }
            }
            
            if ($foundDistributions) {
                Write-ColorOutput "Successfully fetched $($distributions.Count) distributions" "Green"
                return $distributions
            }
        }
    } catch {
        Write-ColorOutput "Failed to fetch latest distributions: $($_.Exception.Message)" "Yellow"
    }
    
    # Fallback to hardcoded list
    Write-ColorOutput "Using fallback distribution list..." "Yellow"
    return Get-FallbackDistributions
}

# Fallback distribution list (in case WSL query fails)
function Get-FallbackDistributions {
    return @{
        "1" = @{ Name = "Ubuntu"; FriendlyName = "Ubuntu (Latest LTS - Recommended)" }
        "2" = @{ Name = "Ubuntu-24.04"; FriendlyName = "Ubuntu 24.04 LTS" }
        "3" = @{ Name = "Ubuntu-22.04"; FriendlyName = "Ubuntu 22.04 LTS" }
        "4" = @{ Name = "Ubuntu-20.04"; FriendlyName = "Ubuntu 20.04 LTS" }
        "5" = @{ Name = "Debian"; FriendlyName = "Debian GNU/Linux" }
        "6" = @{ Name = "kali-linux"; FriendlyName = "Kali Linux (Security Testing)" }
        "7" = @{ Name = "AlmaLinux-9"; FriendlyName = "AlmaLinux 9 (RHEL Compatible)" }
        "8" = @{ Name = "AlmaLinux-8"; FriendlyName = "AlmaLinux 8" }
        "9" = @{ Name = "openSUSE-Tumbleweed"; FriendlyName = "openSUSE Tumbleweed (Rolling)" }
        "10" = @{ Name = "openSUSE-Leap-15.6"; FriendlyName = "openSUSE Leap 15.6" }
        "11" = @{ Name = "SUSE-Linux-Enterprise-15-SP6"; FriendlyName = "SUSE Linux Enterprise 15 SP6" }
        "12" = @{ Name = "OracleLinux_9_1"; FriendlyName = "Oracle Linux 9.1" }
        "13" = @{ Name = "OracleLinux_8_7"; FriendlyName = "Oracle Linux 8.7" }
    }
}

# Show distribution selection menu
function Show-DistributionMenu {
    Write-ColorOutput ""
    
    # Get the latest distributions (either from WSL or fallback)
    $distributions = Get-LatestDistributions
    
    Write-ColorOutput ""
    Write-ColorOutput "Available Linux Distributions:" "Green"
    Write-ColorOutput "==============================" "Green"
    
    # Sort and display distributions
    $maxChoice = 0
    foreach ($key in ($distributions.Keys | Sort-Object {[int]$_})) {
        $dist = $distributions[$key]
        if ($key -eq "1") {
            Write-ColorOutput "$key. $($dist.FriendlyName) ⭐" "Yellow"
        } else {
            Write-ColorOutput "$key. $($dist.FriendlyName)" "White"
        }
        $maxChoice = [Math]::Max($maxChoice, [int]$key)
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Enter your choice (1-$maxChoice) or press Enter for default [1]: " "Cyan" -NoNewline
    $choice = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "1"
    }
    
    if ($distributions.ContainsKey($choice)) {
        return $distributions[$choice].Name
    } else {
        Write-ColorOutput "Invalid choice. Using default Ubuntu." "Yellow"
        return "Ubuntu"
    }
}

# Get list of installed WSL distributions
function Get-InstalledDistributions {
    try {
        $wslOutput = wsl --list --verbose 2>$null
        $distributions = @{}
        $counter = 1
        
        if ($LASTEXITCODE -eq 0 -and $wslOutput) {
            foreach ($line in $wslOutput) {
                # Skip header lines, empty lines, and dashes
                if ($line -match "^\s*NAME\s+STATE\s+VERSION" -or 
                    [string]::IsNullOrWhiteSpace($line) -or
                    $line -match "^-+" -or
                    $line.Trim() -eq "") {
                    continue
                }
                
                # Clean the line and split by whitespace
                $cleanLine = $line.Trim() -replace '\s+', ' '
                $parts = $cleanLine -split '\s+'
                
                # We need at least 3 parts: [*]Name State [Version]
                if ($parts.Count -ge 2) {
                    $isDefault = $false
                    $nameIndex = 0
                    
                    # Check if first part is the default marker
                    if ($parts[0] -eq "*") {
                        $isDefault = $true
                        $nameIndex = 1
                    }
                    
                    # Make sure we have enough parts after accounting for the asterisk
                    if ($parts.Count -gt $nameIndex + 1) {
                        $name = $parts[$nameIndex]
                        $state = $parts[$nameIndex + 1]
                        $version = if ($parts.Count -gt $nameIndex + 2) { $parts[$nameIndex + 2] } else { "2" }
                        
                        # Only add if name is valid and not empty
                        if (![string]::IsNullOrWhiteSpace($name) -and $name -ne "*" -and $name -ne "NAME") {
                            $distributions[$counter.ToString()] = @{
                                Name = $name
                                State = $state
                                Version = $version
                                IsDefault = $isDefault
                            }
                            $counter++
                        }
                    }
                }
            }
        }
        return $distributions
    } catch {
        Write-ColorOutput "Error parsing WSL distributions: $($_.Exception.Message)" "Red"
        return @{}
    }
}

# Show main action menu
function Show-MainMenu {
    Write-ColorOutput ""
    Write-ColorOutput "WSL Management Options:" "Green"
    Write-ColorOutput "=====================" "Green"
    Write-ColorOutput "1. Install new Linux distribution" "White"
    Write-ColorOutput "2. Uninstall existing distribution" "White"
    Write-ColorOutput "3. View installed distributions" "White"
    Write-ColorOutput "4. Completely remove WSL from system" "Red"
    Write-ColorOutput ""
    Write-ColorOutput "Enter your choice (1-4): " "Cyan" -NoNewline
    $choice = Read-Host
    
    switch ($choice) {
        "1" { return "Install" }
        "2" { return "Uninstall" }
        "3" { return "View" }
        "4" { return "RemoveWSL" }
        default { 
            Write-ColorOutput "Invalid choice. Defaulting to Install." "Yellow"
            return "Install" 
        }
    }
}

# Show installed distributions
function Show-InstalledDistributions {
    $installed = Get-InstalledDistributions
    
    if ($installed.Count -eq 0) {
        Write-ColorOutput "No WSL distributions are currently installed." "Yellow"
        return $null
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Installed WSL Distributions:" "Green"
    Write-ColorOutput "===========================" "Green"
    
    foreach ($key in ($installed.Keys | Sort-Object {[int]$_})) {
        $dist = $installed[$key]
        $defaultMarker = if ($dist.IsDefault) { " (Default)" } else { "" }
        $stateColor = switch ($dist.State) {
            "Running" { "Green" }
            "Stopped" { "Yellow" }
            default { "White" }
        }
        
        Write-ColorOutput "$key. $($dist.Name)$defaultMarker" "White"
        Write-ColorOutput "   State: $($dist.State) | WSL Version: $($dist.Version)" $stateColor
    }
    
    return $installed
}

# Uninstall distribution menu
function Show-UninstallMenu {
    $installed = Show-InstalledDistributions
    
    if ($installed -eq $null -or $installed.Count -eq 0) {
        Write-ColorOutput ""
        Write-ColorOutput "Nothing to uninstall!" "Yellow"
        return $null
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Select distribution to uninstall (1-$($installed.Count)): " "Cyan" -NoNewline
    $choice = Read-Host
    
    if ($installed.ContainsKey($choice)) {
        return $installed[$choice].Name
    } else {
        Write-ColorOutput "Invalid choice." "Red"
        return $null
    }
}

# Uninstall a specific distribution
function Uninstall-Distribution {
    param([string]$DistName)
    
    # Check if DistName is empty
    if ([string]::IsNullOrWhiteSpace($DistName)) {
        Write-ColorOutput "Error: No distribution name provided." "Red"
        return
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "WARNING: This will permanently delete '$DistName' and all its data!" "Red"
    Write-ColorOutput "This action cannot be undone!" "Red"
    Write-ColorOutput ""
    $confirm = Read-Host "Type 'DELETE' to confirm removal of '$DistName'"
    
    if ($confirm -eq "DELETE") {
        Write-ColorOutput "Uninstalling '$DistName'..." "Yellow"
        try {
            $result = wsl --unregister $DistName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "'$DistName' has been successfully removed!" "Green"
            } else {
                Write-ColorOutput "Failed to remove '$DistName'. Error: $result" "Red"
            }
        } catch {
            Write-ColorOutput "Error removing '${DistName}': $($_.Exception.Message)" "Red"
        }
    } else {
        Write-ColorOutput "Uninstall cancelled." "Yellow"
    }
}

# Completely remove WSL from system
function Remove-WSLCompletely {
    Write-ColorOutput ""
    Write-ColorOutput "WARNING: COMPLETE WSL REMOVAL" "Red"
    Write-ColorOutput "=============================" "Red"
    Write-ColorOutput "This will:" "Red"
    Write-ColorOutput "• Remove ALL Linux distributions and their data" "Red"
    Write-ColorOutput "• Disable WSL features" "Red"
    Write-ColorOutput "• Reset system to clean state" "Red"
    Write-ColorOutput "• Require restart" "Red"
    Write-ColorOutput ""
    Write-ColorOutput "THIS ACTION CANNOT BE UNDONE!" "Red"
    Write-ColorOutput ""
    $confirm = Read-Host "Type 'REMOVE WSL COMPLETELY' to confirm"
    
    if ($confirm -eq "REMOVE WSL COMPLETELY") {
        Write-ColorOutput ""
        Write-ColorOutput "Removing all WSL distributions..." "Yellow"
        
        # Get all installed distributions
        $installed = Get-InstalledDistributions
        foreach ($key in $installed.Keys) {
            $distName = $installed[$key].Name
            Write-ColorOutput "Removing $distName..." "Yellow"
            wsl --unregister $distName 2>$null
        }
        
        Write-ColorOutput "Disabling WSL features..." "Yellow"
        try {
            # Disable WSL features
            dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
            dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
            
            Write-ColorOutput "WSL has been completely removed from your system!" "Green"
            Write-ColorOutput "A restart is required to complete the removal." "Yellow"
            
            $restart = Read-Host "Restart now? (y/N)"
            if ($restart -eq 'y' -or $restart -eq 'Y') {
                Write-ColorOutput "Restarting in 5 seconds..." "Yellow"
                Start-Sleep -Seconds 5
                Restart-Computer -Force
            } else {
                Write-ColorOutput "Please restart your computer manually to complete WSL removal." "Red"
            }
        } catch {
            Write-ColorOutput "Error disabling WSL features: $($_.Exception.Message)" "Red"
            Write-ColorOutput "You may need to disable features manually in Windows Features." "Yellow"
        }
    } else {
        Write-ColorOutput "WSL removal cancelled." "Yellow"
    }
}

# Main action handler with menu loop
function Start-WSLManager {
    while ($true) {
        # Select action if not specified
        if ([string]::IsNullOrWhiteSpace($Action)) {
            $Action = Show-MainMenu
        }

        # Handle different actions
        switch ($Action.ToLower()) {
            "view" {
                Show-InstalledDistributions
                Write-ColorOutput ""
                $continue = Read-Host "Press Enter to return to main menu, or 'q' to quit"
                if ($continue.ToLower() -eq 'q') {
                    exit 0
                }
                $Action = ""  # Reset to show menu again
            }
            
            "uninstall" {
                $distToUninstall = Show-UninstallMenu
                if ($distToUninstall) {
                    Uninstall-Distribution -DistName $distToUninstall
                }
                Write-ColorOutput ""
                $continue = Read-Host "Press Enter to return to main menu, or 'q' to quit"
                if ($continue.ToLower() -eq 'q') {
                    exit 0
                }
                $Action = ""  # Reset to show menu again
            }
            
            "removewsl" {
                Remove-WSLCompletely
                exit 0
            }
            
            "install" {
                # Continue with installation process
                return "install"
            }
            
            default {
                Write-ColorOutput "Invalid action. Proceeding with installation..." "Yellow"
                return "install"
            }
        }
    }
}

# Main Script
Clear-Host

Write-ColorOutput "WSL Management Script" "Green"
Write-ColorOutput "For Windows 11 24H2" "Green"
Write-ColorOutput ""

# Check if running as Administrator
Write-ColorOutput "Checking Administrator privileges..." "Cyan"
if (-not (Test-Administrator)) {
    Write-ColorOutput "ERROR: This script must be run as Administrator!" "Red"
    Write-ColorOutput "Right-click on PowerShell and select 'Run as Administrator'" "Yellow"
    Read-Host "Press Enter to exit"
    exit 1
}
Write-ColorOutput "Running as Administrator - Good!" "Green"
Write-ColorOutput ""

# Check Windows version
Write-ColorOutput "Checking Windows version..." "Cyan"
$winVersion = [System.Environment]::OSVersion.Version

if ($winVersion.Major -ge 11) {
    Write-ColorOutput "Windows 11 detected - All versions supported!" "Green"
}
elseif ($winVersion.Major -eq 10 -and $winVersion.Build -ge 19041) {
    Write-ColorOutput "Windows 10 version 2004+ detected - Compatible!" "Green"
}
else {
    Write-ColorOutput "ERROR: Your Windows version is too old for WSL2" "Red"
    Write-ColorOutput "You need Windows 10 version 2004 (Build 19041) or Windows 11" "Yellow"
    Read-Host "Press Enter to exit"
    exit 1
}
Write-ColorOutput ""

# Start the main WSL manager
$actionResult = Start-WSLManager

# If we get here, user chose to install
if ($actionResult -eq "install") {
    Write-ColorOutput "Proceeding with installation..." "Green"
    Write-ColorOutput ""
}

# Select distribution if not specified
if ([string]::IsNullOrWhiteSpace($Distribution)) {
    $Distribution = Show-DistributionMenu
    Write-ColorOutput ""
    Write-ColorOutput "Selected: $Distribution" "Green"
    Write-ColorOutput ""
}

# Check existing installations
Write-ColorOutput "Checking if WSL is already installed..." "Cyan"
$wslInstalled = Test-WSLInstallation

if ($wslInstalled) {
    Write-ColorOutput "WSL is already installed!" "Green"
    
    Write-ColorOutput "Checking if $Distribution is already installed..." "Cyan"
    $distInstalled = Test-DistributionInstalled -DistName $Distribution
    
    if ($distInstalled) {
        Write-ColorOutput "$Distribution is already installed!" "Green"
        
        Write-ColorOutput "Checking if $Distribution is set up..." "Cyan"
        $distSetup = Test-DistributionSetup -DistName $Distribution
        
        if ($distSetup) {
            Write-ColorOutput "$Distribution is fully set up and ready to use!" "Green"
            Write-ColorOutput ""
            Write-ColorOutput "Everything is already working!" "Green"
            Write-ColorOutput ""
            Write-ColorOutput "Current WSL installations:" "Cyan"
            Show-InstalledDistributions
            Write-ColorOutput ""
            
            if (-not $Force) {
                Write-ColorOutput "Nothing to do! Use -Force to reinstall anyway." "Yellow"
                Read-Host "Press Enter to exit"
                exit 0
            } else {
                Write-ColorOutput "Force mode enabled - Will reinstall anyway..." "Yellow"
            }
        } else {
            Write-ColorOutput "$Distribution needs initial setup - continuing..." "Yellow"
        }
    } else {
        Write-ColorOutput "WSL installed but $Distribution is not - will install it..." "Yellow"
    }
} else {
    Write-ColorOutput "WSL not installed - will install WSL and $Distribution..." "Yellow"
}
Write-ColorOutput ""

# Ask user if they want to continue
$continue = Read-Host "Continue with installation? (y/N)"
if ($continue -ne 'y' -and $continue -ne 'Y') {
    Write-ColorOutput "Installation cancelled" "Yellow"
    exit 0
}

# Try automatic installation first
Write-ColorOutput "Starting WSL installation..." "Cyan"
Write-ColorOutput "This may take several minutes..." "Yellow"

try {
    if ($Force) {
        Write-ColorOutput "Removing existing installation first..." "Yellow"
        wsl --unregister $Distribution 2>$null
    }
    
    wsl --install --distribution $Distribution
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Installation completed!" "Green"
        
        Write-ColorOutput "Checking if restart is required..." "Cyan"
        Start-Sleep -Seconds 3
        if (Test-WSLInstallation) {
            Write-ColorOutput "WSL is working - no restart needed!" "Green"
            $restartNeeded = $false
        } else {
            $restartNeeded = $true
        }
        
        if ($restartNeeded) {
            Write-ColorOutput "A restart is required to complete installation" "Yellow"
            $restart = Read-Host "Restart now? (y/N)"
            if ($restart -eq 'y' -or $restart -eq 'Y') {
                Write-ColorOutput "Restarting in 5 seconds..." "Yellow"
                Start-Sleep -Seconds 5
                Restart-Computer -Force
            } else {
                Write-ColorOutput "Please restart your computer manually" "Red"
            }
        }
        $manualInstallNeeded = $false
    } else {
        throw "Installation failed"
    }
} catch {
    Write-ColorOutput "Automatic installation failed, trying manual method..." "Yellow"
    $manualInstallNeeded = $true
}

# Manual installation if automatic failed
if ($manualInstallNeeded) {
    Write-ColorOutput "Performing manual installation..." "Cyan"
    
    Write-ColorOutput "Enabling WSL features..." "Yellow"
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        if ($LASTEXITCODE -ne 0) { throw "Failed to enable WSL" }
        
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        if ($LASTEXITCODE -ne 0) { throw "Failed to enable VM Platform" }
        
        Write-ColorOutput "Features enabled successfully" "Green"
    } catch {
        Write-ColorOutput "Failed to enable features: $($_.Exception.Message)" "Red"
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-ColorOutput "Downloading WSL2 kernel update..." "Yellow"
    $kernelUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    $kernelUpdatePath = "$env:TEMP\wsl_update_x64.msi"
    
    try {
        Invoke-WebRequest -Uri $kernelUpdateUrl -OutFile $kernelUpdatePath -UseBasicParsing
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $kernelUpdatePath, "/quiet" -Wait
        Remove-Item $kernelUpdatePath -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "Kernel update installed" "Green"
    } catch {
        Write-ColorOutput "Kernel update may already be installed" "Yellow"
    }
    
    Write-ColorOutput "Setting WSL2 as default..." "Yellow"
    wsl --set-default-version 2
    
    Write-ColorOutput "Manual installation requires restart" "Yellow"
    Write-ColorOutput "After restart, run: wsl --install -d $Distribution" "Cyan"
    
    $restart = Read-Host "Restart now? (y/N)"
    if ($restart -eq 'y' -or $restart -eq 'Y') {
        Write-ColorOutput "Restarting..." "Yellow"
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    } else {
        Write-ColorOutput "Please restart your computer manually" "Red"
        Read-Host "Press Enter to exit"
        exit 0
    }
}

# Installation Complete
Write-ColorOutput ""
Write-ColorOutput "Installation Complete!" "Green"
Write-ColorOutput ""

# Show current status
Write-ColorOutput "Current WSL installations:" "Cyan"
Show-InstalledDistributions

Write-ColorOutput ""
Write-ColorOutput "Next steps:" "Green"
Write-ColorOutput "1. Open $Distribution from Start menu or type the distribution name in terminal" "White"
Write-ColorOutput "2. Create username and password when prompted" "White"
Write-ColorOutput "3. Update system: sudo apt update && sudo apt upgrade" "White"
Write-ColorOutput ""

Write-ColorOutput "Useful commands:" "Green"
Write-ColorOutput "wsl --list --verbose    (show installed distributions)" "White"
Write-ColorOutput "wsl --shutdown         (stop all WSL instances)" "White"
Write-ColorOutput "wsl -d $Distribution   (start $Distribution)" "White"
Write-ColorOutput ""

Write-ColorOutput "Installation completed successfully!" "Green"
Read-Host "Press Enter to exit"