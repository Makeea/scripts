#!/usr/bin/env bash
# ==========================================================
# Script: battery-report.sh
# Purpose: Check macOS battery health/performance and save a report
# Output: /var/reports/battery-report-YYYY-MM-DD_HH-mm-ss.txt
#         /var/reports/battery-health-history.csv (appended each run)
# ==========================================================

set -euo pipefail

REPORT_DIR="/var/reports"
HISTORY_HEADER="Date,MaxCapacityPercent,CycleCount,AppleCondition,HealthRating,FullChargeCapacity_mAh,Voltage_mV,Amperage_mA,Charging,FullyCharged,Device"

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

field() {
    # Extracts the value after "Label: " for the first matching line
    grep -m1 "$1" <<< "$2" | awk -F': ' '{print $2}' | sed 's/^ *//;s/ *$//'
}

main() {
    local profiler_output
    profiler_output="$(system_profiler SPPowerDataType 2>/dev/null || true)"

    if ! grep -q "Battery Information" <<< "$profiler_output"; then
        echo "No battery detected on this system (likely a desktop Mac). Skipping battery report."
        exit 0
    fi

    mkdir -p "$REPORT_DIR" 2>/dev/null || fail "Cannot create $REPORT_DIR (try running with sudo)."

    local timestamp report_path history_path
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    report_path="$REPORT_DIR/battery-report-$timestamp.txt"
    history_path="$REPORT_DIR/battery-health-history.csv"

    printf '%s\n' "$profiler_output" > "$report_path"
    echo "Battery report saved to $report_path"

    # macOS already computes battery health itself; pull its own fields rather than recalculating
    local max_capacity cycle_count apple_condition
    max_capacity="$(field "Maximum Capacity" "$profiler_output" | tr -d '%')"
    cycle_count="$(field "Cycle Count" "$profiler_output")"
    apple_condition="$(field "Condition" "$profiler_output")"

    # Extra hardware-level detail, all read live from the battery's own controller
    # via system_profiler/IOKit, not from any OS history -- this data survives a
    # fresh macOS install since it lives on the battery itself.
    local serial manufacturer device_name full_charge_mah voltage_mv amperage_ma charging fully_charged device_id
    serial="$(field "Serial Number" "$profiler_output")"
    manufacturer="$(field "Manufacturer" "$profiler_output")"
    device_name="$(field "Device Name" "$profiler_output")"
    full_charge_mah="$(field "Full Charge Capacity" "$profiler_output")"
    voltage_mv="$(field "Voltage (mV)" "$profiler_output")"
    amperage_ma="$(field "Amperage (mA)" "$profiler_output")"
    charging="$(field "Charging:" "$profiler_output")"
    fully_charged="$(field "Fully Charged" "$profiler_output")"
    device_id="$(printf '%s %s %s' "$manufacturer" "$device_name" "$serial" | sed 's/^ *//;s/ *$//;s/  */ /g')"

    if [[ -z "$max_capacity" ]]; then
        echo "Could not determine battery health percentage (Maximum Capacity not reported)."
        exit 0
    fi

    local condition
    if awk -v h="$max_capacity" 'BEGIN { exit !(h >= 80) }'; then
        condition="Good"
    elif awk -v h="$max_capacity" 'BEGIN { exit !(h >= 60) }'; then
        condition="Fair (noticeable wear)"
    elif awk -v h="$max_capacity" 'BEGIN { exit !(h >= 40) }'; then
        condition="Poor (replacement recommended)"
    else
        condition="Very Poor (replace battery)"
    fi

    echo
    echo "Battery Health Summary"
    [[ -n "$device_id" ]] && echo "  Device:               $device_id"
    echo "  Maximum Capacity:     ${max_capacity}%"
    [[ -n "$cycle_count" ]] && echo "  Cycle Count:          $cycle_count"
    [[ -n "$apple_condition" ]] && echo "  Apple Condition:      $apple_condition"
    echo "  Health Rating:        ${max_capacity}% - $condition"
    [[ -n "$full_charge_mah" ]] && echo "  Full Charge Capacity: $full_charge_mah mAh"
    [[ -n "$voltage_mv" ]] && echo "  Voltage:              $voltage_mv mV"
    [[ -n "$amperage_ma" ]] && echo "  Amperage:             $amperage_ma mA"
    [[ -n "$charging" ]] && echo "  Charging:             $charging"
    [[ -n "$fully_charged" ]] && echo "  Fully Charged:        $fully_charged"

    if [[ -f "$history_path" ]] && [[ "$(head -n1 "$history_path")" != "$HISTORY_HEADER" ]]; then
        # Older history file used a smaller column set -- keep it instead of silently breaking the CSV shape
        mv "$history_path" "$REPORT_DIR/battery-health-history-$timestamp.csv.bak"
    fi
    if [[ ! -f "$history_path" ]]; then
        echo "$HISTORY_HEADER" > "$history_path"
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$max_capacity" "$cycle_count" "$apple_condition" "$condition" \
        "$full_charge_mah" "$voltage_mv" "$amperage_ma" "$charging" "$fully_charged" "$device_id" >> "$history_path"
}

main "$@"
