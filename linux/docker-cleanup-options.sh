#!/usr/bin/env bash

# Exit on errors, undefined variables, and failed pipes.
set -euo pipefail

# This script provides a simple menu for Docker cleanup tasks.
# It is intended for cases where you want to choose what gets removed.

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
    # Print Docker disk usage so the user can decide what to remove.
    docker_cmd system df || true
}

pause() {
    # Pause so the menu does not immediately redraw after an action.
    read -r -p "Press Enter to continue..."
}

confirm() {
    # Ask for confirmation before running a cleanup step.
    local prompt="${1:-Are you sure?}"
    read -r -p "$prompt [y/N]: " reply
    case "$reply" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cleanup_stopped_containers() {
    echo
    echo "Removing stopped containers..."
    docker_cmd container prune --force
}

cleanup_dangling_images() {
    echo
    echo "Removing dangling images only..."
    docker_cmd image prune --force
}

cleanup_unused_images() {
    echo
    echo "Removing all unused images..."
    docker_cmd image prune --all --force
}

cleanup_unused_networks() {
    echo
    echo "Removing unused networks..."
    docker_cmd network prune --force
}

cleanup_build_cache() {
    echo
    echo "Removing unused build cache..."
    docker_cmd builder prune --force
}

cleanup_unused_volumes() {
    echo
    echo "Removing unused volumes..."
    docker_cmd volume prune --force
}

cleanup_standard() {
    echo
    echo "Running standard cleanup..."
    echo "This removes stopped containers, unused networks, dangling images, and build cache."
    docker_cmd container prune --force
    docker_cmd network prune --force
    docker_cmd image prune --force
    docker_cmd builder prune --force
}

cleanup_aggressive() {
    echo
    echo "Running aggressive cleanup..."
    echo "This removes all unused images and volumes in addition to standard cleanup."
    docker_cmd system prune --all --force --volumes
}

print_menu() {
    cat <<'EOF'

Docker Cleanup Menu
1. Show Docker disk usage
2. Remove stopped containers
3. Remove dangling images
4. Remove all unused images
5. Remove unused networks
6. Remove build cache
7. Remove unused volumes
8. Run standard cleanup
9. Run aggressive cleanup
0. Exit

EOF
}

handle_choice() {
    local choice="$1"

    case "$choice" in
        1)
            echo
            show_disk_usage
            ;;
        2)
            if confirm "Remove stopped containers?"; then
                cleanup_stopped_containers
            fi
            ;;
        3)
            if confirm "Remove dangling images?"; then
                cleanup_dangling_images
            fi
            ;;
        4)
            if confirm "Remove all unused images?"; then
                cleanup_unused_images
            fi
            ;;
        5)
            if confirm "Remove unused networks?"; then
                cleanup_unused_networks
            fi
            ;;
        6)
            if confirm "Remove build cache?"; then
                cleanup_build_cache
            fi
            ;;
        7)
            if confirm "Remove unused volumes?"; then
                cleanup_unused_volumes
            fi
            ;;
        8)
            if confirm "Run standard Docker cleanup?"; then
                cleanup_standard
            fi
            ;;
        9)
            if confirm "Run aggressive Docker cleanup?"; then
                cleanup_aggressive
            fi
            ;;
        0)
            echo
            echo "Exiting $SCRIPT_NAME."
            exit 0
            ;;
        *)
            echo
            echo "Invalid option: $choice"
            ;;
    esac
}

main() {
    require_command

    while true; do
        print_menu
        read -r -p "Select an option: " choice
        handle_choice "$choice"
        pause
    done
}

main "$@"
