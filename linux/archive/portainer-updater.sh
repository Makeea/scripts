#!/bin/sh

# Script Description:
# This script updates Portainer to the latest version while preserving its configurations.
# It lists the running Docker containers, stops and removes the current Portainer container, 
# pulls the latest Portainer image, and then creates a new Portainer container 
# with the same configuration and persistent data.

# List currently running Docker containers
echo "Checking current Docker containers..."
sudo docker container ls

# Stop the Portainer container
echo "Stopping the Portainer container..."
sudo docker stop portainer

# Remove the Portainer container
# This does not remove the Portainer configuration as it is stored in a Docker volume
echo "Removing the Portainer container..."
sudo docker rm portainer

# Pull the latest Portainer image
echo "Pulling the latest Portainer image..."
sudo docker pull portainer/portainer-ce:latest

# Install (run) the latest Portainer image
# -v /var/run/docker.sock:/var/run/docker.sock: Mount the Docker socket for container management
# -v portainer_data:/data: Mount the existing volume 'portainer_data' to preserve Portainer configurations
echo "Installing the latest Portainer version..."
sudo docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  -p 9443:9443 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# List updated Docker containers
echo "Updated Docker containers:"
sudo docker container ls
