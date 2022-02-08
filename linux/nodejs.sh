#!/bin/sh

# install nvm, node, npm
 curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash # Install nvm
 export NVM_DIR="$HOME/.nvm" # add NVM to the path
 [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
 [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # this loads bash completion for nvm
 nvm install --lts # install latest node LTS module