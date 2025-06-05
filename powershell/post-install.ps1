#=============================================================================
# Windows Post-Installation Setup Script
# Author: SystemAdmin Pro
# Version: 2.1.0
# Last Updated: June 2025
# Purpose: Automated Windows system setup after fresh installation
#
# EXECUTION INSTRUCTIONS:
# 1. Right-click PowerShell and select "Run as Administrator"
# 2. Execute: powershell -ExecutionPolicy Bypass -File .\post-install-setup.ps1
#
# If you encounter execution policy issues:
# - Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# - Or use the bypass method shown above
#
# CHANGELOG:
# v2.1.0 (June 2025) - Expanded menu with individual app installations
# v2.0.0 (June 2025) - Complete rewrite with modular architecture
# v1.5.0 (May 2025) - Added WSL2 and Ubuntu installation
# v1.2.0 (April 2025) - Added Winget detection and fallback methods
# v1.0.0 (March 2025) - Initial release
#=============================================================================

# Check if running as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Global variables
$script:LogPath = "$env:TEMP\PostInstallSetup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:TempPath = "$env:TEMP\PostInstallTemp"
$script:WingetInstalled = $false

# Create temp directory if it doesn't exist
if (!(Test-Path $script:TempPath)) {
    New-Item -ItemType Directory -Path $script:TempPath -Force | Out-Null
}

