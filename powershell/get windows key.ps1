<#
.SYNOPSIS
Retrieves the Windows product key (may not work reliably) and saves it to a text file on the desktop.

.DESCRIPTION
This script attempts to retrieve the Windows product key (may not work reliably) and saves it to a text file named 'windows_product_key.txt' in the 'System Information' folder on the desktop.

.AUTHOR
Author: Claire Rosario
Website: Rosario.one
(may not work reliably)
This exports to a folder called System info on your desktop
#>

# Function to get the Windows product key (may not work reliably)
function Get-WindowsProductKey {
    $productKey = (Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService").OA3xOriginalProductKey
    return $productKey
}

# Get the Windows product key (may not work reliably)
$productKey = Get-WindowsProductKey

# Define the path to save the text file in the "System Information" folder on the desktop
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemInfoFolderPath = Join-Path -Path $desktopPath -ChildPath 'System Information'

# Create the "System Information" folder if it doesn't exist
if (-not (Test-Path -Path $systemInfoFolderPath -PathType Container)) {
    New-Item -Path $systemInfoFolderPath -ItemType Directory
}

# Check if a product key was found
if ($productKey -ne $null) {
    # Save the Windows product key to a text file
    $productKey | Out-File -FilePath (Join-Path -Path $systemInfoFolderPath -ChildPath 'windows_product_key.txt')

    # Display a message indicating the file location
    Write-Host "Windows product key saved to 'windows_product_key.txt' in the 'System Information' folder on the desktop."
} else {
    Write-Host "No Windows product key found (may not work reliably)."
}
