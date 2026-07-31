#!/bin/sh

# Script Description:
# This script performs the following tasks on a Debian-based system:
# 1. Update and upgrade the system packages.
# 2. Install and start Docker, a platform for developing and running applications in containers.
# 3. Install Portainer, a tool for managing container environments like Docker.

# Updating and Upgrading the System

# Update the package lists for upgrades and new package installations
sudo apt update -y # Automatically answers 'yes' to prompts

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

# Display the status of the Docker service
# This step is optional and can be commented out for a non-interactive script execution
sudo systemctl status docker

# Installing Portainer

# Run Portainer as a Docker container
sudo docker run -d \
  --name="portainer" \
  --restart on-failure \
  -p 9000:9000 \
  -p 8000:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "System update, Docker installation, and Portainer setup completed."
