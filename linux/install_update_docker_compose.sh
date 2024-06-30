#!/bin/bash

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        exit 1
    fi
}

# Function to install or update Docker Compose
install_update_docker_compose() {
    # Get the latest release version of Docker Compose
    LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)

    # Download the latest version of Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # Apply executable permissions to the binary
    sudo chmod +x /usr/local/bin/docker-compose

    # Verify installation
    if command -v docker-compose &> /dev/null; then
        echo "Docker Compose $(docker-compose --version) is installed/updated successfully."
    else
        echo "Docker Compose installation/update failed."
    fi
}

# Function to add Docker Compose to the user's PATH if necessary
ensure_path() {
    if ! grep -q '/usr/local/bin' <<< "$PATH"; then
        echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
        source ~/.bashrc
    fi
}

# Check if Docker is installed
check_docker

# Install or update Docker Compose
install_update_docker_compose

# Ensure Docker Compose is in the user's PATH
ensure_path
