#!/bin/sh

echo
clear # clear the screen
# gather info
echo Please enter your full name for git:
read name
echo Please enter the email you wish to use with git:
read email
echo

# validation of user input
echo name: $name
echo e-mail: $email
echo "Are you sure this is all correct and you wish to proceed? [yN]:"
read REPLY

# Check if the reply is "y" or "Y"
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    # if it is...
    echo No changes made, try again
    rm ~/update-and-setup.sh # remove this script
    exit 1 #  exit the script with status code 1, and error
fi

# config git
git config --global user.name "$name" # update github name
git config --global user.email "$email" # use your github email
git config --global init.defaultBranch main # change git main branch to, main
git config --global core.editor "code --wait" # set VS Code as default git editor

# install nvm, node, npm
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash # Install nvm
# export NVM_DIR="$HOME/.nvm" # add NVM to the path
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # this loads bash completion for nvm
# nvm install --lts # install latest node LTS module