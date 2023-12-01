<#
.SYNOPSIS
Retrieves the last used date for installed applications and saves it to a text file on the desktop.

.DESCRIPTION
This script attempts to retrieve the last used date for installed applications (may not work reliably) and saves it to a text file named 'last_used_dates.txt' in the 'System Information' folder on the desktop.

.AUTHOR
Author: Claire Rosario
Website: Rosario.one

List all programs' last use date (may not work reliably)
This exports to a folder called System info on your desktop
#>

# Function to get a list of installed programs
function Get-InstalledPrograms {
    return Get-WmiObject -Class Win32_Product | Select-Object -ExpandProperty Name
}

# Function to get the last used date for installed applications (may not work reliably)
function Get-LastUsedDate {
    $programs = Get-InstalledPrograms
    $lastUsedDates = @{}
    foreach ($program in $programs) {
        $lastUsedDate = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object DisplayName -eq $program).InstallDate
        if ($lastUsedDate) {
            $lastUsedDates[$program] = $lastUsedDate
        }
    }
    return $lastUsedDates
}

# Get the last used dates for installed applications (may not work reliably)
$lastUsedDates = Get-LastUsedDate

# Define the path to save the text file in the "System Information" folder on the desktop
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemInfoFolderPath = Join-Path -Path $desktopPath -ChildPath 'System Information'

# Create the "System Information" folder if it doesn't exist
if (-not (Test-Path -Path $systemInfoFolderPath -PathType Container)) {
    New-Item -Path $systemInfoFolderPath -ItemType Directory
}

# Save the last used dates to a text file
$lastUsedDates | Out-File -FilePath (Join-Path -Path $systemInfoFolderPath -ChildPath 'last_used_dates.txt')

# Display a message indicating the file location
Write-Host "Last used dates for installed applications saved to 'last_used_dates.txt' in the 'System Information' folder on the desktop."
