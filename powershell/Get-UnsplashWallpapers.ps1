#=============================================================================
# Unsplash Wallpaper Downloader
# Author: Claire R
# Version: 1.2.0
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
#=============================================================================

param(
    [switch]$SetupApiKey,
    [switch]$SetupCategories,
    [switch]$SetupScheduledTask
)

$ErrorActionPreference = "Stop"

$ConfigDir         = "$env:APPDATA\UnsplashWallpapers"
$ConfigFile        = "$ConfigDir\config.json"
$WallpaperDir      = "$env:USERPROFILE\Pictures\Wallpapers\Unsplash"
$MaxDailyDownloads = 10
$MaxCategories     = 4

$script:DownloadedToday = 0

#=============================================================================
# PER-MONITOR WALLPAPER (IDesktopWallpaper COM interface)
#=============================================================================

if (-not ([System.Management.Automation.PSTypeName]'UnsplashWp.IDesktopWallpaper').Type) {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;

namespace UnsplashWp {
    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDesktopWallpaper {
        void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt([MarshalAs(UnmanagedType.U4)] uint monitorIndex);
        [return: MarshalAs(UnmanagedType.U4)] uint GetMonitorDevicePathCount();
        void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID, out RECT rc);
        void SetBackgroundColor([MarshalAs(UnmanagedType.U4)] uint color);
        [return: MarshalAs(UnmanagedType.U4)] uint GetBackgroundColor();
        void SetPosition([MarshalAs(UnmanagedType.I4)] int position);
        [return: MarshalAs(UnmanagedType.I4)] int GetPosition();
        void SetSlideshow(System.IntPtr items);
        System.IntPtr GetSlideshow();
        void SetSlideshowOptions([MarshalAs(UnmanagedType.U4)] uint options, [MarshalAs(UnmanagedType.U4)] uint slideshowTick);
        void GetSlideshowOptions(out uint options, out uint slideshowTick);
        void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.I4)] int direction);
        [return: MarshalAs(UnmanagedType.U4)] uint GetStatus();
        [return: MarshalAs(UnmanagedType.Bool)] bool Enable([MarshalAs(UnmanagedType.Bool)] bool enable);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
}

function Set-PerMonitorWallpaper {
    param([string[]]$ImagePaths)
    $clsid        = [Guid]"C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD"
    $dw           = [Activator]::CreateInstance([Type]::GetTypeFromCLSID($clsid)) -as [UnsplashWp.IDesktopWallpaper]
    $monitorCount = [int]$dw.GetMonitorDevicePathCount()
    $dw.SetPosition(4)  # Fill
    for ($i = 0; $i -lt $monitorCount; $i++) {
        $monitorId = $dw.GetMonitorDevicePathAt([uint32]$i)
        $img       = $ImagePaths[$i % $ImagePaths.Count]
        $dw.SetWallpaper($monitorId, $img)
        Write-Host "  Monitor $($i + 1): $(Split-Path $img -Leaf)" -ForegroundColor Green
    }
}

#=============================================================================
# SCREEN RESOLUTION
#=============================================================================

function Get-MaxScreenResolution {
    Add-Type -AssemblyName System.Windows.Forms
    $best = @{ Width = 1920; Height = 1080 }
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        if (($s.Bounds.Width * $s.Bounds.Height) -gt ($best.Width * $best.Height)) {
            $best = @{ Width = $s.Bounds.Width; Height = $s.Bounds.Height }
        }
    }
    return $best
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

