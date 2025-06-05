# ============================================================================
# System Post-Install Configuration Script
# Author: Claire Rosario
# Description: Automated installation and configuration script for fresh Windows systems
# 
# Change Log:
# ----------
# v1.0 - 2025-06-04 - Initial release with core functionality
#                   - Added Chrome Enterprise, Firefox, and Notepad++ installation
#                   - Implemented Windows Sandbox and Hyper-V setup
#                   - Added WSL2 with Ubuntu installation
#                   - Created modular menu system for selective installation
#
# v1.1 - 2025-06-04 - Enhanced error handling and user feedback
#                   - Added update detection for existing applications
#                   - Improved logging and progress indicators
# ============================================================================

# Ensure script runs with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Set execution policy for this session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Global variables for better organization
$logFile = "$env:TEMP\PostInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$downloadPath = "$env:TEMP\PostInstallDownloads"

# Create download directory if it doesn't exist
if (!(Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
}

# Logging function to keep track of what we're doing
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

# Function to check if an application is installed
function Test-ApplicationInstalled {
    param([string]$AppName)
    
    $installed = $false
    
    # Check in registry for installed programs
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue
        if ($apps | Where-Object { $_.DisplayName -like "*$AppName*" }) {
            $installed = $true
            break
        }
    }
    
    return $installed
}

