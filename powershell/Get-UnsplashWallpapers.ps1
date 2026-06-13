#=============================================================================
# Unsplash Wallpaper Downloader
# Author: Claire R
# Version: 1.3.0
# Last Updated: June 2026
# Purpose: Downloads up to 10 wallpapers per day from Unsplash for one
#          user-defined category at a time (rotates through up to 4),
#          sized to the largest screen, then sets a different image on
#          each monitor.
#
# FIRST RUN:
# .\Get-UnsplashWallpapers.ps1 -SetupApiKey
# .\Get-UnsplashWallpapers.ps1 -SetupCategories
#
# GETTING AN UNSPLASH API KEY (free):
# 1. Go to https://unsplash.com/developers
# 2. Sign in or create an account
# 3. Click "New Application" and accept the API Guidelines
# 4. Fill in app name (e.g. "My Wallpapers") and description
# 5. Copy the "Access Key" (not the Secret Key)
#
# USAGE:
# .\Get-UnsplashWallpapers.ps1                      Download + set per-monitor wallpapers
# .\Get-UnsplashWallpapers.ps1 -SetupApiKey         Store or update API key
# .\Get-UnsplashWallpapers.ps1 -SetupCategories     Define up to 4 search categories
# .\Get-UnsplashWallpapers.ps1 -SetupScheduledTask  Register daily Task Scheduler job
# .\Get-UnsplashWallpapers.ps1 -Reset               Clear download counter + restart rotation
#=============================================================================

param(
    [switch]$SetupApiKey,
    [switch]$SetupCategories,
    [switch]$SetupScheduledTask,
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

$ConfigDir         = "$env:APPDATA\UnsplashWallpapers"
$ConfigFile        = "$ConfigDir\config.json"
$WallpaperDir      = "$env:USERPROFILE\Pictures\Wallpapers\Unsplash"
$MaxDailyDownloads = 10
$MaxCategories     = 4

$script:DownloadedToday = 0

#=============================================================================
# PER-MONITOR WALLPAPER
#=============================================================================

if (-not ([System.Management.Automation.PSTypeName]'WallpaperCom.Api').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;

namespace WallpaperCom {
    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDesktopWallpaper {
        void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID,
                          [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [return: MarshalAs(UnmanagedType.LPWStr)]
        string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        [return: MarshalAs(UnmanagedType.LPWStr)]
        string GetMonitorDevicePathAt([MarshalAs(UnmanagedType.U4)] uint monitorIndex);
        [return: MarshalAs(UnmanagedType.U4)]
        uint GetMonitorDevicePathCount();
        void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID, out RECT rc);
        void SetBackgroundColor([MarshalAs(UnmanagedType.U4)] uint color);
        [return: MarshalAs(UnmanagedType.U4)] uint GetBackgroundColor();
        void SetPosition([MarshalAs(UnmanagedType.I4)] int position);
        [return: MarshalAs(UnmanagedType.I4)] int GetPosition();
        void SetSlideshow(IntPtr items);
        IntPtr GetSlideshow();
        void SetSlideshowOptions([MarshalAs(UnmanagedType.U4)] uint options,
                                 [MarshalAs(UnmanagedType.U4)] uint slideshowTick);
        void GetSlideshowOptions(out uint options, out uint slideshowTick);
        void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID,
                              [MarshalAs(UnmanagedType.I4)] int direction);
        [return: MarshalAs(UnmanagedType.U4)] uint GetStatus();
        [return: MarshalAs(UnmanagedType.Bool)] bool Enable([MarshalAs(UnmanagedType.Bool)] bool enable);
    }

    [ComImport, Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD"),
     CoClass(typeof(DesktopWallpaperImpl))]
    public interface DesktopWallpaper : IDesktopWallpaper {}

    [ComImport, Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")]
    public class DesktopWallpaperImpl {}

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public static class Api {
        public static string[] Set(string[] paths) {
            var dw    = (IDesktopWallpaper)(new DesktopWallpaper());
            dw.SetPosition(4); // Fill
            uint count = dw.GetMonitorDevicePathCount();
            var  lines = new string[count];
            for (uint i = 0; i < count; i++) {
                string id  = dw.GetMonitorDevicePathAt(i);
                string img = paths[i % paths.Length];
                dw.SetWallpaper(id, img);
                lines[i] = string.Format("Monitor {0}: {1}", i + 1, Path.GetFileName(img));
            }
            return lines;
        }
    }
}
'@
}

function Set-PerMonitorWallpaper {
    param([string[]]$ImagePaths)
    [WallpaperCom.Api]::Set($ImagePaths) | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Green
    }
}

#=============================================================================
# CONFIG
#=============================================================================

