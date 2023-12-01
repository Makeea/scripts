#!/bin/sh

# Script Description:
# This script updates and upgrades the Ubuntu system, asks the user if they want to upgrade to the latest OS version,

# Function to ask for OS upgrade with a 30-second timeout
ask_for_os_upgrade() {
    echo "Do you want to upgrade to the latest OS version? You have 30 seconds to answer. [Y/n]"
    read -t 30 RESPONSE

    if [ "$RESPONSE" = "Y" ] || [ "$RESPONSE" = "y" ]; then
        echo "Upgrading to the latest OS version..."
        sudo apt-get dist-upgrade -y
    else
        echo "Skipping OS upgrade."
    fi
}

# Ask the user if they want to upgrade to the latest OS version
ask_for_os_upgrade

# Update package lists
echo "Updating package lists..."
sudo apt-get update -y

# Upgrade packages
echo "Upgrading packages..."
sudo apt-get upgrade -y

# Remove unnecessary packages
echo "Removing unnecessary packages..."
sudo apt-get autoremove -y

# Final system check for upgradable packages
echo "Final check for upgradable packages..."
apt list --upgradable

# Function to ask for system reboot with a 30-second timeout
ask_for_reboot() {
    echo "Do you want to reboot the system now? You have 30 seconds to answer. [Y/n]"
    read -t 30 REBOOT_RESPONSE

    if [ "$REBOOT_RESPONSE" = "Y" ] || [ "$REBOOT_RESPONSE" = "y" ]; then
        echo "Rebooting the system..."
        sudo shutdown -r now
    else
        echo "System will not reboot. It's recommended to reboot later for changes to take effect."
    fi
}

# Ask the user if they want to reboot the system
ask_for_reboot

echo "System update and upgrade process completed."
