#!/bin/bash

# Function for automatic installation
automatic_install() {
    echo "Performing automatic installation..."
    sudo apt update
    sudo apt install -y qemu-guest-agent
    sudo systemctl enable qemu-guest-agent
    echo "qemu-guest-agent service enabled to autostart."
    echo "Rebooting the system..."
    sudo reboot
}

# Function for manual installation
manual_install() {
    echo "Updating package list..."
    sudo apt update

    echo "Installing qemu-guest-agent..."
    sudo apt install -y qemu-guest-agent

    read -p "Are you sure you want to set qemu-guest-agent to autostart? (y/n): " confirm
    if [[ $confirm == [Yy]* ]]; then
        sudo systemctl enable qemu-guest-agent
        echo "qemu-guest-agent service enabled to autostart."
    else
        echo "Autostart not enabled."
    fi

    read -p "Do you want to reboot the system now? (y/n): " reboot
    if [[ $reboot == [Yy]* ]]; then
        echo "Rebooting the system..."
        sudo reboot
    else
        echo "System will not be rebooted."
    fi
}

# Ask user if they want automatic or manual installation
read -p "Do you want to bypass all prompts and perform an automatic installation? (y/n): " auto_install
if [[ $auto_install == [Yy]* ]]; then
    automatic_install
else
    manual_install
fi