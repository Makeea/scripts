#!/bin/bash

# Script Description:
# This script installs the latest Docker Engine and Docker Compose on Ubuntu,
# performs required setup steps, creates Docker-related folders,
# and optionally reboots the system.

# Uninstall old Docker packages if they exist
sudo apt remove -y docker docker-engine docker.io containerd runc

# Update the package list
sudo apt update -y

# Install required dependencies for Docker installation
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https

# Create the directory for Docker GPG key if it doesn't exist
sudo mkdir -p /etc/apt/keyrings

# Download and overwrite Docker’s official GPG key silently
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /tmp/docker.gpg
sudo mv -f /tmp/docker.gpg /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository to APT sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list again with the Docker repo included
sudo apt update -y

# Install Docker Engine, CLI, containerd, and Docker Compose plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install latest Docker Compose standalone binary
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Confirm Docker installation
docker --version
docker compose version
docker-compose version

# Create Docker group if it doesn't exist
sudo groupadd docker 2>/dev/null || true

# Add the current user to the Docker group
sudo usermod -aG docker "$USER"

# Enable Docker services to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Create directories for local Docker use
mkdir -p "$HOME/docker-data"
mkdir -p "$HOME/docker-compose"

# Inform the user and ask for reboot
echo "Docker installation and setup is complete."
echo "You must reboot to apply group membership changes."
echo "Reboot now? (y/N)"
read REBOOT_CONFIRM

if [ "$REBOOT_CONFIRM" = "y" ] || [ "$REBOOT_CONFIRM" = "Y" ]; then
    sudo reboot
else
    echo "Reboot skipped. Please reboot manually for all changes to take effect."
fi
