# This script lists all saved Wi-Fi SSIDs and their passwords
# You must run this script as Administrator

# Ask the user if they want to save the results to a file
$saveChoice = Read-Host "Do you want to save the Wi-Fi passwords to a file on your Desktop? (y/n)"

# If yes, set up the output file path
if ($saveChoice -eq 'y') {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $outputFile = "$desktopPath\wifi-passwords.txt"
    "" | Out-File -FilePath $outputFile -Encoding UTF8  # create or clear the file
}

# Get all saved Wi-Fi profiles
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}

# Loop through each profile
foreach ($profile in $profiles) {
    $ssidLine = "SSID: $profile"
    $keyLine = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content"
    
    if ($keyLine) {
        $password = ($keyLine -split ":")[1].Trim()
        $result = "$ssidLine`nPassword: $password`n"
    } else {
        $result = "$ssidLine`nPassword: Not found or not stored`n"
    }

    # Show on screen
    Write-Host $result

    # Optionally write to file
    if ($saveChoice -eq 'y') {
        $result | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
}

# Final message if file was saved
if ($saveChoice -eq 'y') {
    Write-Host "`nSaved to: $outputFile"
}
