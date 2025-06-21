#!/usr/bin/env pwsh
# ===============================================================================
# Remove-ProjectJunk.ps1 - Windows PowerShell Project Cleanup Script
# ===============================================================================
# AUTHOR: Claire Rosario
# CREATED: Saturday, June 07, 2025
# VERSION: 2.0 - Complete Edition
#
# DESCRIPTION: Removes system files, build artifacts, and junk from projects
#              Designed for Windows PowerShell with interactive prompts
#
# USAGE: .\Remove-ProjectJunk.ps1 [OPTIONS]
# Run with -Help for detailed usage information
# ===============================================================================

param(
    # Basic options
    [switch]$DryRun,                    # Preview what would be deleted
    [switch]$Force,                     # Skip all confirmation prompts
    [string]$Path = ".",                # Target directory (default: current)
    
    # Output control
    [switch]$Verbose,                   # Show detailed file operations
    [switch]$Quiet,                     # Minimal output
    [string]$LogFile,                   # Save detailed log to file
    
    # Cleanup modes
    [switch]$OnlySystemFiles,           # Clean only OS system files
    [switch]$OnlyBuildFiles,            # Clean only build artifacts
    [switch]$SkipGit,                   # Don't remove from Git tracking
    [switch]$SkipArchives,              # Don't delete archive files
    [switch]$SkipEmptyDirs,             # Don't remove empty directories
    
    # Custom options
    [int]$MaxFileSizeMB,                # Max file size to delete (MB)
    
    # Help
    [switch]$Help                       # Show detailed help
)

# Show help if requested
if ($Help) {
    Write-Host @"
Remove-ProjectJunk.ps1 - Windows PowerShell Project Cleanup Script

USAGE:
  .\Remove-ProjectJunk.ps1 [OPTIONS]

BASIC OPTIONS:
  -DryRun              Preview what would be deleted (RECOMMENDED FIRST)
  -Force               Skip all confirmation prompts
  -Path "C:\Project"   Target directory (default: current)

OUTPUT OPTIONS:
  -Verbose             Show detailed file operations
  -Quiet               Minimal output
  -LogFile "log.txt"   Save detailed log to file

CLEANUP MODES:
  -OnlySystemFiles     Clean only OS system files
  -OnlyBuildFiles      Clean only build artifacts and cache
  -SkipGit             Don't remove from Git tracking
  -SkipArchives        Don't delete archive files
  -SkipEmptyDirs       Don't remove empty directories

CUSTOM OPTIONS:
  -MaxFileSizeMB 100   Don't delete files larger than N MB

HELP:
  -Help                Show this help message

EXAMPLES:
  .\Remove-ProjectJunk.ps1 -DryRun
  .\Remove-ProjectJunk.ps1 -OnlySystemFiles
  .\Remove-ProjectJunk.ps1 -Force -SkipArchives
  .\Remove-ProjectJunk.ps1 -Path "C:\MyProject" -Verbose -LogFile "cleanup.log"

WHAT IT CLEANS:
  ✓ Windows: Thumbs.db, Desktop.ini, *.lnk, Zone.Identifier files
  ✓ macOS: .DS_Store, ._*, .Spotlight-V100 (from Mac developers)
  ✓ Linux: *~, .nfs* (from WSL/Git)
  ✓ Build: node_modules, __pycache__, target, dist, build
  ✓ Cache: .cache, tmp, .sass-cache, .parcel-cache
  ✓ Logs: *.log, npm-debug.log*, yarn-debug.log*
  ✓ Backups: *.bak, *.swp, *.tmp, *.old
  ✓ Compiled: *.pyc, *.class, *.o, *.obj
  ✓ Archives: *.zip, *.rar, *.7z (with confirmation)
  ✓ Empty directories

SAFETY FEATURES:
  • Always run with -DryRun first to preview changes
  • Interactive prompts with 5-second timeouts for each category
  • Full path display before deletion
  • Comprehensive error handling and logging
  • Git integration to remove tracked files
  • File size limits and exclusion patterns

Make sure to run with -DryRun first to preview changes!
"@ -ForegroundColor Cyan
    exit 0
}

# Validate target path
if (-not (Test-Path $Path -PathType Container)) {
    Write-Host "Error: Directory '$Path' does not exist" -ForegroundColor Red
    exit 1
}

# Convert to absolute path
$Path = Resolve-Path $Path

# Initialize statistics
$script:stats = @{
    FilesDeleted = 0
    FoldersDeleted = 0
    SizeFreed = 0
    GitFilesRemoved = 0
    ErrorsEncountered = 0
    StartTime = Get-Date
}

# Initialize logging
if ($LogFile) {
    $logDir = Split-Path $LogFile -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    "=== Cleanup Started: $(Get-Date) ===" | Out-File $LogFile
    "Parameters: DryRun=$DryRun, Force=$Force, Path=$Path" | Out-File $LogFile -Append
}

