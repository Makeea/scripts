#!/bin/sh

sudo apt update -y && sudo apt upgrade -y


sudo apt purge  -y make gcc gpp zlib1g ruby-dev dh-autoreconf
sudo apt purge  -y ruby-full build-essential zlib1g-dev

echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
sudo apt install -y jekyll
sudo gem update

sudo gem install bundler
jekyll new myblog
cd myblog
bundle exec jekyll serve --livereload

