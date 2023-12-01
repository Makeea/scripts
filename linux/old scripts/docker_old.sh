#!/bin/sh

# Script Description:
# This script is designed to perform three main tasks on a Debian-based system (like Ubuntu):
# 1. Update and Upgrade the System: It updates the list of packages and upgrades all installed packages to their latest versions.
# 2. Clean Up Unnecessary Packages: It removes packages that were automatically installed and are no longer needed.
# 3. Install Docker: It installs Docker, a platform for developing, shipping, and running applications in containers.

# Updating and Upgrading the System

# Update the package lists for upgrades and new package installations
sudo apt update -y # '-y' automates 'yes' to prompts

# Upgrade all installed packages to their latest versions
sudo apt upgrade -y

# Cleaning Up Unnecessary Packages

# Remove packages that were automatically installed to satisfy dependencies for other packages and are now no longer needed
sudo apt autoremove -y

# Installing Docker

# Install Docker package
sudo apt install -y docker.io

# Enable Docker service to start on boot
sudo systemctl enable docker

# Start the Docker service
sudo systemctl start docker

# Optionally, you can check the status of the Docker service. Commented out for faster script execution.
# sudo systemctl status docker

echo "System update, cleanup, and Docker installation completed."