# Function to download files with progress indicator
function Get-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-LogMessage "Downloading from: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        return $true
    }
    catch {
        Write-LogMessage "Download failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Chrome Enterprise installation function
function Install-ChromeEnterprise {
    Write-LogMessage "Starting Chrome Enterprise installation process..."
    
    if (Test-ApplicationInstalled "Google Chrome") {
        Write-Host "Chrome is already installed. Checking for updates..." -ForegroundColor Yellow
        # Chrome auto-updates, but we can trigger a check
        Start-Process "chrome.exe" -ArgumentList "--check-for-update-interval=1" -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-LogMessage "Chrome update check initiated"
        return
    }
    
    $chromeUrl = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"
    $chromeInstaller = "$downloadPath\chrome_enterprise.msi"
    
    if (Get-FileWithProgress -Url $chromeUrl -OutputPath $chromeInstaller) {
        Write-LogMessage "Installing Chrome Enterprise..."
        Start-Process msiexec.exe -ArgumentList "/i `"$chromeInstaller`" /quiet /norestart" -Wait
        Write-LogMessage "Chrome Enterprise installation completed"
    }
}

# Firefox installation function
function Install-Firefox {
    Write-LogMessage "Starting Firefox installation process..."
    
    if (Test-ApplicationInstalled "Firefox") {
        Write-Host "Firefox is already installed. It will auto-update on next launch." -ForegroundColor Yellow
        Write-LogMessage "Firefox already present - skipping installation"
        return
    }
    
    $firefoxUrl = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
    $firefoxInstaller = "$downloadPath\firefox_installer.exe"
    
    if (Get-FileWithProgress -Url $firefoxUrl -OutputPath $firefoxInstaller) {
        Write-LogMessage "Installing Firefox..."
        Start-Process $firefoxInstaller -ArgumentList "/S" -Wait
        Write-LogMessage "Firefox installation completed"
    }
}

# Notepad++ installation function
function Install-NotepadPlusPlus {
    Write-LogMessage "Starting Notepad++ installation process..."
    
    if (Test-ApplicationInstalled "Notepad++") {
        Write-Host "Notepad++ is already installed. You can check for updates from Help menu." -ForegroundColor Yellow
        Write-LogMessage "Notepad++ already present - skipping installation"
        return
    }
    
    # Using a stable download link for Notepad++
    $notepadUrl = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/latest/download/npp.Installer.x64.exe"
    $notepadInstaller = "$downloadPath\notepad_installer.exe"
    
    if (Get-FileWithProgress -Url $notepadUrl -OutputPath $notepadInstaller) {
        Write-LogMessage "Installing Notepad++..."
        Start-Process $notepadInstaller -ArgumentList "/S" -Wait
        Write-LogMessage "Notepad++ installation completed"
    }
}

# Windows Sandbox setup function
function Enable-WindowsSandbox {
    Write-LogMessage "Configuring Windows Sandbox..."
    
    # Check if Sandbox is already enabled
    $sandboxFeature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM"
    
    if ($sandboxFeature.State -eq "Enabled") {
        Write-Host "Windows Sandbox is already enabled." -ForegroundColor Green
        Write-LogMessage "Windows Sandbox already enabled"
        return
    }
    
    try {
        Write-LogMessage "Enabling Windows Sandbox feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart
        Write-LogMessage "Windows Sandbox enabled successfully"
        Write-Host "Windows Sandbox has been enabled. A restart may be required." -ForegroundColor Green
    }
    catch {
        Write-LogMessage "Failed to enable Windows Sandbox: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Hyper-V setup function
function Enable-HyperV {
    Write-LogMessage "Configuring Hyper-V..."
    
    # Check if Hyper-V is already enabled
    $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All"
    
    if ($hyperVFeature.State -eq "Enabled") {
        Write-Host "Hyper-V is already enabled." -ForegroundColor Green
        Write-LogMessage "Hyper-V already enabled"
        return
    }
    
    try {
        Write-LogMessage "Enabling Hyper-V features..."
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -All -NoRestart
        Write-LogMessage "Hyper-V enabled successfully"
        Write-Host "Hyper-V has been enabled. A restart will be required." -ForegroundColor Green
    }
    catch {
        Write-LogMessage "Failed to enable Hyper-V: $($_.Exception.Message)" -Level "ERROR"
    }
}

# WSL2 with Ubuntu installation function
function Install-WSL2Ubuntu {
    Write-LogMessage "Setting up WSL2 with Ubuntu..."
    
    # Check if WSL is already installed
    $wslCheck = wsl --list --verbose 2>$null
    if ($wslCheck -match "Ubuntu") {
        Write-Host "Ubuntu on WSL2 is already installed." -ForegroundColor Green
        Write-LogMessage "WSL2 Ubuntu already present"
        # Update existing installation
        Write-LogMessage "Updating existing Ubuntu installation..."
        wsl --update
        return
    }
    
    try {
        # Enable WSL feature
        Write-LogMessage "Enabling WSL feature..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        
        # Enable Virtual Machine Platform
        Write-LogMessage "Enabling Virtual Machine Platform..."
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        
        # Set WSL 2 as default version
        Write-LogMessage "Setting WSL2 as default version..."
        wsl --set-default-version 2
        
        # Install Ubuntu from Microsoft Store
        Write-LogMessage "Installing Ubuntu from Microsoft Store..."
        winget install Canonical.Ubuntu
        
        Write-LogMessage "WSL2 with Ubuntu installation completed"
        Write-Host "WSL2 with Ubuntu has been installed. Please restart your computer to complete the setup." -ForegroundColor Green
    }
    catch {
        Write-LogMessage "Failed to install WSL2: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Function to install everything at once
function Install-Everything {
    Write-Host "`n=== Installing All Applications and Features ===" -ForegroundColor Cyan
    Write-LogMessage "Starting complete system setup..."
    
    Install-ChromeEnterprise
    Install-Firefox  
    Install-NotepadPlusPlus
    Enable-WindowsSandbox
    Enable-HyperV
    Install-WSL2Ubuntu
    
    Write-Host "`nAll installations completed! Check the log file for details: $logFile" -ForegroundColor Green
    Write-LogMessage "Complete system setup finished"
}

# Main menu function
function Show-MainMenu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   System Post-Install Configuration       " -ForegroundColor Cyan  
    Write-Host "   Author: Claire Rosario                  " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please select an option:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Install Chrome Enterprise" -ForegroundColor White
    Write-Host "2. Install Firefox" -ForegroundColor White
    Write-Host "3. Install Notepad++" -ForegroundColor White
    Write-Host "4. Enable Windows Sandbox" -ForegroundColor White
    Write-Host "5. Enable Hyper-V" -ForegroundColor White
    Write-Host "6. Install WSL2 with Ubuntu" -ForegroundColor White
    Write-Host "7. Install Everything" -ForegroundColor Green
    Write-Host "8. Exit" -ForegroundColor Red
    Write-Host ""
}

# Main script execution
Write-LogMessage "Post-install script started by Claire Rosario"
Write-Host "Welcome to the System Configuration Script!" -ForegroundColor Green
Write-Host "Log file location: $logFile" -ForegroundColor Gray
Write-Host ""

# Main menu loop
do {
    Show-MainMenu
    $choice = Read-Host "Enter your choice (1-8)"
    
    switch ($choice) {
        "1" { Install-ChromeEnterprise; Read-Host "Press Enter to continue" }
        "2" { Install-Firefox; Read-Host "Press Enter to continue" }
        "3" { Install-NotepadPlusPlus; Read-Host "Press Enter to continue" }
        "4" { Enable-WindowsSandbox; Read-Host "Press Enter to continue" }
        "5" { Enable-HyperV; Read-Host "Press Enter to continue" }
        "6" { Install-WSL2Ubuntu; Read-Host "Press Enter to continue" }
        "7" { Install-Everything; Read-Host "Press Enter to continue" }
        "8" { 
            Write-Host "Thanks for using the post-install script! Have a great day!" -ForegroundColor Green
            Write-LogMessage "Script ended by user choice"
            break 
        }
        default { 
            Write-Host "Invalid choice. Please enter a number between 1 and 8." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne "8")

# Cleanup downloaded files
Write-LogMessage "Cleaning up temporary files..."
if (Test-Path $downloadPath) {
    Remove-Item $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-LogMessage "Script execution completed successfully"
Write-Host "`nScript completed! Log saved to: $logFile" -ForegroundColor Green