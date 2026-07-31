#!/bin/sh
# Script Description: This script installs and configures the Proxmox QEMU Guest Agent.

# Update the system
echo "Updating the package list..."
sudo apt update -y

# Upgrade installed packages
echo "Upgrading installed packages..."
sudo apt upgrade -y

# Clean up unnecessary packages
echo "Removing unnecessary packages..."
sudo apt autoremove -y

# Install and enable the QEMU Guest Agent
echo "Installing QEMU Guest Agent..."
sudo apt install qemu-guest-agent -y

# Enable the QEMU Guest Agent service
echo "Enabling the QEMU Guest Agent service..."
sudo systemctl enable qemu-guest-agent

echo "Proxmox QEMU Guest Agent installation and configuration completed."
