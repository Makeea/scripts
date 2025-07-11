#!/bin/bash

# Script Name: server-update.sh
# Description:
#   Automatically updates and upgrades Ubuntu packages,
#   removes unnecessary packages, double-checks for pending upgrades,
#   and reboots the system without prompts.
# Author: Claire Rosario
# Date: 2025-06-15

set -euo pipefail
trap 'echo "Script failed. Please review the output above." >&2' ERR

# ----------------------------
# HOW TO SCHEDULE THIS SCRIPT
# ----------------------------
# To run this script every Saturday at 12:00 AM, add this to your crontab:
#
#     0 0 * * 6 /absolute/path/to/server-update.sh
#
# Edit your crontab with:
#     crontab -e
#
# Make sure the script is executable:
#     chmod +x /absolute/path/to/server-update.sh
# ----------------------------

echo ""
echo "Starting unattended system maintenance..."

# First update and upgrade pass
echo "Step 1: Updating package lists..."
sudo apt-get update -y

echo "Step 2: Upgrading installed packages..."
sudo apt-get upgrade -y

echo "Step 3: Removing unnecessary packages..."
sudo apt-get autoremove -y

# Double-check for remaining updates
echo "Step 4: Rechecking for pending upgrades..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get autoremove -y

# Final visibility for admin (non-interactive)
echo "Step 5: Final check for any remaining upgrades..."
apt list --upgradable || true

# Reboot
echo "Step 6: Rebooting system to finalize maintenance..."
sudo shutdown -r now

# This line will only run if reboot fails
echo "Maintenance complete, but reboot was skipped or failed."
