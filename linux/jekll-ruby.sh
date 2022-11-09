#!/bin/sh
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-add-repository ppa:brightbox/ruby-ng
sudo apt-get update -y

cd $HOME
sudo apt-get update -y 
sudo apt install curl -y
curl -sL <https://deb.nodesource.com/setup_19.x> | sudo -E bash -
curl -sS <https://dl.yarnpkg.com/debian/pubkey.gpg> | sudo apt-key add -
echo "deb <https://dl.yarnpkg.com/debian/> stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update -y
sudo apt-get install -y git-core zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs yarn

cd
git clone <https://github.com/rbenv/rbenv.git> ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
exec $SHELL

git clone <https://github.com/rbenv/ruby-build.git> ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
exec $SHELL

rbenv install 3.0.1
rbenv global 3.0.1
ruby -v

gem update
gem install jekyll bundle
bundle add webrick

## bundle add webrick
## config from https://levelup.gitconnected.com/how-to-install-jekyll-on-wsl-2-13c3b285d513