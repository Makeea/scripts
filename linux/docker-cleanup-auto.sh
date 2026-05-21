#!/usr/bin/env bash

# Exit on errors, undefined variables, and failed pipes.
set -euo pipefail

# This script runs a full Docker cleanup without prompting for each prune step.
# It removes:
# - stopped containers
# - unused networks
# - unused images
# - unused build cache
# - unused volumes

SCRIPT_NAME="$(basename "$0")"

require_command() {
    # Fail early if Docker is not installed.
    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: docker is not installed or not in PATH."
        exit 1
    fi
}

docker_cmd() {
    # Use Docker directly when possible. Fall back to sudo when needed.
    if docker info >/dev/null 2>&1; then
        docker "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo docker "$@"
    else
        echo "Error: docker requires elevated privileges and sudo is not available."
        exit 1
    fi
}

show_disk_usage() {
    # Print Docker disk usage so the user can see what changed.
    docker_cmd system df || true
}

show_free_space() {
    # Print host filesystem free space before and after cleanup.
    df -h /
}

main() {
    require_command

    echo "[$SCRIPT_NAME] Host free space before cleanup:"
    show_free_space
    echo
    echo "[$SCRIPT_NAME] Docker disk usage before cleanup:"
    show_disk_usage
    echo
    echo "[$SCRIPT_NAME] Running automatic Docker cleanup..."

    # Remove everything Docker reports as unused, including volumes.
    docker_cmd system prune --all --force --volumes

    echo
    echo "[$SCRIPT_NAME] Docker disk usage after cleanup:"
    show_disk_usage
    echo
    echo "[$SCRIPT_NAME] Host free space after cleanup:"
    show_free_space
    echo
    echo "[$SCRIPT_NAME] Cleanup complete."
}

main "$@"
