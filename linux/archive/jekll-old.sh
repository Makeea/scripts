#!/bin/sh

echo Jekyll on Ubuntu
echo Installing Ruby and other prerequisites
sudo apt install -y ruby-full build-essential zlib1g-dev


echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

echo Finally, install Jekyll and Bundler:
gem install jekyll bundler


sudo gem install bundler
jekyll new site
cd site
bundle exec jekyll serve --livereload
bundle exec jekyll serve --host 192.168.3.11 --livereload
