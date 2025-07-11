#!/bin/sh

# Uninstall and then reinstall System Settings (unity-control-center) from the Ubuntu Software Center application.

# uninstall control center aka settings on ubuntu desktop
sudo apt remove unity-control-center -y

# update Ubuntu
sudo apt update -y # update the package versions
sudo apt upgrade -y # upgrade installed packages to new versions if was found
apt list --upgradable
sudo apt list --upgradable
sudo apt autoremove -y

# Update System

sudo apt update
sudo apt upgrade

# reinstall unity-control-center

sudo apt install unity-control-center -y

sudo reboot
