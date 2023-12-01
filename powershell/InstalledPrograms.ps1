# Script Description: Retrieves a list of installed programs and saves it to a text file on the desktop.
# Author: Claire Rosario
# Website: Rosario.one
# Synopsis: This PowerShell script retrieves a list of installed programs on the computer and saves it to a text file named 'installed_programs.txt' in the 'System Information' folder on the desktop.

# Define the path to save the text file on the desktop
$desktopPath = [System.Environment]::GetFolderPath('Desktop')

# Define the folder name for saving system information
$systemInfoFolderName = "System Information"
$systemInfoFolderPath = Join-Path -Path $desktopPath -ChildPath $systemInfoFolderName

# Create the folder for system information if it doesn't exist
if (-not (Test-Path -Path $systemInfoFolderPath)) {
    New-Item -Path $systemInfoFolderPath -ItemType Directory
}

# Function to get a list of installed programs
function Get-InstalledPrograms {
    return Get-WmiObject -Class Win32_Product | Select-Object -ExpandProperty Name
}

# Get a list of installed programs
$installedPrograms = Get-InstalledPrograms
$installedPrograms | Out-File -FilePath (Join-Path -Path $systemInfoFolderPath -ChildPath 'installed_programs.txt')

# Display a message indicating the completion of the installed programs section
Write-Host "List of installed programs saved to '$systemInfoFolderName\installed_programs.txt'."
