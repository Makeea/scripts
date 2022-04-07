#!/bin/sh

echo Jekyll on Ubuntu
echo Installing Ruby and other prerequisites
sudo apt install -y ruby-full build-essential zlib1g-dev

echo Avoid installing RubyGems packages (called gems) as the root user. Instead, set up a gem installation directory for your user account. The following commands will add environment variables to your ~/.bashrc file to configure the gem installation path:

echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

echo Finally, install Jekyll and Bundler:
gem install jekyll bundler

echo Yay Jekyll is ready
echo bundle exec jekyll serve --livereload is the cmd to start server
echo "Would you like to start the server with demo [yN]:"

sudo gem install bundler
jekyll new new-site
cd new-site
bundle exec jekyll serve --livereload
