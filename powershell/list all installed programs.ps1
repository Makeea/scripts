<#
.SYNOPSIS
Retrieves a list of installed programs and saves it to a text file on the desktop.

.DESCRIPTION
This script retrieves a list of installed programs on the computer and saves it to a text file named 'installed_programs.txt' in the 'System Information' folder on the desktop.

.AUTHOR
Author: Claire Rosario
Website: Rosario.one

#>

# Get a list of installed programs
$installedPrograms = Get-WmiObject -Class Win32_Product | Select-Object -ExpandProperty Name

# Define the path to save the text file in the "System Information" folder on the desktop
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemInfoFolderPath = Join-Path -Path $desktopPath -ChildPath 'System Information'

# Create the "System Information" folder if it doesn't exist
if (-not (Test-Path -Path $systemInfoFolderPath -PathType Container)) {
    New-Item -Path $systemInfoFolderPath -ItemType Directory
}

# Save the list of installed programs to a text file
$installedPrograms | Out-File -FilePath (Join-Path -Path $systemInfoFolderPath -ChildPath 'installed_programs.txt')

# Display a message indicating the file location
Write-Host "List of installed programs saved to 'installed_programs.txt' in the 'System Information' folder on the desktop."
