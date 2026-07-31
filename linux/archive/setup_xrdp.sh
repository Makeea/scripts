#!/bin/bash

# Update the package list
sudo apt update

# Install XRDP
sudo apt install -y xrdp

# Install XFCE4 desktop environment
sudo apt install -y xfce4

# Add xrdp user to the ssl-cert group
sudo adduser xrdp ssl-cert

# Create .xsession file
echo xfce4-session > ~/.xsession

# Edit the xrdp start script
sudo bash -c 'echo "startxfce4" >> /etc/xrdp/startwm.sh'

# Restart XRDP service
sudo systemctl restart xrdp

# Enable XRDP to start on boot
sudo systemctl enable xrdp

# Allow XRDP through the firewall (if UFW is enabled)
sudo ufw allow 3389/tcp

# Print the IP address of the machine
echo "Setup complete. You can now connect to this machine using Remote Desktop."
echo "Your IP address is:"
ip a | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1
