#!/bin/sh

# Script Description:
# This script automates the setup of a graphical user interface (GUI) on an Ubuntu system.
# It updates the system, installs the GNOME desktop environment, and configures LightDM
# to provide a complete desktop environment without user interaction.

# Step 1: Update the system
echo "Step 1: Updating the system..."
sudo apt update -y         # Update the package list
sudo apt upgrade -y        # Upgrade installed packages to the latest versions

# Step 2: Install GNOME and LightDM
echo "Step 2: Installing GNOME and LightDM..."
sudo apt install ubuntu-desktop -y  # Install the GNOME desktop environment with automatic confirmation
sudo apt install -y lightdm          # Install LightDM (display manager) with automatic confirmation

# Step 3: Start LightDM
echo "Step 3: Starting LightDM..."
sudo systemctl start lightdm.service  # Start the LightDM service to enable the graphical login screen

# Ask the user if they want to reboot
echo -n "Do you want to reboot now? (yes/no): "
read -t 30 answer

if [ "$answer" = "yes" ]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "You chose not to reboot. Please consider rebooting soon for the changes to take effect."
fi

echo "System update, GNOME installation, and LightDM setup completed."