#=============================================================================
# LOGGING FUNCTIONS
#=============================================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $script:LogPath -Value $logEntry
    
    # Also display to console with color coding
    switch ($Level) {
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "INFO"    { Write-Host $Message -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

function Test-CommandExists {
    param([string]$Command)
    
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-WingetInstalled {
    # Check if winget is available
    if (Test-CommandExists "winget") {
        $script:WingetInstalled = $true
        return $true
    }
    
    Write-Log "Winget not found. Attempting to install App Installer..." "WARNING"
    
    try {
        # Download and install App Installer (includes winget)
        $appInstallerUrl = "https://aka.ms/getwinget"
        $installerPath = "$script:TempPath\AppInstaller.msixbundle"
        
        Write-Log "Downloading App Installer..."
        Invoke-WebRequest -Uri $appInstallerUrl -OutFile $installerPath -UseBasicParsing
        
        Write-Log "Installing App Installer..."
        Add-AppxPackage -Path $installerPath
        
        # Verify installation
        if (Test-CommandExists "winget") {
            $script:WingetInstalled = $true
            Write-Log "Winget installed successfully!" "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Failed to install winget: $_" "ERROR"
    }
    
    return $false
}

function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Test-FeatureInstalled {
    param([string]$FeatureName)
    
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
    return ($feature -and $feature.State -eq "Enabled")
}

#=============================================================================
# SYSTEM FEATURE FUNCTIONS
#=============================================================================

function Enable-WindowsSandbox {
    Write-Log "`n=== Enabling Windows Sandbox ===" "INFO"
    
    if (Test-FeatureInstalled "Containers-DisposableClientVM") {
        Write-Log "Windows Sandbox is already enabled!" "SUCCESS"
        return
    }
    
    try {
        Write-Log "Enabling Windows Sandbox feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart
        Write-Log "Windows Sandbox enabled successfully! A restart is required." "SUCCESS"
    }
    catch {
        Write-Log "Failed to enable Windows Sandbox: $_" "ERROR"
    }
}

function Enable-HyperV {
    Write-Log "`n=== Enabling Hyper-V ===" "INFO"
    
    if (Test-FeatureInstalled "Microsoft-Hyper-V-All") {
        Write-Log "Hyper-V is already enabled!" "SUCCESS"
        return
    }
    
    try {
        Write-Log "Enabling Hyper-V features..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
        Write-Log "Hyper-V enabled successfully! A restart is required." "SUCCESS"
    }
    catch {
        Write-Log "Failed to enable Hyper-V: $_" "ERROR"
    }
}

function Install-WSL2 {
    Write-Log "`n=== Installing WSL2 with Ubuntu ===" "INFO"
    
    try {
        # Check if WSL is already installed
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL is already installed!" "SUCCESS"
            
            # Check if Ubuntu is installed
            $distros = wsl --list --quiet
            if ($distros -match "Ubuntu") {
                Write-Log "Ubuntu is already installed!" "SUCCESS"
                return
            }
        }
        else {
            Write-Log "Installing WSL2..."
            wsl --install --no-launch
            
            # Wait for installation to complete
            Start-Sleep -Seconds 5
        }
        
        # Install Ubuntu
        Write-Log "Installing Ubuntu distribution..."
        wsl --install -d Ubuntu --no-launch
        
        Write-Log "WSL2 with Ubuntu installed successfully!" "SUCCESS"
        Write-Log "You'll need to restart and then launch Ubuntu to complete setup." "INFO"
    }
    catch {
        Write-Log "Failed to install WSL2: $_" "ERROR"
    }
}

#=============================================================================
# BROWSER INSTALLATION FUNCTIONS
#=============================================================================

function Install-ChromeEnterprise {
    Write-Log "`n=== Installing Chrome Enterprise ===" "INFO"
    
    # Check if Chrome is already installed
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    $chromePath86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    
    if ((Test-Path $chromePath) -or (Test-Path $chromePath86)) {
        Write-Log "Google Chrome is already installed!" "SUCCESS"
        return
    }
    
    try {
        # Construct the Chrome Enterprise URL properly to handle the ampersand
        $baseUrl = "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $chromeUrl = $baseUrl + "?standalone=1"
        $chromeMsi = "$script:TempPath\ChromeEnterprise.msi"
        
        Write-Log "Downloading Chrome Enterprise MSI..."
        Show-Progress -Activity "Installing Chrome Enterprise" -Status "Downloading..." -PercentComplete 25
        
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeMsi -UseBasicParsing
        
        Write-Log "Installing Chrome Enterprise..."
        Show-Progress -Activity "Installing Chrome Enterprise" -Status "Installing..." -PercentComplete 75
        
        Start-Process msiexec.exe -ArgumentList "/i", "`"$chromeMsi`"", "/quiet", "/norestart" -Wait
        
        Write-Log "Chrome Enterprise installed successfully!" "SUCCESS"
        Show-Progress -Activity "Installing Chrome Enterprise" -Status "Complete" -PercentComplete 100
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Log "Failed to install Chrome Enterprise: $_" "ERROR"
    }
    finally {
        Write-Progress -Activity "Installing Chrome Enterprise" -Completed
    }
}

function Install-Firefox {
    Write-Log "`n=== Installing Mozilla Firefox ===" "INFO"
    
    # First try with winget if available
    if ($script:WingetInstalled) {
        try {
            $firefoxCheck = winget list --id Mozilla.Firefox --exact 2>$null
            if ($LASTEXITCODE -eq 0 -and $firefoxCheck -match "Mozilla.Firefox") {
                Write-Log "Firefox is already installed! Checking for updates..."
                winget upgrade --id Mozilla.Firefox --exact --silent --accept-package-agreements --accept-source-agreements
                Write-Log "Firefox is up to date!" "SUCCESS"
                return
            }
            
            Write-Log "Installing Firefox via winget..."
            winget install --id Mozilla.Firefox --exact --silent --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Firefox installed successfully via winget!" "SUCCESS"
                return
            }
        }
        catch {
            Write-Log "Winget installation failed, falling back to direct download..." "WARNING"
        }
    }
    
    # Fallback to direct download
    try {
        $firefoxUrl = "https://download.mozilla.org/?product=firefox-latest-ssl" + "&" + "os=win64" + "&" + "lang=en-US"
        $firefoxInstaller = "$script:TempPath\FirefoxSetup.exe"
        
        Write-Log "Downloading Firefox installer..."
        Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxInstaller -UseBasicParsing
        
        Write-Log "Installing Firefox..."
        Start-Process $firefoxInstaller -ArgumentList "/S" -Wait
        
        Write-Log "Firefox installed successfully!" "SUCCESS"
    }
    catch {
        Write-Log "Failed to install Firefox: $_" "ERROR"
    }
}

#=============================================================================
# INDIVIDUAL APPLICATION INSTALLATION FUNCTIONS
#=============================================================================

function Install-SingleApp {
    param(
        [string]$AppName,
        [string]$WingetID,
        [string]$FallbackUrl = "",
        [string]$InstallerArgs = "/S"
    )
    
    Write-Log "`n=== Installing $AppName ===" "INFO"
    
    # First try with winget if available
    if ($script:WingetInstalled) {
        try {
            # Check if already installed
            $appCheck = winget list --id $WingetID --exact 2>$null
            if ($LASTEXITCODE -eq 0 -and $appCheck -match $WingetID) {
                Write-Log "$AppName is already installed! Checking for updates..."
                winget upgrade --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements
                Write-Log "$AppName is up to date!" "SUCCESS"
                return
            }
            
            # Install the app
            Write-Log "Installing $AppName via winget..."
            winget install --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$AppName installed successfully!" "SUCCESS"
                return
            }
        }
        catch {
            Write-Log "Winget installation failed for $AppName" "WARNING"
        }
    }
    
    # Fallback to direct download if URL provided
    if ($FallbackUrl -ne "") {
        try {
            $extension = [System.IO.Path]::GetExtension($FallbackUrl)
            if ($extension -eq "") { $extension = ".exe" }
            $installerPath = "$script:TempPath\$AppName$extension"
            
            Write-Log "Downloading $AppName from official website..."
            Invoke-WebRequest -Uri $FallbackUrl -OutFile $installerPath -UseBasicParsing
            
            Write-Log "Installing $AppName..."
            if ($extension -eq ".msi") {
                Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/quiet", "/norestart" -Wait
            }
            else {
                Start-Process $installerPath -ArgumentList $InstallerArgs -Wait
            }
            
            Write-Log "$AppName installed successfully!" "SUCCESS"
        }
        catch {
            Write-Log "Failed to install $AppName`: $($_)" "ERROR"
        }
    }
    else {
        Write-Log "No fallback URL available for $AppName. Winget is required." "ERROR"
    }
}

# Individual app installation functions
function Install-7Zip { Install-SingleApp -AppName "7-Zip" -WingetID "7zip.7zip" }
function Install-BCUninstaller { Install-SingleApp -AppName "BCUninstaller" -WingetID "Klocman.BulkCrapUninstaller" }
function Install-BulkRenameUtility { Install-SingleApp -AppName "Bulk Rename Utility" -WingetID "TGRMNSoftware.BulkRenameUtility" }
function Install-CPUZ { Install-SingleApp -AppName "CPU-Z" -WingetID "CPUID.CPU-Z" }
function Install-FileConverter { Install-SingleApp -AppName "File Converter" -WingetID "AdrienAllard.FileConverter" }
function Install-Git { Install-SingleApp -AppName "Git" -WingetID "Git.Git" }
function Install-GitExtensions { Install-SingleApp -AppName "Git Extensions" -WingetID "GitExtensionsTeam.GitExtensions" }
function Install-GoogleChrome { Install-SingleApp -AppName "Google Chrome" -WingetID "Google.Chrome" }
function Install-Krita { Install-SingleApp -AppName "Krita" -WingetID "KDE.Krita" }
function Install-LogiOptionsPlus { Install-SingleApp -AppName "Logi Options+" -WingetID "Logitech.OptionsPlus" }
function Install-MozillaFirefox { Install-SingleApp -AppName "Mozilla Firefox" -WingetID "Mozilla.Firefox" }
function Install-NotepadPlusPlus { Install-SingleApp -AppName "Notepad++" -WingetID "Notepad++.Notepad++" }
function Install-OpenSCAD { Install-SingleApp -AppName "OpenSCAD" -WingetID "OpenSCAD.OpenSCAD" }
function Install-VirtualBox { Install-SingleApp -AppName "VirtualBox" -WingetID "Oracle.VirtualBox" }
function Install-PeaZip { Install-SingleApp -AppName "PeaZip" -WingetID "Giorgiotani.Peazip" }
function Install-PrusaSlicer { Install-SingleApp -AppName "PrusaSlicer" -WingetID "Prusa3D.PrusaSlicer" }
function Install-Tabby { Install-SingleApp -AppName "Tabby" -WingetID "Eugeny.Tabby" }

#=============================================================================
# BULK OPERATIONS
#=============================================================================

function Update-AllApps {
    Write-Log "`n=== Updating All Applications via Winget ===" "INFO"
    
    if (!$script:WingetInstalled) {
        Write-Log "Winget is not available. Cannot update apps." "ERROR"
        return
    }
    
    try {
        Write-Log "Checking for application updates..."
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "All applications updated successfully!" "SUCCESS"
        }
        else {
            Write-Log "Some applications may have failed to update. Check the log for details." "WARNING"
        }
    }
    catch {
        Write-Log "Failed to update applications: $_" "ERROR"
    }
}

function Install-Everything {
    Write-Log "`n=== INSTALLING EVERYTHING - ONE-CLICK SETUP ===" "INFO"
    Write-Log "This will install all components. Please be patient..." "INFO"
    
    # Install system features
    Enable-WindowsSandbox
    Enable-HyperV
    Install-WSL2
    
    # Install browsers
    Install-ChromeEnterprise
    Install-Firefox
    
    # Install all essential apps
    Install-7Zip
    Install-BCUninstaller
    Install-BulkRenameUtility
    Install-CPUZ
    Install-FileConverter
    Install-Git
    Install-GitExtensions
    Install-GoogleChrome
    Install-Krita
    Install-LogiOptionsPlus
    Install-MozillaFirefox
    Install-NotepadPlusPlus
    Install-OpenSCAD
    Install-VirtualBox
    Install-PeaZip
    Install-PrusaSlicer
    Install-Tabby
    
    Write-Log "`n=== COMPLETE INSTALLATION FINISHED ===" "SUCCESS"
    Write-Log "Note: A system restart is required to complete the installation of some features." "WARNING"
}

#=============================================================================
# MENU SYSTEM
#=============================================================================

function Show-Menu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    Windows Post-Installation Setup Script    " -ForegroundColor White
    Write-Host "           Author: SystemAdmin Pro            " -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SYSTEM FEATURES:" -ForegroundColor Yellow
    Write-Host " 1.  Enable Windows Sandbox" -ForegroundColor White
    Write-Host " 2.  Enable Hyper-V" -ForegroundColor White
    Write-Host " 3.  Install WSL2 with Ubuntu" -ForegroundColor White
    Write-Host ""
    Write-Host "BROWSERS:" -ForegroundColor Yellow
    Write-Host " 4.  Install Chrome Enterprise" -ForegroundColor White
    Write-Host " 5.  Install Mozilla Firefox" -ForegroundColor White
    Write-Host ""
    Write-Host "ESSENTIAL APPLICATIONS:" -ForegroundColor Yellow
    Write-Host " 6.  Install 7-Zip" -ForegroundColor White
    Write-Host " 7.  Install BCUninstaller" -ForegroundColor White
    Write-Host " 8.  Install Bulk Rename Utility" -ForegroundColor White
    Write-Host " 9.  Install CPU-Z" -ForegroundColor White
    Write-Host " 10. Install File Converter" -ForegroundColor White
    Write-Host " 11. Install Git" -ForegroundColor White
    Write-Host " 12. Install Git Extensions" -ForegroundColor White
    Write-Host " 13. Install Google Chrome" -ForegroundColor White
    Write-Host " 14. Install Krita" -ForegroundColor White
    Write-Host " 15. Install Logi Options+" -ForegroundColor White
    Write-Host " 16. Install Mozilla Firefox" -ForegroundColor White
    Write-Host " 17. Install Notepad++" -ForegroundColor White
    Write-Host " 18. Install OpenSCAD" -ForegroundColor White
    Write-Host " 19. Install VirtualBox" -ForegroundColor White
    Write-Host " 20. Install PeaZip" -ForegroundColor White
    Write-Host " 21. Install PrusaSlicer" -ForegroundColor White
    Write-Host " 22. Install Tabby" -ForegroundColor White
    Write-Host ""
    Write-Host "BULK OPERATIONS:" -ForegroundColor Green
    Write-Host " 23. Update All Apps via Winget" -ForegroundColor White
    Write-Host ""
    Write-Host " 24. INSTALL EVERYTHING (One-Click Setup)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host " 25. Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Log file: $script:LogPath" -ForegroundColor Gray
    Write-Host ""
}

