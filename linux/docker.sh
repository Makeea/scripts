#!/bin/sh

# Script Description:
# This script uninstalls old versions of Docker, sets up the Docker repository,
# installs the latest version of Docker and docker-compose-plugin,
# and performs post-installation steps including user configuration.
# It then prompts the user before rebooting the system.

# Uninstall old versions of Docker
sudo apt remove docker docker-engine docker.io containerd runc -y

# Set up the repository for Docker installation
sudo apt update -y
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https -y

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the stable repository for Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine, CLI, Containerd, and Docker Compose Plugin
sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# The docker-compose-plugin is the integrated version of Docker Compose as part of Docker.
# If you specifically need the standalone Docker Compose, uncomment the following line:
# sudo apt install docker-compose -y

# Test Docker installation by running a hello-world container
sudo docker run hello-world

# Display Docker Compose version
docker compose version

# Docker Engine post-installation steps

# Create the docker group if it doesn't already exist
sudo groupadd docker || true

# Add your user to the docker group
sudo usermod -aG docker $USER

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Create a Docker directory in the user's home directory
mkdir -p ~/docker

# Prompt the user before rebooting
echo "The system needs to reboot to apply changes. Reboot now? (y/N)"
read REBOOT_CONFIRM
if [ "$REBOOT_CONFIRM" = "y" ] || [ "$REBOOT_CONFIRM" = "Y" ]; then
    sudo reboot
else
    echo "Reboot cancelled. Please reboot manually for changes to take effect."
fi
