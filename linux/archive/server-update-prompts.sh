#!/bin/bash

# Script Name: server-update.sh
# Description:
#   Updates and upgrades Ubuntu, with optional OS upgrade, optional weekly cron scheduling,
#   and an optional reboot prompt. Designed to be used interactively or via cron.
# Author: Claire Rosario
# Date: 2025-06-15

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Define an error trap to print a message if any command fails
trap 'echo "Script failed. Please check for issues." >&2' ERR

# Get the absolute path to this script
SCRIPT_PATH="$(realpath "$0")"

# Function: Prompt user to optionally upgrade the OS
ask_for_os_upgrade() {
    echo ""
    echo "Do you want to upgrade to the latest Ubuntu OS version?"
    echo "You have 10 seconds to respond. [y/N]"
    # Wait up to 10 seconds for user input; default to "n" if no response
    read -t 10 -r RESPONSE || RESPONSE="n"

    # Convert input to lowercase and check for "y"
    case "${RESPONSE,,}" in
        y)
            echo "Starting OS upgrade..."
            # Ensure the update manager is installed
            sudo apt install -y update-manager-core
            # Start the OS release upgrade
            sudo do-release-upgrade
            ;;
        *)
            echo "Skipping OS version upgrade."
            ;;
    esac
}

# Function: Prompt user to optionally schedule this script to run weekly via cron
ask_to_schedule_weekly() {
    echo ""
    echo "Do you want to schedule this script to run weekly on Saturday at 12:00 AM?"
    echo "You have 10 seconds to respond. [y/N]"
    # Wait up to 10 seconds for user input; default to "n" if no response
    read -t 10 -r SCHEDULE_RESPONSE || SCHEDULE_RESPONSE="n"

    case "${SCHEDULE_RESPONSE,,}" in
        y)
            # Define the cron job string
            CRON_JOB="0 0 * * 6 $SCRIPT_PATH"

            # Check if this cron job already exists
            if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
                echo "Cron job already exists. No changes made."
            else
                # Append the new cron job to the current crontab
                (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
                echo "Script scheduled to run weekly at 12:00 AM on Saturdays."
            fi
            ;;
        *)
            echo "Skipping weekly schedule setup."
            ;;
    esac
}

# Function: Prompt user to optionally reboot the system
ask_for_reboot() {
    echo ""
    echo "Do you want to reboot the system now?"
    echo "You have 10 seconds to respond. [y/N]"
    # Wait up to 10 seconds for user input; default to "n" if no response
    read -t 10 -r REBOOT_RESPONSE || REBOOT_RESPONSE="n"

    case "${REBOOT_RESPONSE,,}" in
        y)
            echo "Rebooting the system..."
            # Reboot the system immediately
            sudo shutdown -r now
            ;;
        *)
            echo "System will not reboot now. Please reboot manually later if needed."
            ;;
    esac
}

# ---------------------------
# MAIN SCRIPT EXECUTION
# ---------------------------

echo "Starting system update and upgrade process..."

# Ask if the user wants to upgrade the OS
ask_for_os_upgrade

# Update the system's package list
echo ""
echo "Updating package lists..."
sudo apt-get update -y

# Upgrade installed packages to the latest versions
echo ""
echo "Upgrading installed packages..."
sudo apt-get upgrade -y

# Remove packages that are no longer required
echo ""
echo "Removing unnecessary packages..."
sudo apt-get autoremove -y

# Show any remaining upgradable packages
echo ""
echo "Final check for upgradable packages..."
apt list --upgradable || true

# Ask if the user wants to schedule this script to run weekly
ask_to_schedule_weekly

# Ask if the user wants to reboot now
ask_for_reboot

echo ""
echo "System update and upgrade process completed."
