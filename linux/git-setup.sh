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

# config git
git config --global user.name "$name" # update github name
git config --global user.email "$email" # use your github email
git config --global init.defaultBranch main # change git main branch to, main
git config --global core.editor "code --wait" # set VS Code as default git editor