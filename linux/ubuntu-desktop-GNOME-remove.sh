#!/bin/sh

# Script Description:
# This script uninstalls the GNOME desktop environment and LightDM, ensuring that all associated packages are removed.

# Uninstall GNOME
echo "Uninstalling GNOME..."
sudo apt autoremove --purge ubuntu-desktop  # Remove GNOME and its dependencies

# Uninstall LightDM
echo "Uninstalling LightDM..."
sudo systemctl stop lightdm.service  # Stop the LightDM service
sudo apt autoremove --purge lightdm  # Remove LightDM and its dependencies

# Perform a final cleanup
echo "Performing final cleanup..."
sudo apt autoremove -y  # Remove any remaining unnecessary packages

echo "GNOME and LightDM have been uninstalled, and system cleanup is complete."