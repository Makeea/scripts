#!/bin/sh

# install nvm, node, npm
 curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash # Install nvm
  export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
source ~/.bashrc
 nvm install --lts # install latest node LTS module



nvm install node 16
nvm use node 16
#Check Node Ver
 nvm --version
 npm -version
 nvm current