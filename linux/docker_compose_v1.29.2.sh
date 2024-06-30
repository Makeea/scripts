#!/bin/bash

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        exit 1
    fi
}

# Function to install or update Docker Compose to version 3
install_update_docker_compose_v3() {
    # Define the Docker Compose v3 version
    DOCKER_COMPOSE_VERSION="1.29.2"  # v3 format starts from this version

    # Download the specified version of Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # Apply executable permissions to the binary
    sudo chmod +x /usr/local/bin/docker-compose

    # Verify installation
    if command -v docker-compose &> /dev/null; then
        echo "Docker Compose installed/updated to version ${DOCKER_COMPOSE_VERSION} successfully."
    else
        echo "Docker Compose installation/update failed."
        exit 1
    fi
}

# Function to add Docker Compose to the user's PATH if necessary
ensure_path() {
    if ! grep -q '/usr/local/bin' <<< "$PATH"; then
        echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
        source ~/.bashrc
    fi
}

# Function to display Docker Compose version
display_docker_compose_version() {
    if command -v docker-compose &> /dev/null; then
        docker-compose --version
    else
        echo "Docker Compose is not installed."
    fi
}

# Check if Docker is installed
check_docker

# Install or update Docker Compose to version 3
install_update_docker_compose_v3

# Ensure Docker Compose is in the user's PATH
ensure_path

# Display Docker Compose version
display_docker_compose_version
