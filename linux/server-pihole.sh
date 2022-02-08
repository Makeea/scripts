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

pihole -up

sudo apt autoremove -y
sudo apt upgrade -y
sudo apt update -y
