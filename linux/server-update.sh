#!/bin/sh

# update the system

# update Ubuntu
sudo apt update # update the package versions
sudo apt upgrade -y # upgrade installed packages to new versions if was found

apt list --upgradable
sudo apt list --upgradable
sudo apt autoremove -y
sudo apt upgrade -y
sudo apt update -y

apt list --upgradable
sudo apt list --upgradable
sudo apt autoremove -y
sudo apt upgrade -y
sudo apt update -y

sudo apt autoremove -y
sudo apt upgrade -y
sudo apt update -y