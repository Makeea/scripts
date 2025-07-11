#!/bin/sh

# Script Description:
# This script updates package lists, removes unnecessary packages, upgrades the system, updates Pi-hole,
# and offers to add itself to a weekly cron job. It will reboot the system upon completion.

# Update package lists
echo "Updating package lists..."
sudo apt update -y

# List upgradable packages
echo "Listing upgradable packages..."
apt list --upgradable

# Remove unnecessary packages
echo "Removing unnecessary packages..."
sudo apt autoremove -y

# Upgrade the system
echo "Upgrading the system..."
sudo apt upgrade -y

# Update Pi-hole
echo "Updating Pi-hole..."
pihole -up

# Final cleanup and upgrade
echo "Final cleanup and upgrade..."
sudo apt autoremove -y
sudo apt upgrade -y

# Ask the user if they want to add the script to a weekly cron job
echo "Do you want to add this script to a weekly cron job? [y/N]"
read ADD_CRON

if [ "$ADD_CRON" = "y" ] || [ "$ADD_CRON" = "Y" ]; then
    # Add the script to the crontab
    SCRIPT_PATH="$(realpath $0)"
    (crontab -l 2>/dev/null; echo "0 0 * * 0 $SCRIPT_PATH") | crontab -
    echo "Script added to cron job. It will run every Sunday at midnight."
else
    echo "Script not added to cron job."
fi

# Reboot the system
echo "Rebooting the system in 1 minute..."
sudo shutdown -r +1

# Note: This script should be run with appropriate permissions.
# The user should have sudo privileges and the script should be executable.
