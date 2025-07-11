#!/bin/bash

# Stop the VNC server service for the current user
sudo systemctl stop vncserver@$(whoami)

# Disable the VNC server service
sudo systemctl disable vncserver@$(whoami)

# Remove the VNC server packages
sudo apt remove -y tigervnc-standalone-server tigervnc-common

# Remove XFCE4 desktop environment if it was installed specifically for VNC
sudo apt remove -y xfce4 xfce4-goodies

# Remove VNC configuration files from the user's home directory
rm -rf ~/.vnc

# Remove the systemd service file for the VNC server
sudo rm -f /etc/systemd/system/vncserver@.service

# Reload systemd daemon to apply the changes
sudo systemctl daemon-reload

# Optionally purge packages and clean up
sudo apt purge -y tigervnc-standalone-server tigervnc-common xfce4 xfce4-goodies
sudo apt autoremove -y
sudo apt clean

echo "VNC Server has been successfully removed."
