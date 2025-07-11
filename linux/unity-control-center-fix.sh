#!/bin/sh

# Script Description:
# This script is essential for system stability and user convenience. It fixes issues related to the `unity-control-center` on an Ubuntu system.
# The control center is a critical component responsible for managing system settings. When it malfunctions or becomes corrupted, it can lead to problems with system configuration and user experience.
# This script addresses these issues by uninstalling and reinstalling the `unity-control-center`, ensuring system updates are applied, and providing an option to reboot the system for changes to take effect.
# It offers a user-friendly approach to troubleshooting and restores the functionality of the control center, ultimately enhancing the overall system's performance and usability.

# Step 0: Explain the purpose of the script
echo "This script fixes the unity-control-center by uninstalling and reinstalling it."
echo "It will update your system, uninstall unity-control-center, reinstall it, and optionally reboot."

# Step 1: Uninstall unity-control-center
echo "Step 1: Uninstalling unity-control-center..."
sudo apt remove unity-control-center -y

# Step 2: Update the system
echo "Step 2: Updating the system..."
sudo apt update -y         # Update the package list
sudo apt upgrade -y        # Upgrade installed packages to the latest versions

# Step 3: Reinstall unity-control-center
echo "Step 3: Reinstalling unity-control-center..."
sudo apt install unity-control-center -y

# Ask the user if they want to reboot
echo -n "Do you want to reboot now? (yes/no): "
read -t 30 answer

if [ "$answer" = "yes" ]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "You chose not to reboot. Please consider rebooting soon for the changes to take effect."
fi

echo "unity-control-center fix completed."