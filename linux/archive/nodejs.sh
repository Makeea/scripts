#!/bin/sh

# Script Description:
# This script installs NVM (Node Version Manager) and then allows the user to choose 
# a specific version of Node.js to install and use.

# Install NVM (Node Version Manager)
echo "Installing NVM (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Set up NVM environment variables
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Reload .bashrc to apply NVM settings
source ~/.bashrc

# Install the latest Node LTS (Long Term Support) version
echo "Installing the latest Node.js LTS version..."
nvm install --lts

# Prompt the user for a specific Node.js version to install
echo "Enter the Node.js version you wish to install (e.g., '16', '14.17.0'): "
read NODE_VERSION

# Install and use the user-specified version of Node.js
nvm install $NODE_VERSION
nvm use $NODE_VERSION

# Display the installed versions of NVM, Node.js, and NPM
echo "NVM version:"
nvm --version

echo "Node.js version:"
node --version

echo "NPM version:"
npm -version

echo "Current Node.js version in use:"
nvm current
