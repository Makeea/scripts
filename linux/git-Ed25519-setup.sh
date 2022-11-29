#!/bin/sh

#Note: If you are using a legacy system that doesn't support the Ed25519 algorithm

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

echo This creates a new SSH key, using the provided email as a label.
ssh-keygen -t ed25519 -C "$email"

echo Start the ssh-agent in the background.
eval "$(ssh-agent -s)"

echo Adding your SSH private key to the ssh-agent
ssh-add ~/.ssh/id_ed25519


# config git
git config --global user.name "$name" # update github name
git config --global user.email "$email" # use your github email
git config --global init.defaultBranch main # change git main branch to, main
git config --global core.editor "code --wait" # set VS Code as default git editor

echo  Run cat ~/.ssh/id_rsa.pub to get your key. 
cat ~/.ssh/id_ed25519.pub
echo  Then select and copy the contents of the id_ed25519.pub file
echo  Displayed in the terminal to your clipboard 
echo  Need help visit https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account