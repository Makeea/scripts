#!/bin/sh

# Downloading the latest version of Google Chrome
# The wget command retrieves the .deb package from Google's website
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Installing Google Chrome
# The dpkg command is used to install .deb packages
# sudo is used to ensure the installation has the necessary permissions
sudo dpkg -i google-chrome-stable_current_amd64.deb

# Handling possible missing dependencies
# Sometimes dpkg might not handle dependencies automatically, so we use apt-get to fix any missing dependencies
sudo apt-get install -f

# Removing the downloaded .deb package to free up space
# This step cleans up the installation file as it's no longer needed after installation
rm google-chrome-stable_current_amd64.deb

# Displaying completion message
echo "Google Chrome installation completed."