# Logging function
function Write-LogMessage {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )
    
    if (-not $Quiet -or $Level -eq "ERROR") {
        Write-Host $Message -ForegroundColor $Color
    }
    
    if ($LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$Level] $Message" | Out-File $LogFile -Append
    }
}

# Display header
if (-not $Quiet) {
    Write-LogMessage "INFO" "=== WINDOWS POWERSHELL CLEANUP v2.0 ===" "Cyan"
    Write-LogMessage "INFO" "Target: $Path" "Yellow"
    if ($DryRun) {
        Write-LogMessage "INFO" "Mode: DRY RUN (Preview Only)" "Magenta"
    } else {
        Write-LogMessage "INFO" "Mode: LIVE CLEANUP" "Red"
    }
    
    # Show active options
    $options = @()
    if ($Force) { $options += "Force" }
    if ($Verbose) { $options += "Verbose" }
    if ($OnlySystemFiles) { $options += "OnlySystemFiles" }
    if ($OnlyBuildFiles) { $options += "OnlyBuildFiles" }
    if ($SkipGit) { $options += "SkipGit" }
    if ($SkipArchives) { $options += "SkipArchives" }
    
    if ($options.Count -gt 0) {
        Write-LogMessage "INFO" "Options: $($options -join ', ')" "Cyan"
    }
    Write-LogMessage "INFO" ("=" * 50) "Cyan"
}

# Size formatting function
function Format-FileSize {
    param([long]$Size)
    
    if ($Size -lt 1KB) {
        return "$($Size)B"
    } elseif ($Size -lt 1MB) {
        return "$([math]::Round($Size/1KB, 1))KB"
    } else {
        return "$([math]::Round($Size/1MB, 1))MB"
    }
}

# File size check function
function Test-FileSizeAcceptable {
    param([System.IO.FileInfo]$File)
    
    if ($MaxFileSizeMB) {
        $fileSizeMB = $File.Length / 1MB
        return $fileSizeMB -le $MaxFileSizeMB
    }
    return $true
}

# Show items and prompt function with simplified timeout
function Show-AndPrompt {
    param(
        [string]$Category,
        [string]$ItemType,
        [array]$Items
    )
    
    if ($Items.Count -eq 0) {
        return $false
    }
    
    Write-LogMessage "INFO" "`n--- $Category ---" "Green"
    Write-LogMessage "INFO" "Found $($Items.Count) $ItemType`:" "Yellow"
    
    # Show all items with paths and sizes
    foreach ($item in $Items) {
        $relativePath = $item.FullName.Replace($Path, ".").Replace("\", "/")
        
        if ($ItemType -eq "folders") {
            try {
                $size = (Get-ChildItem $item.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                        Measure-Object -Property Length -Sum).Sum
                if ($null -eq $size) { $size = 0 }
                Write-LogMessage "INFO" "  → $relativePath ($(Format-FileSize $size))" "White"
            } catch {
                Write-LogMessage "INFO" "  → $relativePath (unknown size)" "White"
            }
        } else {
            # Check file size limits
            if (-not (Test-FileSizeAcceptable $item)) {
                if ($Verbose) {
                    Write-LogMessage "INFO" "  ⚠ Skipped (too large): $relativePath" "DarkYellow"
                }
                continue
            }
            
            Write-LogMessage "INFO" "  → $relativePath ($(Format-FileSize $item.Length))" "White"
        }
    }
    
    # Interactive prompt with fixed timeout
    if (-not $DryRun -and -not $Force) {
        Write-LogMessage "INFO" "Delete all items in '$Category'? Press 'n' to skip, or wait 5 seconds to proceed..." "Cyan"
        
        # Use a simpler approach without jobs
        $timeout = 50  # 5 seconds in 100ms intervals
        $response = ""
        
        for ($i = 0; $i -lt $timeout; $i++) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'n' -or $key.KeyChar -eq 'N') {
                    Write-Host "n"
                    Write-LogMessage "INFO" "Skipped $Category" "Yellow"
                    return $false
                } elseif ($key.Key -eq [ConsoleKey]::Enter) {
                    Write-Host ""
                    break
                } else {
                    Write-Host $key.KeyChar -NoNewline
                }
            }
            Start-Sleep -Milliseconds 100
        }
        
        Write-LogMessage "INFO" "Proceeding with cleanup..." "Green"
    }
    return $true
}

