# update-all-winget.ps1

# Ensure log directory exists
$log_dir = "C:\logs"
if (!(Test-Path $log_dir)) {
	New-Item -ItemType Directory -Path $log_dir | Out-Null
}

# Create timestamped log file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$log_path = "$log_dir\winget-update-$timestamp.txt"

# Start logging
Add-Content -Path $log_path -Value "=== Winget Update Started: $timestamp ===`n"

try {
	winget upgrade --all --accept-source-agreements --accept-package-agreements --silent --disable-interactivity | Tee-Object -FilePath $log_path -Append
	Add-Content -Path $log_path -Value "`n=== Winget Update Completed Successfully ===`n"
} catch {
	Add-Content -Path $log_path -Value "`n*** ERROR: $($_.Exception.Message) ***`n"
}
