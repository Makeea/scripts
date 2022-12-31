#!/bin/sh

#Uninstall old versions
sudo apt remove docker docker-engine docker.io containerd runc -y


## Set up the repository
sudo apt update -y
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common  \
    apt-transport-https -y

# Add Docker’s official GPG key:
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

#Use the following command to set up the repository:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine

sudo apt update -y

sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

sudo apt-get install docker-compose-plugin -y
sudo apt install docker-compose -y

sudo docker run hello-world
docker compose version


## Docker Engine post-installation steps

# Create the docker group.
sudo groupadd docker

# Add your user to the docker group.
sudo usermod -aG docker $USER

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# make docker folder
mkdir ~/docker

sudo reboot