#!/bin/sh

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


sudo apt install qemu-guest-agent

sudo systemctl enable qemu-guest-agent