#!/usr/bin/env bash
# ==========================================================
# Script: battery-report.sh
# Purpose: Check Linux battery health/performance and save a report
# Output: /var/reports/battery-report-YYYY-MM-DD_HH-mm-ss.txt
#         /var/reports/battery-health-history.csv (appended each run)
# ==========================================================

set -euo pipefail

REPORT_DIR="/var/reports"

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

find_battery() {
    local bat
    for bat in /sys/class/power_supply/BAT*; do
        [[ -d "$bat" ]] && printf '%s\n' "$bat" && return 0
    done
    return 1
}

read_attr() {
    local path="$1"
    [[ -r "$path" ]] && cat "$path" || printf ''
}

main() {
    local bat_path
    if ! bat_path="$(find_battery)"; then
        echo "No battery detected on this system (likely a desktop/server). Skipping battery report."
        exit 0
    fi

    mkdir -p "$REPORT_DIR" 2>/dev/null || fail "Cannot create $REPORT_DIR (try running with sudo)."

    local timestamp report_path history_path
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    report_path="$REPORT_DIR/battery-report-$timestamp.txt"
    history_path="$REPORT_DIR/battery-health-history.csv"

    # Batteries expose capacity either as energy (uWh) or charge (uAh); use whichever the driver provides
    local full design unit
    if [[ -r "$bat_path/energy_full" && -r "$bat_path/energy_full_design" ]]; then
        full="$(read_attr "$bat_path/energy_full")"
        design="$(read_attr "$bat_path/energy_full_design")"
        unit="uWh"
    elif [[ -r "$bat_path/charge_full" && -r "$bat_path/charge_full_design" ]]; then
        full="$(read_attr "$bat_path/charge_full")"
        design="$(read_attr "$bat_path/charge_full_design")"
        unit="uAh"
    else
        fail "Battery found at $bat_path but no capacity data is exposed by the kernel driver."
    fi

    local charge_percent status cycle_count model
    charge_percent="$(read_attr "$bat_path/capacity")"
    status="$(read_attr "$bat_path/status")"
    cycle_count="$(read_attr "$bat_path/cycle_count")"
    model="$(read_attr "$bat_path/model_name")"

    # Save the raw diagnostic dump as the detailed report
    {
        echo "Battery Report - $timestamp"
        echo "Device: $bat_path"
        [[ -n "$model" ]] && echo "Model: $model"
        echo "Status: $status"
        echo "Current Charge: ${charge_percent}%"
        echo
        echo "--- Raw attributes ---"
        cat "$bat_path/uevent" 2>/dev/null || true
    } > "$report_path"

    echo "Battery report saved to $report_path"

    if [[ -z "$full" || -z "$design" || "$design" -eq 0 ]]; then
        echo "Could not determine battery health percentage (capacity data unavailable)."
        exit 0
    fi

    local health_percent condition
    health_percent="$(awk -v f="$full" -v d="$design" 'BEGIN { printf "%.1f", (f / d) * 100 }')"

    if awk -v h="$health_percent" 'BEGIN { exit !(h >= 80) }'; then
        condition="Good"
    elif awk -v h="$health_percent" 'BEGIN { exit !(h >= 60) }'; then
        condition="Fair (noticeable wear)"
    elif awk -v h="$health_percent" 'BEGIN { exit !(h >= 40) }'; then
        condition="Poor (replacement recommended)"
    else
        condition="Very Poor (replace battery)"
    fi

    echo
    echo "Battery Health Summary"
    echo "  Design Capacity:      $design $unit"
    echo "  Full Charge Capacity: $full $unit"
    [[ -n "$cycle_count" && "$cycle_count" != "0" ]] && echo "  Cycle Count:          $cycle_count"
    echo "  Health:               ${health_percent}% - $condition"

    if [[ ! -f "$history_path" ]]; then
        echo "Date,DesignCapacity,FullChargeCapacity,Unit,HealthPercent,Condition" > "$history_path"
    fi
    printf '%s,%s,%s,%s,%s,%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$design" "$full" "$unit" "$health_percent" "$condition" >> "$history_path"
}

main "$@"