# Delete items function
function Remove-ItemsSafely {
    param(
        [string]$ItemType,
        [array]$Items
    )
    
    foreach ($item in $Items) {
        # Skip if item no longer exists
        if (-not (Test-Path $item.FullName)) {
            continue
        }
        
        $relativePath = $item.FullName.Replace($Path, ".").Replace("\", "/")
        
        # Check file size limits for files
        if ($ItemType -eq "file" -and -not (Test-FileSizeAcceptable $item)) {
            continue
        }
        
        try {
            if ($DryRun) {
                Write-LogMessage "INFO" "Would delete: $relativePath" "Yellow"
            } else {
                if ($ItemType -eq "folder") {
                    Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
                    Write-LogMessage "INFO" "Deleted folder: $relativePath" "Red"
                    $script:stats.FoldersDeleted++
                    if ($LogFile) {
                        "Deleted folder: $relativePath" | Out-File $LogFile -Append
                    }
                } else {
                    Remove-Item $item.FullName -Force -ErrorAction Stop
                    Write-LogMessage "INFO" "Deleted: $relativePath" "Red"
                    $script:stats.FilesDeleted++
                    $script:stats.SizeFreed += $item.Length
                    if ($LogFile) {
                        "Deleted: $relativePath" | Out-File $LogFile -Append
                    }
                }
            }
        }
        catch {
            Write-LogMessage "ERROR" "Failed: $relativePath - $($_.Exception.Message)" "DarkRed"
            $script:stats.ErrorsEncountered++
            if ($LogFile) {
                "Failed: $relativePath - $($_.Exception.Message)" | Out-File $LogFile -Append
            }
        }
    }
}

# Git removal function
function Remove-FromGit {
    param(
        [string]$Category,
        [array]$Patterns
    )
    
    if ($SkipGit -or -not (Test-Path ".git")) {
        return
    }
    
    foreach ($pattern in $Patterns) {
        try {
            $null = git rm -r --cached $pattern 2>$null
            if ($LASTEXITCODE -eq 0) {
                if ($Verbose) {
                    Write-LogMessage "INFO" "Removed from Git: $pattern" "Cyan"
                }
                $script:stats.GitFilesRemoved++
            }
        } catch {
            # Ignore git errors
        }
    }
}

# MAIN CLEANUP PROCESS
Write-LogMessage "INFO" "Starting cleanup process..." "Yellow"

# Change to target directory
Set-Location $Path

# File patterns by category - COMPREHENSIVE LIST
$filePatterns = @{
    "Windows System Files" = @("Thumbs.db", "ehthumbs.db", "ehthumbs_vista.db", "Desktop.ini", "*.lnk", "*.stackdump")
    "macOS Files (from Mac devs)" = @(".DS_Store", "._*", ".Spotlight-V100", ".Trashes", ".fseventsd", ".localized")
    "Linux Files (from WSL/Git)" = @("*~", ".nfs*")
    "Zone Identifier Files" = @("*Zone.Identifier", "*.Zone.Identifier")
    "Editor Backup Files" = @("*.bak", "*.old", "*.orig", "*.swp", "*.swo", "*.tmp", "*.temp")
    "Development Log Files" = @("*.log", "npm-debug.log*", "yarn-debug.log*", "yarn-error.log*", "debug.log")
    "Cache Files" = @(".eslintcache", ".sass-cache", "*.cache", ".nyc_output", ".coverage")
}

# Folder patterns by category
$folderPatterns = @{
    "Build Directories" = @("node_modules", "__pycache__", ".pytest_cache", "target", "build", "dist", "bin", "obj", ".next", ".nuxt")
    "Cache Directories" = @(".cache", "cache", ".tmp", "tmp", "temp", ".sass-cache", ".parcel-cache")
    "System Directories" = @(".Trash-*", ".AppleDouble", ".LSOverride", "System Volume Information", "`$RECYCLE.BIN")
    "IDE Directories" = @(".vscode", ".idea", ".settings", ".metadata", ".vs", ".venv", "venv", ".tox")
}

# Process file patterns
if (-not $OnlyBuildFiles) {
    foreach ($category in $filePatterns.Keys) {
        # Skip non-system files if only cleaning system files
        if ($OnlySystemFiles -and $category -notlike "*System Files*" -and $category -notlike "*Zone*" -and $category -notlike "*Files*") {
            continue
        }
        
        $foundFiles = @()
        $patterns = $filePatterns[$category]
        
        foreach ($pattern in $patterns) {
            try {
                $files = Get-ChildItem -Path $Path -Filter $pattern -Recurse -File -Force -ErrorAction SilentlyContinue
                $foundFiles += $files
            } catch {
                # Ignore search errors
            }
        }
        
        if (Show-AndPrompt $category "files" $foundFiles) {
            Remove-ItemsSafely "file" $foundFiles
            if (-not $DryRun) {
                Remove-FromGit $category $patterns
            }
        }
    }
}

# Process folder patterns
if (-not $OnlySystemFiles) {
    foreach ($category in $folderPatterns.Keys) {
        # Skip non-build folders if only cleaning build files
        if ($OnlyBuildFiles -and $category -notlike "*Build*" -and $category -notlike "*Cache*") {
            continue
        }
        
        $foundFolders = @()
        $patterns = $folderPatterns[$category]
        
        foreach ($pattern in $patterns) {
            try {
                if ($pattern.Contains("*")) {
                    $folders = Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue | 
                              Where-Object { $_.Name -like $pattern }
                } else {
                    $folders = Get-ChildItem -Path $Path -Filter $pattern -Recurse -Directory -Force -ErrorAction SilentlyContinue
                }
                $foundFolders += $folders
            } catch {
                # Ignore search errors
            }
        }
        
        if (Show-AndPrompt $category "folders" $foundFolders) {
            Remove-ItemsSafely "folder" $foundFolders
        }
    }
}

# Handle compiled files
if (-not $OnlySystemFiles) {
    $compiledFiles = @()
    $compiledExts = @("*.pyc", "*.pyo", "*.class", "*.o", "*.obj", "*.exe", "*.dll", "*.so")
    
    foreach ($ext in $compiledExts) {
        $files = Get-ChildItem -Path $Path -Filter $ext -Recurse -File -Force -ErrorAction SilentlyContinue
        $compiledFiles += $files
    }
    
    if (Show-AndPrompt "Compiled Files" "files" $compiledFiles) {
        Remove-ItemsSafely "file" $compiledFiles
    }
}

# Handle archive files
if (-not $OnlySystemFiles -and -not $SkipArchives) {
    $archiveFiles = @()
    $archiveExts = @("*.zip", "*.rar", "*.7z", "*.tar", "*.gz", "*.bz2", "*.xz")
    
    foreach ($ext in $archiveExts) {
        $files = Get-ChildItem -Path $Path -Filter $ext -Recurse -File -Force -ErrorAction SilentlyContinue
        $archiveFiles += $files
    }
    
    if (Show-AndPrompt "Archive Files (CAUTION: May contain important backups!)" "files" $archiveFiles) {
        Remove-ItemsSafely "file" $archiveFiles
    }
}

# Handle empty directories
if (-not $SkipEmptyDirs) {
    $emptyDirs = Get-ChildItem -Path $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
        try {
            (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
        } catch {
            $false
        }
    }
    
    if (Show-AndPrompt "Empty Directories" "folders" $emptyDirs) {
        Remove-ItemsSafely "folder" $emptyDirs
    }
}

# Calculate execution time
$executionTime = (Get-Date) - $script:stats.StartTime

# Final summary
if (-not $Quiet) {
    Write-LogMessage "INFO" "`n=== CLEANUP SUMMARY ===" "Cyan"
    Write-LogMessage "INFO" "Files deleted: $($script:stats.FilesDeleted)" "White"
    Write-LogMessage "INFO" "Folders deleted: $($script:stats.FoldersDeleted)" "White"
    Write-LogMessage "INFO" "Space freed: $(Format-FileSize $script:stats.SizeFreed)" "White"
    if (-not $SkipGit) {
        Write-LogMessage "INFO" "Git files removed: $($script:stats.GitFilesRemoved)" "White"
    }
    if ($script:stats.ErrorsEncountered -gt 0) {
        Write-LogMessage "INFO" "Errors: $($script:stats.ErrorsEncountered)" "Red"
    } else {
        Write-LogMessage "INFO" "Errors: $($script:stats.ErrorsEncountered)" "White"
    }
    Write-LogMessage "INFO" "Time: $([math]::Round($executionTime.TotalSeconds, 2)) seconds" "White"

    if ($DryRun) {
        Write-LogMessage "INFO" "`nDRY RUN - No files were deleted. Run without -DryRun to clean." "Magenta"
    } else {
        Write-LogMessage "INFO" "`nCleanup completed!" "Green"
        if ((Test-Path ".git") -and $script:stats.GitFilesRemoved -gt 0 -and -not $SkipGit) {
            Write-LogMessage "INFO" "Next steps: git status, then git commit -m 'Remove junk files'" "Yellow"
        }
    }
}

# Finalize logging
if ($LogFile) {
    "=== Cleanup Completed: $(Get-Date) ===" | Out-File $LogFile -Append
    "Statistics: Files=$($script:stats.FilesDeleted), Folders=$($script:stats.FoldersDeleted), Errors=$($script:stats.ErrorsEncountered)" | Out-File $LogFile -Append
    if (-not $Quiet) {
        Write-LogMessage "INFO" "Log saved to: $LogFile" "Cyan"
    }
}

# Exit with appropriate code
if ($script:stats.ErrorsEncountered -gt 0) {
    exit 1
} else {
    exit 0
}