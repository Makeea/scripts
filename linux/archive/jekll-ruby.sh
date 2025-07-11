#!/bin/sh

# Script Description:
# This script updates the system, installs necessary dependencies for Ruby, Node.js, and Yarn,
# and sets up Ruby using rbenv. It then installs the latest stable version of Ruby and Jekyll.

# Update and upgrade system packages
sudo apt-get update -y && sudo apt-get upgrade -y

# Install dependencies for building Ruby and other essential tools
sudo apt-get install -y git-core zlib1g-dev build-essential libssl-dev libreadline-dev \
libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev \
software-properties-common libffi-dev nodejs yarn

# Install rbenv for managing Ruby versions
cd $HOME
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
exec $SHELL

# Install ruby-build as a rbenv plugin, this provides the `rbenv install` command
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
exec $SHELL

# Install the latest stable version of Ruby
rbenv install 3.1.2 # As of my last update, 3.1.2 is the latest stable version
rbenv global 3.1.2
ruby -v

# Update RubyGems and install Jekyll and Bundler
gem update --system
gem install jekyll bundler

# Webrick is included with Ruby 3.0 and later
# If needed for older versions, uncomment the following line:
# bundle add webrick

# Install Node.js and Yarn (for JavaScript runtime and package management)
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash - # Using LTS version of Node.js
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update -y
sudo apt-get install -y nodejs yarn

echo "Ruby and Jekyll installation completed."