function Save-Config {
    param(
        [AllowNull()][string]  $ApiKey            = $null,
        [AllowNull()][string[]]$Categories         = $null,
        [int]                  $NextCategoryIndex  = -1,
        [int]                  $TodayCount         = -1
    )
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $cur = if (Test-Path $ConfigFile) { Get-Content $ConfigFile -Raw | ConvertFrom-Json } else { $null }

    $cfg = [ordered]@{
        ApiKey = if ($null -ne $ApiKey) {
            $ApiKey
        } elseif ($null -ne $cur -and $null -ne $cur.ApiKey) {
            $cur.ApiKey
        } else { "" }

        Categories = if ($null -ne $Categories) {
            $Categories
        } elseif ($null -ne $cur -and $null -ne $cur.Categories) {
            @($cur.Categories)
        } else { @() }

        NextCategoryIndex = if ($NextCategoryIndex -ge 0) {
            $NextCategoryIndex
        } elseif ($null -ne $cur -and $null -ne $cur.NextCategoryIndex) {
            [int]$cur.NextCategoryIndex
        } else { 0 }
    }

    if ($TodayCount -ge 0) {
        $cfg.DownloadLog = [ordered]@{ Date = (Get-Date -Format "yyyy-MM-dd"); Count = $TodayCount }
    } elseif ($null -ne $cur -and $null -ne $cur.DownloadLog) {
        $cfg.DownloadLog = [ordered]@{ Date = $cur.DownloadLog.Date; Count = [int]$cur.DownloadLog.Count }
    }

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
    Save-Config -ApiKey $key.Trim()
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

    Save-Config -Categories $newCategories -NextCategoryIndex 0
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

function Get-FolderName {
    param([string]$Query)
    return ($Query -replace '[<>:"/\\|?*]', '_' -replace '\s+', '_').Trim('_')
}

function Get-UnsplashImages {
    param(
        [string]$ApiKey,
        [string]$Query,
        [string]$FolderName,
        [int]$Width,
        [int]$Height,
        [int]$Count
    )

    $saveDir = Join-Path $WallpaperDir $FolderName
    if (!(Test-Path $saveDir)) {
        New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
    }

    $existingFiles = @(Get-ChildItem $saveDir -Filter "*.jpg" -ErrorAction SilentlyContinue |
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

        $filePath = Join-Path $saveDir "$($photo.id).jpg"
        if (Test-Path $filePath) { continue }

        $imageUrl = "{0}&w={1}&h={2}&fit=crop&q=85" -f $photo.urls.raw, $Width, $Height

        try {
            Invoke-WebRequest -Uri $imageUrl -OutFile $filePath -UseBasicParsing
            Invoke-RestMethod -Uri $photo.links.download_location -Headers $headers -Method Get | Out-Null
            $script:DownloadedToday++
            Write-Host "  Downloaded: $($photo.id).jpg  [$script:DownloadedToday/$MaxDailyDownloads]" -ForegroundColor Gray
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

if ($SetupApiKey)         { Invoke-SetupApiKey;       exit 0 }
if ($SetupCategories)     { Invoke-SetupCategories;   exit 0 }

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
$currentIdx  = [int]($config.NextCategoryIndex ?? 0) % $configCategories.Count
$nextIdx     = ($currentIdx + 1) % $configCategories.Count
$query       = $configCategories[$currentIdx]
$folderName  = Get-FolderName -Query $query

Write-Host "Category ($($currentIdx + 1)/$($configCategories.Count)): $query" -ForegroundColor Cyan
Write-Host "Downloads today: $($script:DownloadedToday) / $MaxDailyDownloads  ($remainingToday remaining)" -ForegroundColor Cyan

if (!(Test-Path $WallpaperDir)) {
    New-Item -ItemType Directory -Path $WallpaperDir -Force | Out-Null
}

$resolution = Get-MaxScreenResolution
Write-Host "Largest screen: $($resolution.Width) x $($resolution.Height)" -ForegroundColor Cyan
Write-Host ""

$categoryFiles = Get-UnsplashImages `
    -ApiKey     $config.ApiKey `
    -Query      $query `
    -FolderName $folderName `
    -Width      $resolution.Width `
    -Height     $resolution.Height `
    -Count      $remainingToday

# Persist updated index and download count
Save-Config -NextCategoryIndex $nextIdx -TodayCount $script:DownloadedToday

# Rotate wallpapers from the full library (all categories downloaded so far)
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
