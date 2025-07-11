#!/bin/sh

# Script Description:
# This script allows the user to choose and install a desktop environment (GNOME, KDE, or Xfce) on an Ubuntu system.
# It updates the system, installs the selected desktop environment, and optionally installs LightDM
# to provide a complete desktop environment without user interaction.

# Step 1: Update the system
echo "Step 1: Updating the system..."
sudo apt update -y         # Update the package list
sudo apt upgrade -y        # Upgrade installed packages to the latest versions

# Offer desktop environment choices
echo "Choose a desktop environment to install:"
echo "1. GNOME"
echo "2. KDE"
echo "3. Xfce"
echo -n "Enter the number of your choice (1/2/3): "
read choice

case "$choice" in
    1)
        desktop="ubuntu-desktop"  # GNOME desktop
        ;;
    2)
        desktop="kubuntu-desktop" # KDE desktop
        ;;
    3)
        desktop="xubuntu-desktop" # Xfce desktop
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Ask if the user wants to install LightDM
echo -n "Do you want to install LightDM for the selected desktop environment? (yes/no): "
read -t 30 install_lightdm

if [ "$install_lightdm" = "yes" ]; then
    sudo apt install -y lightdm  # Install LightDM if requested
    lightdm_installed="true"
else
    echo "LightDM is not installed. You may need to manually configure your display manager for the selected desktop environment."
    lightdm_installed="false"
fi

# Step 2: Install the selected desktop environment
echo "Step 2: Installing $desktop..."
sudo apt install $desktop -y   # Install the selected desktop environment with automatic confirmation

# Step 3: Start LightDM if it's installed
if [ "$lightdm_installed" = "true" ]; then
    echo "Step 3: Starting LightDM..."
    sudo systemctl start lightdm.service  # Start the LightDM service to enable the graphical login screen
fi

# Ask the user if they want to reboot
echo -n "Do you want to reboot now? (yes/no): "
read -t 30 answer

if [ "$answer" = "yes" ]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "You chose not to reboot. Please consider rebooting soon for the changes to take effect."
fi

echo "System update, desktop environment installation, and LightDM setup (if requested) completed."
