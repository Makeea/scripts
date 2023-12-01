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

# install GNOME
sudo apt install ubuntu-desktop -y

# Setting Up LightDM
sudo apt install -y lightdm
sudo systemctl start lightdm.service
sudo service ligthdm start
