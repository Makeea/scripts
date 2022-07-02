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

# Install Docker

sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
