#!/bin/bash

# Stop the XRDP service
sudo systemctl stop xrdp

# Disable the XRDP service
sudo systemctl disable xrdp

# Remove XRDP package
sudo apt remove -y xrdp

# Remove XFCE4 desktop environment if it was installed specifically for XRDP
sudo apt remove -y xfce4

# Remove XRDP user from ssl-cert group
sudo deluser xrdp ssl-cert

# Remove XRDP configuration files
sudo rm -rf /etc/xrdp

# Remove .xsession file from user's home directory
rm -f ~/.xsession

# Optionally purge packages and clean up
sudo apt purge -y xrdp xfce4
sudo apt autoremove -y
sudo apt clean

echo "XRDP has been successfully removed."
