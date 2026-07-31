#!/bin/sh

# Clear the terminal screen
clear 

# Prompt the user to enter their full name and email for Git configuration
echo "Please enter your full name for git:"
read name
echo "Please enter the email you wish to use with git:"
read email

# Check if the name and email variables are empty. If they are, exit the script.
if [ -z "$name" ] || [ -z "$email" ]; then
  echo "Name and email are required."
  exit 1
fi

# Display the entered name and email back to the user for confirmation
echo "Name: $name"
echo "E-mail: $email"
echo "Are you sure this is all correct and you wish to proceed? [y/N]:"
read REPLY

# If the user does not confirm, exit the script
if [ "$REPLY" != "y" ]; then
  echo "Aborting..."
  exit 1
fi

# Check if an SSH key already exists
if [ -f ~/.ssh/id_ed25519.pub ]; then
  echo "SSH key already exists. Do you want to overwrite it? [y/N]:"
  read OVERWRITE

  # If the user does not want to overwrite the existing key, use the existing one
  if [ "$OVERWRITE" != "y" ]; then
    echo "Using existing key..."
  else
    # If the user wants to overwrite, generate a new SSH key
    ssh-keygen -t ed25519 -C "$email"
  fi
else
  # If no SSH key exists, create a new one
  echo "Creating a new SSH key..."
  ssh-keygen -t ed25519 -C "$email"
fi

# Start the ssh-agent in the background
eval "$(ssh-agent -s)"

# Add the generated SSH private key to the ssh-agent
ssh-add ~/.ssh/id_ed25519

# Configure user's name and email for Git
git config --global user.name "$name"
git config --global user.email "$email"
# Set the default Git branch name to 'main'
git config --global init.defaultBranch main
# Set the default editor for Git to 'nano' (or change it to your preferred editor)
git config --global core.editor "nano"

# Display the generated SSH public key
echo "Your SSH public key is:"
cat ~/.ssh/id_ed25519.pub
echo
# Instructions for copying the SSH key to the clipboard
echo "Copy the above key to your clipboard and add it to your GitHub account."
# Provide a link for further help
echo "For help, visit https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"

# Confirmation message indicating the script has completed successfully
echo "Script completed successfully."