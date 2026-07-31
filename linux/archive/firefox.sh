#!/bin/sh

# Script Description:
# This script removes the snap version of Firefox, adds the Mozilla Team's Personal Package Archive (PPA) for Firefox,
# sets up package pinning and unattended upgrades for Firefox from this PPA, and then installs the latest version of Firefox.

# Remove the snap version of Firefox
sudo snap remove firefox 

# Add the Mozilla Team PPA
# This PPA provides the latest stable releases of Firefox
sudo add-apt-repository ppa:mozillateam/ppa -y

# Configure package pinning for the Mozilla Firefox package
# This ensures that the package from this PPA is prioritized over other sources
echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox

# Configure unattended upgrades for Firefox from the Mozilla Team PPA
# This allows Firefox to be automatically upgraded when new versions are available in the PPA
echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

# Update package lists
sudo apt update -y

# Install Firefox from the newly added PPA
sudo apt install firefox -y
