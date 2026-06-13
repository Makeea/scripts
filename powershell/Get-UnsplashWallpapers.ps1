#=============================================================================
# Unsplash Wallpaper Downloader
# Author: Claire R
# Version: 1.0.0
# Last Updated: June 2026
# Purpose: Downloads wallpapers from Unsplash matching screen resolution
#          across configured categories, then rotates the desktop wallpaper.
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
# .\Get-UnsplashWallpapers.ps1                    Download + rotate wallpaper
# .\Get-UnsplashWallpapers.ps1 -SetupApiKey       Store or update API key
# .\Get-UnsplashWallpapers.ps1 -SetupScheduledTask  Register daily Task Scheduler job
#=============================================================================

param(
    [switch]$SetupApiKey,
    [switch]$SetupScheduledTask
)

$ErrorActionPreference = "Stop"

$ConfigDir    = "$env:APPDATA\UnsplashWallpapers"
$ConfigFile   = "$ConfigDir\config.json"
$WallpaperDir = "$env:USERPROFILE\Pictures\Wallpapers\Unsplash"

$Categories = @(
    @{ Name = "Gaming";    Query = "gaming wallpaper setup" },
    @{ Name = "Desktop";   Query = "minimal desktop background" },
    @{ Name = "4K";        Query = "4k ultra hd wallpaper" },
    @{ Name = "Dark";      Query = "dark aesthetic wallpaper" },
    @{ Name = "Abstract";  Query = "abstract background" },
    @{ Name = "Nature";    Query = "nature landscape background" }
)

$PerCategoryCount = 5

#=============================================================================
# WALLPAPER
#=============================================================================

Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class WallpaperHelper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

function Set-DesktopWallpaper {
    param([string]$ImagePath)
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper"   -Value "0"
    [WallpaperHelper]::SystemParametersInfo(20, 0, $ImagePath, 3) | Out-Null
    Write-Host "Wallpaper set: $(Split-Path $ImagePath -Leaf)" -ForegroundColor Green
}

function Get-ScreenResolution {
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    return @{ Width = $screen.Bounds.Width; Height = $screen.Bounds.Height }
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
    param([string]$ApiKey)
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    @{ ApiKey = $ApiKey } | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    Write-Host "API key saved to: $ConfigFile" -ForegroundColor Green
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
}

function Register-WallpaperTask {
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrEmpty($scriptPath)) {
        Write-Host "Cannot determine script path. Run the script from a file, not the console." -ForegroundColor Red
        exit 1
    }

    $pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    if (!$pwshExe) {
        $pwshExe = (Get-Command powershell -ErrorAction SilentlyContinue)?.Source
    }
    if (!$pwshExe) {
        Write-Host "Neither pwsh nor powershell found in PATH." -ForegroundColor Red
        exit 1
    }

    $action   = New-ScheduledTaskAction -Execute $pwshExe `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger  = New-ScheduledTaskTrigger -Daily -At "08:00AM"
    $settings = New-ScheduledTaskSettingsSet `
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

    $searchUrl = "https://api.unsplash.com/search/photos?query={0}&orientation=landscape&per_page={1}&order_by=relevant" `
        -f [Uri]::EscapeDataString($Query), $Count

    $headers = @{
        Authorization    = "Client-ID $ApiKey"
        "Accept-Version" = "v1"
    }

    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
    } catch {
        Write-Host "  API request failed for '$Query': $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }

    if ($response.results.Count -eq 0) {
        Write-Host "  No results for: $Query" -ForegroundColor Yellow
        return @()
    }

    $collected = @()
    foreach ($photo in $response.results) {
        $filePath = Join-Path $saveDir "$($photo.id).jpg"

        if (Test-Path $filePath) {
            $collected += $filePath
            continue
        }

        $imageUrl = "{0}&w={1}&h={2}&fit=crop&q=85" -f $photo.urls.raw, $Width, $Height

        try {
            Invoke-WebRequest -Uri $imageUrl -OutFile $filePath -UseBasicParsing
            # Required by Unsplash API guidelines: trigger download event
            Invoke-RestMethod -Uri $photo.links.download_location -Headers $headers -Method Get | Out-Null
            Write-Host "  Downloaded: $($photo.id).jpg" -ForegroundColor Gray
        } catch {
            Write-Host "  Failed [$($photo.id)]: $($_.Exception.Message)" -ForegroundColor Red
            if (Test-Path $filePath) { Remove-Item $filePath -Force }
            continue
        }

        $collected += $filePath
    }

    return $collected
}

#=============================================================================
# MAIN
#=============================================================================

if ($SetupApiKey) {
    Invoke-SetupApiKey
    exit 0
}

$config = Get-Config
if ($null -eq $config -or [string]::IsNullOrWhiteSpace($config.ApiKey)) {
    Write-Host "No API key configured. Run:" -ForegroundColor Yellow
    Write-Host "  .\Get-UnsplashWallpapers.ps1 -SetupApiKey" -ForegroundColor Cyan
    exit 1
}

if ($SetupScheduledTask) {
    Register-WallpaperTask
    exit 0
}

if (!(Test-Path $WallpaperDir)) {
    New-Item -ItemType Directory -Path $WallpaperDir -Force | Out-Null
}

$resolution = Get-ScreenResolution
Write-Host "Resolution: $($resolution.Width) x $($resolution.Height)" -ForegroundColor Cyan
Write-Host ""

$allWallpapers = @()

foreach ($category in $Categories) {
    Write-Host "[$($category.Name)] $($category.Query)"
    $files = Get-UnsplashImages `
        -ApiKey      $config.ApiKey `
        -Query       $category.Query `
        -CategoryName $category.Name `
        -Width       $resolution.Width `
        -Height      $resolution.Height `
        -Count       $PerCategoryCount
    $allWallpapers += $files
}

Write-Host ""
Write-Host "Total wallpapers in library: $($allWallpapers.Count)" -ForegroundColor Cyan

if ($allWallpapers.Count -gt 0) {
    $pick = $allWallpapers | Get-Random
    Set-DesktopWallpaper -ImagePath $pick
} else {
    Write-Host "No wallpapers downloaded. Check your API key and network." -ForegroundColor Yellow
}

Write-Host "`nDone." -ForegroundColor Green