function Get-Config {
    if (Test-Path $ConfigFile) {
        return Get-Content $ConfigFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Update-Config {
    param([hashtable]$Patch)
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $cfg = if (Test-Path $ConfigFile) {
        $raw = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $ht  = [ordered]@{}
        $raw.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    } else {
        [ordered]@{}
    }
    foreach ($key in $Patch.Keys) { $cfg[$key] = $Patch[$key] }
    $cfg | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
}

#=============================================================================
# SETUP
#=============================================================================

function Invoke-SetupApiKey {
    Write-Host ""
    Write-Host "=== Unsplash API Key Setup ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Get a free key at: https://unsplash.com/developers"
    Write-Host "  1. Sign in, click 'New Application', accept Guidelines"
    Write-Host "  2. Fill in a name and description for your app"
    Write-Host "  3. Copy the 'Access Key' (not the Secret Key)"
    Write-Host ""
    $key = Read-Host "Paste your Unsplash Access Key"
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Host "No key entered. Exiting." -ForegroundColor Red
        exit 1
    }
    Update-Config @{ ApiKey = $key.Trim() }
    Write-Host "API key saved to: $ConfigFile" -ForegroundColor Green
}

function Invoke-SetupCategories {
    Write-Host ""
    Write-Host "=== Category Setup ===" -ForegroundColor Cyan
    Write-Host "Enter up to $MaxCategories Unsplash search terms, one per category."
    Write-Host "Examples: 'dark neon gaming', 'nature 4k forest', 'space nebula'"
    Write-Host "Leave blank to finish early."
    Write-Host ""

    $cur = Get-Config
    if ($null -ne $cur -and $null -ne $cur.Categories -and @($cur.Categories).Count -gt 0) {
        Write-Host "Current categories:"
        @($cur.Categories) | ForEach-Object { $i = 0 } { Write-Host "  $($i + 1). $_"; $i++ }
        Write-Host ""
    }

    $newCategories = @()
    for ($i = 1; $i -le $MaxCategories; $i++) {
        $entry = (Read-Host "Category $i").Trim()
        if ([string]::IsNullOrEmpty($entry)) { break }
        $newCategories += $entry
    }

    if ($newCategories.Count -eq 0) {
        Write-Host "No categories entered. Existing categories unchanged." -ForegroundColor Yellow
        exit 0
    }

    Update-Config @{ Categories = $newCategories; NextCategoryIndex = 0 }
    Write-Host ""
    Write-Host "Saved $($newCategories.Count) categor$(if ($newCategories.Count -eq 1) { 'y' } else { 'ies' }):" -ForegroundColor Green
    $newCategories | ForEach-Object { Write-Host "  - $_" }
    Write-Host "Category rotation reset to start at category 1." -ForegroundColor Cyan
}

function Register-WallpaperTask {
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrEmpty($scriptPath)) {
        Write-Host "Cannot determine script path. Run from a file, not the console." -ForegroundColor Red
        exit 1
    }

    $pwshExe = (Get-Command pwsh       -ErrorAction SilentlyContinue)?.Source
    if (!$pwshExe) {
        $pwshExe = (Get-Command powershell -ErrorAction SilentlyContinue)?.Source
    }
    if (!$pwshExe) {
        Write-Host "Neither pwsh nor powershell found in PATH." -ForegroundColor Red
        exit 1
    }

    $action    = New-ScheduledTaskAction -Execute $pwshExe `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger   = New-ScheduledTaskTrigger -Daily -At "08:00AM"
    $settings  = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

    Register-ScheduledTask -TaskName "UnsplashWallpaperRefresh" `
        -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
        -Description "Downloads and rotates Unsplash wallpapers daily" -Force | Out-Null

    Write-Host "Scheduled task registered: 'UnsplashWallpaperRefresh'" -ForegroundColor Green
    Write-Host "Runs daily at 8:00 AM using: $pwshExe" -ForegroundColor Cyan
}

#=============================================================================
# DOWNLOAD
#=============================================================================

function Get-CategoryPrefix {
    param([string]$Query)
    return ($Query -replace '[<>:"/\\|?*]', '' -replace '\s+', '-').Trim('-')
}

