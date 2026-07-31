#!/bin/sh

# update the system

# update Ubuntu
sudo apt update -y # update the package versions
sudo apt upgrade -y # upgrade installed packages to new versions if was found
apt list --upgradable
sudo apt list --upgradable
sudo apt autoremove -y

# Update System

sudo apt update
sudo apt upgrade

# Now Install Portainer

sudo docker run -d \
--name="portainer" \
--restart on-failure \
-p 9000:9000 \
-p 8000:8000 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer-ce:latest