function Start-MainMenu {
    # Initial setup
    Write-Log "Windows Post-Installation Setup Script Started" "INFO"
    Write-Log "Checking for winget..." "INFO"
    Test-WingetInstalled | Out-Null
    
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-25)"
        
        switch ($choice) {
            "1"  { Enable-WindowsSandbox; Pause }
            "2"  { Enable-HyperV; Pause }
            "3"  { Install-WSL2; Pause }
            "4"  { Install-ChromeEnterprise; Pause }
            "5"  { Install-Firefox; Pause }
            "6"  { Install-7Zip; Pause }
            "7"  { Install-BCUninstaller; Pause }
            "8"  { Install-BulkRenameUtility; Pause }
            "9"  { Install-CPUZ; Pause }
            "10" { Install-FileConverter; Pause }
            "11" { Install-Git; Pause }
            "12" { Install-GitExtensions; Pause }
            "13" { Install-GoogleChrome; Pause }
            "14" { Install-Krita; Pause }
            "15" { Install-LogiOptionsPlus; Pause }
            "16" { Install-MozillaFirefox; Pause }
            "17" { Install-NotepadPlusPlus; Pause }
            "18" { Install-OpenSCAD; Pause }
            "19" { Install-VirtualBox; Pause }
            "20" { Install-PeaZip; Pause }
            "21" { Install-PrusaSlicer; Pause }
            "22" { Install-Tabby; Pause }
            "23" { Update-AllApps; Pause }
            "24" { 
                $confirm = Read-Host "This will install everything. Continue? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Install-Everything
                }
                Pause
            }
            "25" { 
                Write-Log "Exiting script..." "INFO"
                break 
            }
            default { 
                Write-Host "Invalid choice. Please select 1-25." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne "25")
}

function Pause {
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

#=============================================================================
# CLEANUP FUNCTION
#=============================================================================

function Cleanup-TempFiles {
    Write-Log "Cleaning up temporary files..." "INFO"
    
    try {
        if (Test-Path $script:TempPath) {
            Remove-Item -Path $script:TempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Temporary files cleaned up successfully." "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to clean up some temporary files: $_" "WARNING"
    }
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

try {
    # Start the main menu
    Start-MainMenu
}
catch {
    Write-Log "An unexpected error occurred: $_" "ERROR"
}
finally {
    # Always cleanup
    Cleanup-TempFiles
    
    Write-Log "Script execution completed." "INFO"
    Write-Host ""
    Write-Host "Script finished. Log saved to: $script:LogPath" -ForegroundColor Green
    Write-Host "Thank you for using the Windows Post-Installation Setup Script!" -ForegroundColor Cyan
    Start-Sleep -Seconds 3
}