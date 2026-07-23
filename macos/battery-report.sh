#!/usr/bin/env bash
# ==========================================================
# Script: battery-report.sh
# Purpose: Check macOS battery health/performance and save a report
# Output: /var/reports/battery-report-YYYY-MM-DD_HH-mm-ss.txt
#         /var/reports/battery-health-history.csv (appended each run)
# ==========================================================

set -euo pipefail

REPORT_DIR="/var/reports"

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
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
    max_capacity="$(grep -m1 "Maximum Capacity" <<< "$profiler_output" | awk -F': ' '{print $2}' | tr -d '%[:space:]')"
    cycle_count="$(grep -m1 "Cycle Count" <<< "$profiler_output" | awk -F': ' '{print $2}' | tr -d '[:space:]')"
    apple_condition="$(grep -m1 "Condition" <<< "$profiler_output" | awk -F': ' '{print $2}' | sed 's/^ *//;s/ *$//')"

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
    echo "  Maximum Capacity:  ${max_capacity}%"
    [[ -n "$cycle_count" ]] && echo "  Cycle Count:       $cycle_count"
    [[ -n "$apple_condition" ]] && echo "  Apple Condition:   $apple_condition"
    echo "  Health Rating:     ${max_capacity}% - $condition"

    if [[ ! -f "$history_path" ]]; then
        echo "Date,MaxCapacityPercent,CycleCount,AppleCondition,HealthRating" > "$history_path"
    fi
    printf '%s,%s,%s,%s,%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$max_capacity" "$cycle_count" "$apple_condition" "$condition" >> "$history_path"
}

main "$@"
