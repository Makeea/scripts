#!/usr/bin/env bash

# Title: Git & SSH Setup Script
# Description: Configures Git and sets up SSH for GitHub connectivity

# Exit immediately if a command exits with a non-zero status
set -e

# Clear the terminal screen
clear 

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
  echo -e "\n${GREEN}$1${NC}\n"
}

print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Check if git is installed
if ! command -v git &> /dev/null; then
  print_error "Git is not installed. Please install git first."
  exit 1
fi

print_header "Git & SSH Setup Script"

# Get stored values if they exist
DEFAULT_NAME=$(git config --global user.name || echo "")
DEFAULT_EMAIL=$(git config --global user.email || echo "")

# Prompt the user to enter their full name and email for Git configuration
echo "Please enter your full name for git [${DEFAULT_NAME}]:"
read -r name
name=${name:-$DEFAULT_NAME}

echo "Please enter the email you wish to use with git [${DEFAULT_EMAIL}]:"
read -r email
email=${email:-$DEFAULT_EMAIL}

# Check if the name and email variables are empty. If they are, exit the script.
if [ -z "$name" ] || [ -z "$email" ]; then
  print_error "Name and email are required."
  exit 1
fi

# Display the entered name and email back to the user for confirmation
echo 
echo "Name: $name"
echo "E-mail: $email"
echo 
echo "Are you sure this is all correct and you wish to proceed? [y/N]:"
read -r REPLY

# If the user does not confirm, exit the script
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  print_warning "Aborting..."
  exit 0
fi

print_header "Configuring Git"

# Configure user's name and email for Git
git config --global user.name "$name"
git config --global user.email "$email"
# Set the default Git branch name to 'main'
git config --global init.defaultBranch main
# Set the default editor for Git (use the user's preferred editor if set)
EDITOR=${EDITOR:-nano}
git config --global core.editor "$EDITOR"

# Add more useful Git configurations
git config --global pull.rebase false
git config --global core.autocrlf input

print_header "Setting up SSH key"

SSH_KEY_FILE="$HOME/.ssh/id_ed25519"

# Check if an SSH key already exists
if [ -f "${SSH_KEY_FILE}.pub" ]; then
  print_warning "SSH key already exists. Do you want to overwrite it? [y/N]:"
  read -r OVERWRITE

  # If the user does not want to overwrite the existing key, use the existing one
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    print_warning "Using existing key..."
  else
    # If the user wants to overwrite, generate a new SSH key with customizable bits
    print_header "Creating a new SSH key..."
    ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_FILE"
  fi
else
  # If no SSH key exists, create a new one
  print_header "Creating a new SSH key..."
  # Ensure .ssh directory exists with proper permissions
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_FILE"
fi

# Start the ssh-agent in the background
print_header "Starting SSH agent"
eval "$(ssh-agent -s)"

# Create/update SSH config file to automatically load keys and keep connections alive
SSH_CONFIG="$HOME/.ssh/config"
if [ ! -f "$SSH_CONFIG" ]; then
  echo "# SSH configuration file" > "$SSH_CONFIG"
  echo "Host github.com" >> "$SSH_CONFIG"
  echo "  AddKeysToAgent yes" >> "$SSH_CONFIG"
  echo "  IdentityFile $SSH_KEY_FILE" >> "$SSH_CONFIG"
  echo "  ServerAliveInterval 60" >> "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

# Add the generated SSH private key to the ssh-agent
ssh-add "$SSH_KEY_FILE"

# Display the generated SSH public key
print_header "Your SSH public key:"
cat "${SSH_KEY_FILE}.pub"
echo

# Check for common clipboard commands and provide appropriate instructions
if command -v pbcopy &> /dev/null; then
  # macOS
  cat "${SSH_KEY_FILE}.pub" | pbcopy
  print_warning "The SSH key has been copied to your clipboard."
elif command -v xclip &> /dev/null; then
  # Linux with xclip
  cat "${SSH_KEY_FILE}.pub" | xclip -selection clipboard
  print_warning "The SSH key has been copied to your clipboard."
elif command -v clip.exe &> /dev/null; then
  # Windows with clip.exe (WSL)
  cat "${SSH_KEY_FILE}.pub" | clip.exe
  print_warning "The SSH key has been copied to your clipboard."
else
  print_warning "Please manually copy the SSH key above to your clipboard."
fi

# Provide links for further help
echo
print_warning "Add this key to your GitHub account:"
echo "https://github.com/settings/ssh/new"
echo
echo "For help, visit: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"

# Test the SSH connection to GitHub
print_header "Would you like to test the SSH connection to GitHub? [y/N]:"
read -r TEST_CONNECTION

if [[ "$TEST_CONNECTION" =~ ^[Yy]$ ]]; then
  echo "Testing connection to GitHub..."
  if ssh -T git@github.com -o StrictHostKeyChecking=accept-new; then
    print_header "Connection successful! Your SSH key is working correctly."
  else
    status=$?
    if [ $status -eq 1 ]; then
      # Exit code 1 is actually expected from GitHub's SSH response
      print_header "Connection successful! Your SSH key is working correctly."
    else
      print_error "Connection failed with exit code $status. Please check your configuration."
    fi
  fi
fi

print_header "Git & SSH setup completed successfully!"
echo "Your git configuration:"
git config --global --list | grep -E 'user.name|user.email|init.defaultBranch|core.editor'