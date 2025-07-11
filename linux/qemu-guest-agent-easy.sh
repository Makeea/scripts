#!/bin/bash

# Update the package list
echo "Updating package list..."
sudo apt update

# Install qemu-guest-agent
echo "Installing qemu-guest-agent..."
sudo apt install -y qemu-guest-agent

# Ask user to enable qemu-guest-agent service to autostart
read -p "Are you sure you want to set qemu-guest-agent to autostart? (y/n): " confirm
if [[ $confirm == [Yy]* ]]; then
    sudo systemctl enable qemu-guest-agent
    echo "qemu-guest-agent service enabled to autostart."
else
    echo "Autostart not enabled."
fi

# Ask user if they want to reboot
read -p "Do you want to reboot the system now? (y/n): " reboot
if [[ $reboot == [Yy]* ]]; then
    echo "Rebooting the system..."
    sudo reboot
else
    echo "System will not be rebooted."
fi