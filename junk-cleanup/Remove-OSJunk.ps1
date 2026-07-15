#!/usr/bin/env pwsh
# ===============================================================================
# Remove-OSJunk.ps1 - Recursive OS junk file cleaner
# ===============================================================================
# DESCRIPTION: Recursively finds OS-generated junk files and folders
#              (macOS, Windows, Linux) under a target directory and sends
#              them to the Recycle Bin. Does NOT touch build artifacts,
#              caches, version control, or archive/compressed files.
#
# USAGE: .\Remove-OSJunk.ps1 [-Path <dir>] [-DryRun] [-Permanent]
# ===============================================================================

param(
    [string]$Path = ".",
    [switch]$DryRun,
    [switch]$Permanent    # Skip the Recycle Bin and delete permanently
)

if (-not (Test-Path $Path -PathType Container)) {
    Write-Host "Error: Directory '$Path' does not exist" -ForegroundColor Red
    exit 1
}

$Path = (Resolve-Path $Path).Path

if (-not $DryRun -and -not $Permanent) {
    Add-Type -AssemblyName Microsoft.VisualBasic
}

# Junk directories are removed whole (with their contents)
$junkDirNames = @(
    "__MACOSX", ".Spotlight-V100", ".Trashes", ".fseventsd", ".AppleDouble",
    '$RECYCLE.BIN', "System Volume Information"
)
$junkDirPatterns = @(".Trash-*")

# Junk files, matched by name/pattern
$junkFilePatterns = @(
    ".DS_Store", "._*", ".apdisk", ".localized",
    "Thumbs.db", "ehthumbs.db", "ehthumbs_vista.db", "desktop.ini", "*.lnk", "*Zone.Identifier*",
    "*~", ".nfs*", ".directory"
)

function Format-FileSize {
    param([long]$Size)
    if ($Size -lt 1KB) { return "$($Size)B" }
    elseif ($Size -lt 1MB) { return "$([math]::Round($Size/1KB, 1))KB" }
    else { return "$([math]::Round($Size/1MB, 1))MB" }
}

function Remove-FileToDestination {
    param([string]$FullPath)
    if ($Permanent) {
        Remove-Item $FullPath -Force -ErrorAction Stop
    } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $FullPath,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
}

function Remove-DirectoryToDestination {
    param([string]$FullPath)
    if ($Permanent) {
        Remove-Item $FullPath -Recurse -Force -ErrorAction Stop
    } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $FullPath,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
}

$verb = if ($Permanent) { "Deleted (permanent)" } else { "Recycled" }
$verbWould = if ($Permanent) { "Would permanently delete" } else { "Would recycle" }

Write-Host "=== OS Junk Cleanup ===" -ForegroundColor Cyan
Write-Host "Target: $Path" -ForegroundColor Yellow
if ($DryRun) {
    Write-Host "Mode: DRY RUN (preview only)" -ForegroundColor Magenta
} elseif ($Permanent) {
    Write-Host "Mode: LIVE CLEANUP (permanent delete)" -ForegroundColor Red
} else {
    Write-Host "Mode: LIVE CLEANUP (Recycle Bin)" -ForegroundColor Red
}
Write-Host ""

$filesDeleted = 0
$foldersDeleted = 0
$sizeFreed = 0

# Find matching directories (exact names + glob patterns), collapsed so nested
# matches inside an already-matched junk directory aren't processed twice.
$foundDirs = @()
foreach ($name in $junkDirNames) {
    $foundDirs += Get-ChildItem -Path $Path -Filter $name -Recurse -Directory -Force -ErrorAction SilentlyContinue
}
foreach ($pattern in $junkDirPatterns) {
    $foundDirs += Get-ChildItem -Path $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $pattern }
}
$foundDirs = $foundDirs | Sort-Object FullName -Unique | Where-Object {
    $dir = $_.FullName
    -not ($foundDirs | Where-Object { $_.FullName -ne $dir -and $dir.StartsWith($_.FullName + [IO.Path]::DirectorySeparatorChar) })
}

foreach ($dir in $foundDirs) {
    $relative = $dir.FullName.Replace($Path, ".").Replace("\", "/")
    $size = (Get-ChildItem $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $size) { $size = 0 }

    if ($DryRun) {
        Write-Host "$verbWould folder: $relative ($(Format-FileSize $size))" -ForegroundColor Yellow
    } else {
        try {
            Remove-DirectoryToDestination $dir.FullName
            Write-Host "$verb folder: $relative ($(Format-FileSize $size))" -ForegroundColor Red
            $foldersDeleted++
            $sizeFreed += $size
        } catch {
            Write-Host "Failed: $relative - $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    }
}

# Find matching files, skipping anything already inside a removed junk directory
$foundFiles = @()
foreach ($pattern in $junkFilePatterns) {
    $foundFiles += Get-ChildItem -Path $Path -Filter $pattern -Recurse -File -Force -ErrorAction SilentlyContinue
}
$foundFiles = $foundFiles | Sort-Object FullName -Unique | Where-Object {
    $file = $_.FullName
    -not ($foundDirs | Where-Object { $file.StartsWith($_.FullName + [IO.Path]::DirectorySeparatorChar) })
}

foreach ($file in $foundFiles) {
    $relative = $file.FullName.Replace($Path, ".").Replace("\", "/")

    if ($DryRun) {
        Write-Host "$verbWould $relative ($(Format-FileSize $file.Length))" -ForegroundColor Yellow
    } else {
        try {
            $size = $file.Length
            Remove-FileToDestination $file.FullName
            Write-Host "$verb $relative ($(Format-FileSize $size))" -ForegroundColor Red
            $filesDeleted++
            $sizeFreed += $size
        } catch {
            Write-Host "Failed: $relative - $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Would process $($foundFiles.Count) file(s) and $($foundDirs.Count) folder(s)" -ForegroundColor White
    Write-Host "`nDRY RUN - nothing was touched. Run without -DryRun to clean." -ForegroundColor Magenta
} else {
    Write-Host "Files $($verb.ToLower()): $filesDeleted" -ForegroundColor White
    Write-Host "Folders $($verb.ToLower()): $foldersDeleted" -ForegroundColor White
    Write-Host "Space freed: $(Format-FileSize $sizeFreed)" -ForegroundColor White
    if ($Permanent) {
        Write-Host "`nCleanup complete! (permanently deleted, not recoverable)" -ForegroundColor Green
    } else {
        Write-Host "`nCleanup complete! Items were sent to the Recycle Bin." -ForegroundColor Green
    }
}
