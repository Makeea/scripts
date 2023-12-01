#!/bin/sh

# Uninstall GNOME
sudo apt autoremove ubuntu-desktop


# Uninstall LightDM
sudo systemctl stop lightdm.service
sudo apt autoremove lightdm

sudo apt autoremove -y