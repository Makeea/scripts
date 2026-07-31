#!/bin/sh

# Script Description:
# This script installs Jekyll on Ubuntu. It installs Ruby and the necessary build tools,
# configures the environment for Ruby Gems, and then installs Jekyll and Bundler.

# Display the purpose of the script
echo "Jekyll on Ubuntu"
echo "Installing Ruby and other prerequisites"

# Install Ruby and build essentials
sudo apt install -y ruby-full build-essential zlib1g-dev

# Configure Ruby Gems to install in the user's home directory
echo "Configuring Ruby Gems..."
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc

# Reload .bashrc to apply changes
source ~/.bashrc

# Install Jekyll and Bundler
echo "Finally, install Jekyll and Bundler:"
gem install jekyll bundler

# Bundler is already installed globally, so the following line is redundant and can be removed.
# sudo gem install bundler

# Create a new Jekyll site
echo "Creating a new Jekyll site..."
jekyll new site
cd site

# Serve the Jekyll site with live reload
echo "Serving Jekyll site with live reload..."
bundle exec jekyll serve --livereload

# The following line serves the site on a specific host. 
# This is useful if you want your Jekyll site to be accessible on your local network.
# Replace '192.168.3.11' with your actual network IP if needed.
# bundle exec jekyll serve --host 192.168.3.11 --livereload
