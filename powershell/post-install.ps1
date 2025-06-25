#=============================================================================
# Windows Post-Installation Setup Script
# Author: Claire R
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
# DEVELOPER SETUP FUNCTIONS
#=============================================================================

function Setup-SSHKeyAndGit {
    Write-Log "`n=== Setting up SSH Key + Git Configuration ===" "INFO"
    
    try {
        # Get computer name for SSH key comment
        $computerName = $env:COMPUTERNAME
        $sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
        $sshKeyPubPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
        
        # Create .ssh directory if it doesn't exist
        $sshDir = "$env:USERPROFILE\.ssh"
        if (!(Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            Write-Log "Created .ssh directory" "INFO"
        }
        
        # Check if SSH key already exists
        if (Test-Path $sshKeyPath) {
            Write-Log "BEFORE: SSH key already exists at $sshKeyPath" "WARNING"
            Write-Host ""
            Write-Host "An SSH key already exists!" -ForegroundColor Yellow
            Write-Host "1. Create new key (backup existing)" -ForegroundColor White
            Write-Host "2. Replace existing key" -ForegroundColor White
            Write-Host "3. Skip SSH key creation" -ForegroundColor White
            $choice = Read-Host "Choose option (1-3)"
            
            switch ($choice) {
                "1" {
                    # Backup existing key
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    Copy-Item $sshKeyPath "$sshKeyPath.backup_$timestamp" -Force
                    Copy-Item $sshKeyPubPath "$sshKeyPubPath.backup_$timestamp" -Force
                    Write-Log "Backed up existing SSH key with timestamp" "SUCCESS"
                }
                "2" {
                    Write-Log "Will replace existing SSH key" "INFO"
                }
                "3" {
                    Write-Log "Skipping SSH key creation, proceeding to Git setup..." "INFO"
                    Setup-GitConfiguration
                    return
                }
                default {
                    Write-Log "Invalid choice, skipping SSH key setup" "ERROR"
                    return
                }
            }
        } else {
            Write-Log "BEFORE: No SSH key found, will create new one" "INFO"
        }
        
        # Generate SSH key with computer name as comment
        Write-Log "Generating ed25519 SSH key..."
        $keyComment = "$computerName@$computerName"
        
        # Use ssh-keygen to generate the key
        $sshKeygenArgs = @(
            "-t", "ed25519"
            "-f", $sshKeyPath
            "-C", $keyComment
            "-N", '""'  # Empty passphrase
        )
        
        Start-Process "ssh-keygen" -ArgumentList $sshKeygenArgs -Wait -WindowStyle Hidden
        
        if (Test-Path $sshKeyPath -and Test-Path $sshKeyPubPath) {
            Write-Log "AFTER: SSH key generated successfully!" "SUCCESS"
            Write-Log "Private key: $sshKeyPath" "INFO"
            Write-Log "Public key: $sshKeyPubPath" "INFO"
            
            # Display the public key
            $publicKey = Get-Content $sshKeyPubPath
            Write-Log "`nYour SSH Public Key:" "INFO"
            Write-Host $publicKey -ForegroundColor Green
            Write-Host "`nCopy this key to your Git hosting service (GitHub, GitLab, etc.)" -ForegroundColor Yellow
        } else {
            Write-Log "Failed to generate SSH key" "ERROR"
            return
        }
        
        # Start SSH agent and add key
        Write-Log "Starting SSH agent and adding key..."
        Start-Service ssh-agent -ErrorAction SilentlyContinue
        ssh-add $sshKeyPath 2>$null
        
        Write-Log "SSH key setup completed successfully!" "SUCCESS"
        
        # Now configure Git
        Setup-GitConfiguration
        
    }
    catch {
        Write-Log "Failed to setup SSH key: $($_)" "ERROR"
    }
}

function Setup-GitConfiguration {
    Write-Log "`n=== Configuring Git ===" "INFO"
    
    try {
        # Check if git is installed
        if (!(Test-CommandExists "git")) {
            Write-Log "Git is not installed! Please install Git first (option 14)." "ERROR"
            return
        }
        
        # Get current git configuration
        $currentName = git config --global user.name 2>$null
        $currentEmail = git config --global user.email 2>$null
        
        if ($currentName) {
            Write-Log "BEFORE: Git user.name = '$currentName'" "INFO"
        } else {
            Write-Log "BEFORE: Git user.name not set" "INFO"
        }
        
        if ($currentEmail) {
            Write-Log "BEFORE: Git user.email = '$currentEmail'" "INFO"
        } else {
            Write-Log "BEFORE: Git user.email not set" "INFO"
        }
        
        # Get user input for Git configuration
        Write-Host "`nGit Configuration Setup:" -ForegroundColor Cyan
        
        if ($currentName) {
            $newName = Read-Host "Git user name (current: $currentName, press Enter to keep)"
            if ([string]::IsNullOrWhiteSpace($newName)) {
                $newName = $currentName
            }
        } else {
            $newName = Read-Host "Enter your Git user name"
        }
        
        if ($currentEmail) {
            $newEmail = Read-Host "Git user email (current: $currentEmail, press Enter to keep)"
            if ([string]::IsNullOrWhiteSpace($newEmail)) {
                $newEmail = $currentEmail
            }
        } else {
            $newEmail = Read-Host "Enter your Git user email"
        }
        
        # Configure Git with best practices
        Write-Log "Applying Git configuration and best practices..."
        
        # Basic user configuration
        git config --global user.name "$newName"
        git config --global user.email "$newEmail"
        
        # Best practices configuration
        git config --global init.defaultBranch main
        git config --global pull.rebase true
        git config --global push.default simple
        git config --global core.autocrlf true  # Windows line endings
        git config --global core.editor "notepad"
        git config --global credential.helper manager-core
        git config --global fetch.prune true
        git config --global rebase.autoStash true
        
        # Useful aliases
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.unstage "reset HEAD --"
        git config --global alias.last "log -1 HEAD"
        git config --global alias.visual "!gitk"
        git config --global alias.lg "log --oneline --decorate --graph --all"
        
        # Safety configurations
        git config --global safe.directory "*"
        
        Write-Log "AFTER: Git user.name = '$newName'" "SUCCESS"
        Write-Log "AFTER: Git user.email = '$newEmail'" "SUCCESS"
        Write-Log "Applied Git best practices:" "SUCCESS"
        Write-Log "- Default branch: main" "INFO"
        Write-Log "- Pull strategy: rebase" "INFO"
        Write-Log "- Line endings: Windows (CRLF)" "INFO"
        Write-Log "- Credential helper: manager-core" "INFO"
        Write-Log "- Added useful aliases (st, co, br, ci, lg, etc.)" "INFO"
        Write-Log "- Enabled auto-stash and prune" "INFO"
        
        Write-Log "Git configuration completed successfully!" "SUCCESS"
        
    }
    catch {
        Write-Log "Failed to configure Git: $($_)" "ERROR"
    }
}

function Setup-GitOnly {
    Write-Log "`n=== Setting up Git Configuration Only ===" "INFO"
    Setup-GitConfiguration
}

function Set-ComputerHostname {
    Write-Log "`n=== Setting Computer Hostname ===" "INFO"
    
    try {
        # Get current computer name
        $currentName = $env:COMPUTERNAME
        Write-Log "BEFORE: Current computer name is '$currentName'" "INFO"
        
        Write-Host "`nComputer Hostname Setup:" -ForegroundColor Cyan
        Write-Host "Current computer name: $currentName" -ForegroundColor Yellow
        $newName = Read-Host "Enter new computer name (or press Enter to cancel)"
        
        if ([string]::IsNullOrWhiteSpace($newName)) {
            Write-Log "Computer name change cancelled" "INFO"
            return
        }
        
        # Validate computer name (basic validation)
        if ($newName.Length -gt 15) {
            Write-Log "Computer name must be 15 characters or less" "ERROR"
            return
        }
        
        if ($newName -match '[^a-zA-Z0-9\-]') {
            Write-Log "Computer name can only contain letters, numbers, and hyphens" "ERROR"
            return
        }
        
        if ($newName -eq $currentName) {
            Write-Log "New name is the same as current name" "INFO"
            return
        }
        
        Write-Log "Changing computer name to '$newName'..."
        
        # Use Rename-Computer cmdlet
        Rename-Computer -NewName $newName -Force
        
        Write-Log "AFTER: Computer name changed to '$newName'" "SUCCESS"
        Write-Log "A system restart is REQUIRED for the name change to take effect!" "WARNING"
        
        $restart = Read-Host "Would you like to restart now? (Y/N)"
        if ($restart -eq "Y" -or $restart -eq "y") {
            Write-Log "Restarting computer in 10 seconds..." "WARNING"
            Write-Host "Restarting in 10 seconds... Press Ctrl+C to cancel" -ForegroundColor Red
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            Write-Log "Please restart your computer manually to complete the hostname change" "INFO"
        }
        
    }
    catch {
        Write-Log "Failed to change computer hostname: $($_)" "ERROR"
    }
}

#=============================================================================
# WINDOWS CUSTOMIZATION FUNCTIONS
#=============================================================================

function Enable-ClassicRightClick {
    Write-Log "`n=== Enabling Classic Right-Click Menu ===" "INFO"
    
    try {
        # Check current state
        $currentValue = Get-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -ErrorAction SilentlyContinue
        
        if ($currentValue) {
            Write-Log "Classic right-click menu is already enabled!" "SUCCESS"
            return
        }
        
        Write-Log "Configuring registry for classic context menu..."
        
        # Create the registry path if it doesn't exist
        $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        
        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        # Set the default value to empty string to enable classic menu
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value "" -Force
        
        Write-Log "Classic right-click menu enabled successfully!" "SUCCESS"
        Write-Log "You need to restart Explorer or log off/on for changes to take effect." "INFO"
        
        # Offer to restart Explorer
        $restart = Read-Host "Would you like to restart Explorer now? (Y/N)"
        if ($restart -eq "Y" -or $restart -eq "y") {
            Write-Log "Restarting Explorer..."
            Stop-Process -Name explorer -Force
            Start-Sleep -Seconds 2
            Start-Process explorer
            Write-Log "Explorer restarted successfully!" "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to enable classic right-click menu: $($_)" "ERROR"
    }
}

function Enable-TaskbarEndTask {
    Write-Log "`n=== Enabling End Task in Taskbar Right-Click ===" "INFO"
    
    try {
        # Registry path for the End Task feature
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
        
        # Check if already enabled
        $currentValue = Get-ItemProperty -Path $regPath -Name "TaskbarEndTask" -ErrorAction SilentlyContinue
        
        if ($currentValue -and $currentValue.TaskbarEndTask -eq 1) {
            Write-Log "End Task in taskbar is already enabled!" "SUCCESS"
            return
        }
        
        Write-Log "Configuring registry for End Task in taskbar..."
        
        # Create the registry path if it doesn't exist
        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        # Enable End Task in taskbar (DWORD value = 1)
        Set-ItemProperty -Path $regPath -Name "TaskbarEndTask" -Value 1 -Type DWord -Force
        
        Write-Log "End Task in taskbar enabled successfully!" "SUCCESS"
        Write-Log "You need to restart Explorer or log off/on for changes to take effect." "INFO"
        
        # Offer to restart Explorer
        $restart = Read-Host "Would you like to restart Explorer now? (Y/N)"
        if ($restart -eq "Y" -or $restart -eq "y") {
            Write-Log "Restarting Explorer..."
            Stop-Process -Name explorer -Force
            Start-Sleep -Seconds 2
            Start-Process explorer
            Write-Log "Explorer restarted successfully!" "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to enable End Task in taskbar: $($_)" "ERROR"
    }
}

function Disable-FastBoot {
    Write-Log "`n=== Disabling Fast Boot ===" "INFO"
    
    try {
        # Registry path for Fast Boot setting
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        $regName = "HiberbootEnabled"
        
        # Check current state before making changes
        $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        if ($currentValue) {
            if ($currentValue.HiberbootEnabled -eq 0) {
                Write-Log "BEFORE: Fast Boot is already disabled" "INFO"
                Write-Log "Fast Boot is already disabled!" "SUCCESS"
                return
            } else {
                Write-Log "BEFORE: Fast Boot is currently enabled (value: $($currentValue.HiberbootEnabled))" "INFO"
            }
        } else {
            Write-Log "BEFORE: Fast Boot registry value not found (default enabled)" "INFO"
        }
        
        Write-Log "Disabling Fast Boot..."
        
        # Set HiberbootEnabled to 0 to disable Fast Boot
        Set-ItemProperty -Path $regPath -Name $regName -Value 0 -Type DWord -Force
        
        # Verify the change
        $newValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        if ($newValue -and $newValue.HiberbootEnabled -eq 0) {
            Write-Log "AFTER: Fast Boot is now disabled (value: $($newValue.HiberbootEnabled))" "SUCCESS"
            Write-Log "Fast Boot disabled successfully!" "SUCCESS"
            Write-Log "A system restart is required for changes to take effect." "WARNING"
        } else {
            Write-Log "Failed to verify Fast Boot disable setting" "ERROR"
        }
    }
    catch {
        Write-Log "Failed to disable Fast Boot: $($_)" "ERROR"
    }
}

function Disable-ClassicRightClick {
    Write-Log "`n=== Restoring Windows 11 Right-Click Menu ===" "INFO"
    
    try {
        $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force
            Write-Log "Windows 11 right-click menu restored successfully!" "SUCCESS"
            Write-Log "You need to restart Explorer or log off/on for changes to take effect." "INFO"
            
            # Offer to restart Explorer
            $restart = Read-Host "Would you like to restart Explorer now? (Y/N)"
            if ($restart -eq "Y" -or $restart -eq "y") {
                Write-Log "Restarting Explorer..."
                Stop-Process -Name explorer -Force
                Start-Sleep -Seconds 2
                Start-Process explorer
                Write-Log "Explorer restarted successfully!" "SUCCESS"
            }
        }
        else {
            Write-Log "Windows 11 right-click menu is already active!" "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to restore Windows 11 right-click menu: $($_)" "ERROR"
    }
}

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

function Install-AllApplications {
    Write-Log "`n=== INSTALLING ALL APPLICATIONS ONLY ===" "INFO"
    Write-Log "This will install browsers and essential applications only (no system features or customizations)..." "INFO"
    
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
    
    Write-Log "`n=== ALL APPLICATIONS INSTALLATION FINISHED ===" "SUCCESS"
}

function Install-Everything {
    Write-Log "`n=== INSTALLING EVERYTHING - ONE-CLICK SETUP ===" "INFO"
    Write-Log "This will install all components. Please be patient..." "INFO"
    
    # Install system features
    Enable-WindowsSandbox
    Enable-HyperV
    Install-WSL2
    
    # Windows customizations
    Enable-ClassicRightClick
    Enable-TaskbarEndTask
    Disable-FastBoot
    
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
    
    # Developer setup (Git configuration only, user can manually setup SSH if needed)
    Write-Log "`n=== Setting up Git Configuration ===" "INFO"
    Setup-GitConfiguration
    
    Write-Log "`n=== COMPLETE INSTALLATION FINISHED ===" "SUCCESS"
    Write-Log "Note: A system restart is required to complete the installation of some features." "WARNING"
    Write-Log "Reminder: You can use option 26 to setup SSH keys for Git if needed." "INFO"
}

#=============================================================================
# MENU SYSTEM
#=============================================================================

function Show-Menu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    Windows Post-Installation Setup Script    " -ForegroundColor White
    Write-Host "           Author: Claire R                   " -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SYSTEM FEATURES:" -ForegroundColor Yellow
    Write-Host " 1.  Enable Windows Sandbox" -ForegroundColor White
    Write-Host " 2.  Enable Hyper-V" -ForegroundColor White
    Write-Host " 3.  Install WSL2 with Ubuntu" -ForegroundColor White
    Write-Host ""
    Write-Host "WINDOWS CUSTOMIZATIONS:" -ForegroundColor Yellow
    Write-Host " 4.  Enable Classic Right-Click Menu" -ForegroundColor White
    Write-Host " 5.  Enable End Task in Taskbar" -ForegroundColor White
    Write-Host " 6.  Disable Fast Boot" -ForegroundColor White
    Write-Host ""
    Write-Host "BROWSERS:" -ForegroundColor Yellow
    Write-Host " 7.  Install Chrome Enterprise" -ForegroundColor White
    Write-Host " 8.  Install Mozilla Firefox" -ForegroundColor White
    Write-Host ""
    Write-Host "ESSENTIAL APPLICATIONS:" -ForegroundColor Yellow
    Write-Host " 9.  Install 7-Zip" -ForegroundColor White
    Write-Host " 10. Install BCUninstaller" -ForegroundColor White
    Write-Host " 11. Install Bulk Rename Utility" -ForegroundColor White
    Write-Host " 12. Install CPU-Z" -ForegroundColor White
    Write-Host " 13. Install File Converter" -ForegroundColor White
    Write-Host " 14. Install Git" -ForegroundColor White
    Write-Host " 15. Install Git Extensions" -ForegroundColor White
    Write-Host " 16. Install Google Chrome" -ForegroundColor White
    Write-Host " 17. Install Krita" -ForegroundColor White
    Write-Host " 18. Install Logi Options+" -ForegroundColor White
    Write-Host " 19. Install Mozilla Firefox" -ForegroundColor White
    Write-Host " 20. Install Notepad++" -ForegroundColor White
    Write-Host " 21. Install OpenSCAD" -ForegroundColor White
    Write-Host " 22. Install VirtualBox" -ForegroundColor White
    Write-Host " 23. Install PeaZip" -ForegroundColor White
    Write-Host " 24. Install PrusaSlicer" -ForegroundColor White
    Write-Host " 25. Install Tabby" -ForegroundColor White
    Write-Host ""
    Write-Host "DEVELOPER SETUP:" -ForegroundColor Magenta
    Write-Host " 26. Setup SSH Key + Git Configuration" -ForegroundColor White
    Write-Host " 27. Setup Git Only (no SSH key)" -ForegroundColor White
    Write-Host " 28. Set Computer Hostname" -ForegroundColor White
    Write-Host ""
    Write-Host "BULK OPERATIONS:" -ForegroundColor Green
    Write-Host " 29. Update All Installed Apps via Winget" -ForegroundColor White
    Write-Host " 30. Install All Applications Only" -ForegroundColor White
    Write-Host ""
    Write-Host " 31. INSTALL EVERYTHING (One-Click Setup)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host " 32. Exit" -ForegroundColor Red
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
        $choice = Read-Host "Enter your choice (1-32)"
        
        switch ($choice) {
            "1"  { Enable-WindowsSandbox; Pause }
            "2"  { Enable-HyperV; Pause }
            "3"  { Install-WSL2; Pause }
            "4"  { Enable-ClassicRightClick; Pause }
            "5"  { Enable-TaskbarEndTask; Pause }
            "6"  { Disable-FastBoot; Pause }
            "7"  { Install-ChromeEnterprise; Pause }
            "8"  { Install-Firefox; Pause }
            "9"  { Install-7Zip; Pause }
            "10" { Install-BCUninstaller; Pause }
            "11" { Install-BulkRenameUtility; Pause }
            "12" { Install-CPUZ; Pause }
            "13" { Install-FileConverter; Pause }
            "14" { Install-Git; Pause }
            "15" { Install-GitExtensions; Pause }
            "16" { Install-GoogleChrome; Pause }
            "17" { Install-Krita; Pause }
            "18" { Install-LogiOptionsPlus; Pause }
            "19" { Install-MozillaFirefox; Pause }
            "20" { Install-NotepadPlusPlus; Pause }
            "21" { Install-OpenSCAD; Pause }
            "22" { Install-VirtualBox; Pause }
            "23" { Install-PeaZip; Pause }
            "24" { Install-PrusaSlicer; Pause }
            "25" { Install-Tabby; Pause }
            "26" { Setup-SSHKeyAndGit; Pause }
            "27" { Setup-GitOnly; Pause }
            "28" { Set-ComputerHostname; Pause }
            "29" { Update-AllApps; Pause }
            "30" { 
                $confirm = Read-Host "This will install all applications only (no system features). Continue? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Install-AllApplications
                }
                Pause
            }
            "31" { 
                $confirm = Read-Host "This will install everything (features + apps + customizations + git setup). Continue? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Install-Everything
                }
                Pause
            }
            "32" { 
                Write-Log "Exiting script..." "INFO"
                break 
            }
            default { 
                Write-Host "Invalid choice. Please select 1-32." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne "32")
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