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

echo speedtest
sudo apt-get install curl
curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
sudo apt-get install speedtest -y

echo gping https://github.com/orf/gping

echo "deb http://packages.azlux.fr/debian/ buster main" | sudo tee /etc/apt/sources.list.d/azlux.list
wget -qO - https://azlux.fr/repo.gpg.key | sudo apt-key add -
sudo apt update
sudo apt install gping -y