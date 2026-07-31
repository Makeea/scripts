#!/bin/sh

# Script Description:
# This script is designed for WSL with Ubuntu. It updates and upgrades the system, 
# installs Jekyll, and sets up a new Jekyll blog. Additionally, it gives the user 
# an option to create shortcuts in bash for easy blog management.

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update -y && sudo apt upgrade -y

# Remove certain packages (if previously installed)
echo "Removing certain previously installed packages..."
sudo apt purge -y make gcc gpp zlib1g ruby-dev dh-autoreconf
sudo apt purge -y ruby-full build-essential zlib1g-dev

# Configure Ruby Gems environment variables
echo "Configuring Ruby Gems environment..."
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Jekyll
echo "Installing Jekyll..."
sudo apt install -y jekyll

# Update Ruby gems
echo "Updating Ruby gems..."
sudo gem update

# Install Bundler
echo "Installing Bundler..."
sudo gem install bundler

# Create a new Jekyll blog
echo "Creating a new Jekyll blog..."
Jekyll new my_blog
cd my_blog

# Serve the Jekyll blog with live reload
echo "Serving the Jekyll blog with live reload..."
bundle exec jekyll serve --livereload

# Ask the user if they want to create shortcuts
echo "Do you want to create bash shortcuts for managing your Jekyll blog? [y/N]"
read CREATE_SHORTCUTS

if [ "$CREATE_SHORTCUTS" = "y" ] || [ "$CREATE_SHORTCUTS" = "Y" ]; then
    echo "Creating bash shortcuts..."

    # Shortcut for serving the blog
    echo "alias serveblog='cd ~/my_blog && bundle exec jekyll serve --livereload'" >> ~/.bashrc

    # Other useful shortcuts can be added here

    echo "Shortcuts created. Please restart your terminal or run 'source ~/.bashrc' to use them."
else
    echo "No shortcuts created."
fi

echo "Jekyll blog setup completed."
