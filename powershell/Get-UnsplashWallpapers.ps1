#=============================================================================
# Unsplash Wallpaper Downloader
# Author: Claire R
# Version: 1.1.0
# Last Updated: June 2026
# Purpose: Downloads up to 10 wallpapers per day from Unsplash across
#          configured categories, sized to the largest screen, then sets
#          a different image on each monitor.
#
# FIRST RUN:
# .\Get-UnsplashWallpapers.ps1 -SetupApiKey
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
# .\Get-UnsplashWallpapers.ps1 -SetupScheduledTask  Register daily Task Scheduler job
#=============================================================================

param(
    [switch]$SetupApiKey,
    [switch]$SetupScheduledTask
)

$ErrorActionPreference = "Stop"

$ConfigDir         = "$env:APPDATA\UnsplashWallpapers"
$ConfigFile        = "$ConfigDir\config.json"
$WallpaperDir      = "$env:USERPROFILE\Pictures\Wallpapers\Unsplash"
$MaxDailyDownloads = 10

$Categories = @(
    @{ Name = "Gaming";   Query = "gaming wallpaper setup" },
    @{ Name = "Desktop";  Query = "minimal desktop background" },
    @{ Name = "4K";       Query = "4k ultra hd wallpaper" },
    @{ Name = "Dark";     Query = "dark aesthetic wallpaper" },
    @{ Name = "Abstract"; Query = "abstract background" },
    @{ Name = "Nature";   Query = "nature landscape background" }
)

$script:DownloadedToday = 0

#=============================================================================
# PER-MONITOR WALLPAPER (IDesktopWallpaper COM interface)
#=============================================================================

if (-not ('WallpaperFactory' -as [type])) {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;

[ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDesktopWallpaper {
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
struct RECT { public int Left, Top, Right, Bottom; }

[ComImport, Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")]
class WallpaperFactory {}
"@
}

function Set-PerMonitorWallpaper {
    param([string[]]$ImagePaths)

    $dw           = (New-Object WallpaperFactory) -as [IDesktopWallpaper]
    $monitorCount = [int]$dw.GetMonitorDevicePathCount()
    $dw.SetPosition(4)  # 4 = Fill

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
    param([string]$ApiKey, [int]$TodayCount = -1)
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $cfg = [ordered]@{ ApiKey = $ApiKey }
    if ($TodayCount -ge 0) {
        $cfg.DownloadLog = [ordered]@{ Date = (Get-Date -Format "yyyy-MM-dd"); Count = $TodayCount }
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

function Get-UnsplashImages {
    param(
        [string]$ApiKey,
        [string]$Query,
        [string]$CategoryName,
        [int]$Width,
        [int]$Height,
        [int]$Count
    )

    $saveDir = Join-Path $WallpaperDir $CategoryName
    if (!(Test-Path $saveDir)) {
        New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
    }

    # Always return existing files so the rotation pool stays full even on limit days
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
        Write-Host "  API request failed for '$Query': $($_.Exception.Message)" -ForegroundColor Red
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

if ($SetupApiKey) { Invoke-SetupApiKey; exit 0 }

$config = Get-Config
if ($null -eq $config -or [string]::IsNullOrWhiteSpace($config.ApiKey)) {
    Write-Host "No API key configured. Run:" -ForegroundColor Yellow
    Write-Host "  .\Get-UnsplashWallpapers.ps1 -SetupApiKey" -ForegroundColor Cyan
    exit 1
}

if ($SetupScheduledTask) { Register-WallpaperTask; exit 0 }

# Determine downloads remaining today
$today = Get-Date -Format "yyyy-MM-dd"
if ($null -ne $config.DownloadLog -and $config.DownloadLog.Date -eq $today) {
    $script:DownloadedToday = [int]$config.DownloadLog.Count
} else {
    $script:DownloadedToday = 0
}
$remainingToday = $MaxDailyDownloads - $script:DownloadedToday

Write-Host "Downloads today: $($script:DownloadedToday) / $MaxDailyDownloads  ($remainingToday remaining)" -ForegroundColor Cyan

if (!(Test-Path $WallpaperDir)) {
    New-Item -ItemType Directory -Path $WallpaperDir -Force | Out-Null
}

$resolution = Get-MaxScreenResolution
Write-Host "Largest screen: $($resolution.Width) x $($resolution.Height)" -ForegroundColor Cyan
Write-Host ""

# Spread remaining budget evenly across categories; always fetch existing files when at limit
$perCategory = if ($remainingToday -gt 0) {
    [Math]::Max(1, [Math]::Ceiling($remainingToday / $Categories.Count))
} else { 0 }

$allWallpapers = @()

foreach ($category in $Categories) {
    Write-Host "[$($category.Name)] $($category.Query)"
    $files = Get-UnsplashImages `
        -ApiKey       $config.ApiKey `
        -Query        $category.Query `
        -CategoryName $category.Name `
        -Width        $resolution.Width `
        -Height       $resolution.Height `
        -Count        $perCategory
    $allWallpapers += $files
}

Save-Config -ApiKey $config.ApiKey -TodayCount $script:DownloadedToday

Write-Host ""
Write-Host "Total wallpapers in library: $($allWallpapers.Count)" -ForegroundColor Cyan

if ($allWallpapers.Count -gt 0) {
    # Pick 2 different images for 2 monitors; pad with first if library has only 1
    $pickCount = [Math]::Min($allWallpapers.Count, 2)
    $picks     = @($allWallpapers | Get-Random -Count $pickCount)
    while ($picks.Count -lt 2) { $picks += $picks[0] }

    Write-Host "Setting wallpapers:"
    Set-PerMonitorWallpaper -ImagePaths $picks
} else {
    Write-Host "No wallpapers available. Check your API key and network." -ForegroundColor Yellow
}

Write-Host "`nDone." -ForegroundColor Green