function Get-UnsplashImages {
    param(
        [string]$ApiKey,
        [string]$Query,
        [string]$Prefix,
        [int]$Count
    )

    if (!(Test-Path $WallpaperDir)) {
        New-Item -ItemType Directory -Path $WallpaperDir -Force | Out-Null
    }

    $existingFiles = @(Get-ChildItem $WallpaperDir -Filter "$Prefix-*.jpg" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)

    if ($Count -le 0 -or $script:DownloadedToday -ge $MaxDailyDownloads) {
        return $existingFiles
    }

    $headers = @{
        Authorization    = "Client-ID $ApiKey"
        "Accept-Version" = "v1"
    }

    $searchUrl = "https://api.unsplash.com/search/photos?query={0}&orientation=landscape&per_page={1}&order_by=relevant" `
        -f [Uri]::EscapeDataString($Query), $Count

    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
    } catch {
        Write-Host "  API request failed: $($_.Exception.Message)" -ForegroundColor Red
        return $existingFiles
    }

    if ($response.results.Count -eq 0) {
        Write-Host "  No results for: $Query" -ForegroundColor Yellow
        return $existingFiles
    }

    $collected = [System.Collections.Generic.List[string]]$existingFiles

    foreach ($photo in $response.results) {
        if ($script:DownloadedToday -ge $MaxDailyDownloads) {
            Write-Host "  Daily limit reached ($MaxDailyDownloads)." -ForegroundColor Yellow
            break
        }

        $filePath = Join-Path $WallpaperDir "$Prefix-$($photo.id).jpg"
        if (Test-Path $filePath) { continue }

        try {
            # download_location returns the authorized image URL and registers the
            # download event with Unsplash in one call (required by API guidelines)
            $dlInfo = Invoke-RestMethod -Uri $photo.links.download_location -Headers $headers -Method Get
            Invoke-WebRequest -Uri $dlInfo.url -Headers $headers -OutFile $filePath -UseBasicParsing
            $script:DownloadedToday++
            Write-Host "  Downloaded: $Prefix-$($photo.id).jpg  [$script:DownloadedToday/$MaxDailyDownloads]" -ForegroundColor Gray
            $collected.Add($filePath)
        } catch {
            Write-Host "  Failed [$($photo.id)]: $($_.Exception.Message)" -ForegroundColor Red
            if (Test-Path $filePath) { Remove-Item $filePath -Force }
        }
    }

    return $collected.ToArray()
}

#=============================================================================
# MAIN
#=============================================================================

if ($SetupApiKey)     { Invoke-SetupApiKey;     exit 0 }
if ($SetupCategories) { Invoke-SetupCategories; exit 0 }
if ($Reset) {
    Update-Config @{ NextCategoryIndex = 0; DownloadLog = [ordered]@{ Date = ""; Count = 0 } }
    Write-Host "Reset: category rotation back to 1, download counter cleared." -ForegroundColor Green
    exit 0
}

$config = Get-Config

if ($null -eq $config -or [string]::IsNullOrWhiteSpace($config.ApiKey)) {
    Write-Host "No API key configured. Run:" -ForegroundColor Yellow
    Write-Host "  .\Get-UnsplashWallpapers.ps1 -SetupApiKey" -ForegroundColor Cyan
    exit 1
}

$configCategories = @($config.Categories)
if ($configCategories.Count -eq 0) {
    Write-Host "No categories configured. Run:" -ForegroundColor Yellow
    Write-Host "  .\Get-UnsplashWallpapers.ps1 -SetupCategories" -ForegroundColor Cyan
    exit 1
}

if ($SetupScheduledTask) { Register-WallpaperTask; exit 0 }

# Determine today's download count
$today = Get-Date -Format "yyyy-MM-dd"
if ($null -ne $config.DownloadLog -and $config.DownloadLog.Date -eq $today) {
    $script:DownloadedToday = [int]$config.DownloadLog.Count
} else {
    $script:DownloadedToday = 0
}
$remainingToday = $MaxDailyDownloads - $script:DownloadedToday

# Pick category for this run and advance the index
$currentIdx = [int]($config.NextCategoryIndex ?? 0) % $configCategories.Count
$nextIdx    = ($currentIdx + 1) % $configCategories.Count
$query      = $configCategories[$currentIdx]
$prefix     = Get-CategoryPrefix -Query $query

Write-Host "Category ($($currentIdx + 1)/$($configCategories.Count)): $query" -ForegroundColor Cyan
Write-Host "Downloads today: $($script:DownloadedToday) / $MaxDailyDownloads  ($remainingToday remaining)" -ForegroundColor Cyan

if (!(Test-Path $WallpaperDir)) {
    New-Item -ItemType Directory -Path $WallpaperDir -Force | Out-Null
}

Write-Host ""

Get-UnsplashImages `
    -ApiKey  $config.ApiKey `
    -Query   $query `
    -Prefix  $prefix `
    -Count   $remainingToday | Out-Null

Update-Config @{
    NextCategoryIndex = $nextIdx
    DownloadLog       = [ordered]@{ Date = $today; Count = $script:DownloadedToday }
}

$allWallpapers = @(Get-ChildItem $WallpaperDir -Filter "*.jpg" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName)

Write-Host ""
Write-Host "Total wallpapers in library: $($allWallpapers.Count)" -ForegroundColor Cyan

if ($allWallpapers.Count -gt 0) {
    $pickCount = [Math]::Min($allWallpapers.Count, 2)
    $picks     = @($allWallpapers | Get-Random -Count $pickCount)
    while ($picks.Count -lt 2) { $picks += $picks[0] }

    Write-Host "Setting wallpapers:"
    Set-PerMonitorWallpaper -ImagePaths $picks
} else {
    Write-Host "No wallpapers available. Check your API key and network." -ForegroundColor Yellow
}

Write-Host "`nDone." -ForegroundColor Green
