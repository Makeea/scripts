# ==========================================================
# Script: Get-BatteryReport.ps1
# Path: C:\Users\Claire\projects\scripts\powershell\Get-BatteryReport.ps1
# Purpose: Generate a Windows battery health/performance report
# Output: C:\reports\battery-report-YYYY-MM-DD_HH-mm-ss.html
#         C:\reports\battery-health-history.csv (appended each run)
# ==========================================================

# ==========================================================
# HOW TO ADD THIS SCRIPT TO TASK SCHEDULER
# ==========================================================
# 1. Open Task Scheduler
# 2. Click "Create Task" (not "Create Basic Task")
# 3. General tab:
#      - Name: Battery Health Report
#      - Select: Run with highest privileges
#      - Configure for: Windows 10/11
# 4. Triggers tab:
#      - Click "New"
#      - Choose how often (e.g. Weekly, Monthly)
#      - Set time (e.g. 9:00 AM)
#      - Click OK
# 5. Actions tab:
#      - Click "New"
#      - Action: Start a program
#      - Program/script (choose one):
#          a) For PowerShell 5 (Windows built-in):
#             C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
#          b) For PowerShell 7+ (if installed):
#             C:\Program Files\PowerShell\7\pwsh.exe
#      - Add arguments:
#             -ExecutionPolicy Bypass -File "C:\path-to-script\Get-BatteryReport.ps1"
#      - Click OK
# 6. Click OK to save the task
# 7. Run it manually once to confirm the report is generated
# ==========================================================

# 1. Confirm this machine has a battery before doing anything else
$battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
if (-not $battery) {
    Write-Host "No battery detected on this system (likely a desktop). Skipping battery report."
    exit 0
}

# 2. Ensure report directory exists
#    Creates C:\reports if it doesn't already exist
$report_dir = "C:\reports"
if (!(Test-Path $report_dir)) {
    New-Item -ItemType Directory -Path $report_dir | Out-Null
}

# 3. Build timestamped report path
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$report_path = "$report_dir\battery-report-$timestamp.html"

# 4. Generate the report
#    powercfg /batteryreport is the built-in Windows tool for battery health:
#    design capacity vs. full charge capacity, charge/discharge history, and life estimates
try {
    powercfg /batteryreport /output "$report_path" | Out-Null
    if (Test-Path $report_path) {
        Write-Host "Battery report saved to $report_path"
    } else {
        Write-Host "ERROR: powercfg did not produce a report file." -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Battery health percentage (Full Charge Capacity vs. Design Capacity)
#    Common industry rule of thumb (Apple's Battery Health feature, most OEM
#    warranties): capacity retention below ~80% is when noticeable
#    degradation/replacement conversations typically start. Not a hard law,
#    just the most consistently cited threshold.
try {
    try {
        $staticData = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop
    } catch {
        # Some systems throw a generic CIM driver error on this class; the older WMI provider still works
        $staticData = Get-WmiObject -Namespace root\wmi -Class BatteryStaticData
    }
    $fullChargeData = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity

    $designCapacity = ($staticData | Select-Object -First 1).DesignedCapacity
    $fullChargeCapacity = ($fullChargeData | Select-Object -First 1).FullChargedCapacity

    # Extra hardware-level detail, all read live from the battery's own controller
    # (embedded controller / fuel gauge via ACPI), not from Windows history --
    # this data survives a Windows reinstall since it lives on the battery itself.
    $deviceId = ($battery | Select-Object -First 1).DeviceID

    try {
        $cycleData = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction Stop
    } catch {
        $cycleData = Get-WmiObject -Namespace root\wmi -Class BatteryCycleCount -ErrorAction SilentlyContinue
    }
    $cycleCount = ($cycleData | Select-Object -First 1).CycleCount

    $statusData = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
    $voltage = $statusData.Voltage
    $chargeRate = $statusData.ChargeRate
    $dischargeRate = $statusData.DischargeRate
    $remainingCapacity = $statusData.RemainingCapacity
    $batteryState = if ($statusData.Critical) { "Critical" } elseif ($statusData.Charging) { "Charging" } elseif ($statusData.Discharging) { "Discharging" } else { "Idle" }

    if ($designCapacity -and $fullChargeCapacity) {
        $healthPercent = [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 1)

        if ($healthPercent -ge 80) {
            $condition = "Good"
        } elseif ($healthPercent -ge 60) {
            $condition = "Fair (noticeable wear)"
        } elseif ($healthPercent -ge 40) {
            $condition = "Poor (replacement recommended)"
        } else {
            $condition = "Very Poor (replace battery)"
        }

        Write-Host ""
        Write-Host "Battery Health Summary"
        if ($deviceId) { Write-Host "  Device:                $deviceId" }
        Write-Host "  Design Capacity:       $designCapacity mWh"
        Write-Host "  Full Charge Capacity:  $fullChargeCapacity mWh"
        Write-Host "  Health:                $healthPercent% - $condition"
        if ($cycleCount) { Write-Host "  Cycle Count:           $cycleCount" }
        if ($voltage) { Write-Host "  Voltage:               $voltage mV" }
        if ($remainingCapacity) { Write-Host "  Remaining Capacity:    $remainingCapacity mWh" }
        if ($chargeRate -or $dischargeRate) { Write-Host "  Charge/Discharge Rate: $chargeRate / $dischargeRate mW" }
        Write-Host "  State:                 $batteryState"

        # Append to a running history file so health can be tracked over time
        $history_path = "$report_dir\battery-health-history.csv"
        $expectedHeader = '"Date","DesignCapacity_mWh","FullChargeCapacity_mWh","HealthPercent","Condition","CycleCount","Voltage_mV","ChargeRate_mW","DischargeRate_mW","RemainingCapacity_mWh","State","DeviceId"'
        if ((Test-Path $history_path) -and ((Get-Content $history_path -TotalCount 1) -ne $expectedHeader)) {
            # Older history file used a smaller column set -- keep it instead of silently breaking the CSV shape
            Rename-Item -Path $history_path -NewName "battery-health-history-$timestamp.csv.bak"
        }
        [PSCustomObject]@{
            Date                   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            DesignCapacity_mWh     = $designCapacity
            FullChargeCapacity_mWh = $fullChargeCapacity
            HealthPercent          = $healthPercent
            Condition              = $condition
            CycleCount             = $cycleCount
            Voltage_mV             = $voltage
            ChargeRate_mW          = $chargeRate
            DischargeRate_mW       = $dischargeRate
            RemainingCapacity_mWh  = $remainingCapacity
            State                  = $batteryState
            DeviceId               = $deviceId
        } | Export-Csv -Path $history_path -Append -NoTypeInformation -Force
    } else {
        Write-Host "Could not determine battery health percentage (capacity data unavailable)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not determine battery health percentage: $($_.Exception.Message)" -ForegroundColor Yellow
}
