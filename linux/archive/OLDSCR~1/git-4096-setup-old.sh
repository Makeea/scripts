#!/bin/sh

# Clearing the screen for better readability of the script output
clear 

# Prompting the user for their full name and email for Git configuration
echo "Please enter your full name for Git:"
read name
echo "Please enter the email you wish to use with Git:"
read email

# Validating the provided name and email inputs
echo "Name: $name"
echo "E-mail: $email"
echo "Are you sure this is all correct and you wish to proceed? [y/N]:"
read REPLY

# Exit the script if the user does not confirm
if [ "$REPLY" != "y" ]; then
  echo "Aborting..."
  exit 1
fi

# Generating a new SSH key using RSA algorithm
# Note: RSA is used here for broader compatibility with legacy systems
echo "Creating a new SSH key, using the provided email as a label..."
ssh-keygen -t rsa -b 4096 -C "$email"

# Uncomment the following lines if you are not using the default key name 'id_rsa'
# Start the ssh-agent in the background
# eval "$(ssh-agent -s)"

# Add the newly created SSH private key to the ssh-agent
# ssh-add ~/.ssh/id_rsa

# Configuring Git with the user's name and email
echo "Configuring Git with your details..."
git config --global user.name "$name" # Set the global Git username
git config --global user.email "$email" # Set the global Git email
git config --global init.defaultBranch main # Set the default branch name to 'main'
git config --global core.editor "code --wait" # Set Visual Studio Code as the default Git editor

# Displaying instructions for adding the SSH key to GitHub
echo "Your SSH public key is:"
cat ~/.ssh/id_rsa.pub
echo
echo "Select and copy the contents of the id_rsa.pub file displayed in the terminal to your clipboard."
echo "For assistance in adding this key to your GitHub account, visit:"
echo "https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"

echo "Script completed successfully."
