#!/usr/bin/env bash

set -u
set -o pipefail

DEFAULT_BASE_DIR="$HOME/docker-data"

SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
FOUND_COUNT=0

declare -a SUCCESS_PROJECTS=()
declare -a FAILED_PROJECTS=()
declare -a SKIPPED_PROJECTS=()

print_line() {
    printf '%s\n' "=================================================="
}

expand_path() {
    local input_path="$1"

    case "$input_path" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s\n' "$HOME/${input_path#~/}"
            ;;
        *)
            printf '%s\n' "$input_path"
            ;;
    esac
}

check_requirements() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: Docker is not installed or is not in PATH."
        exit 1
    fi

    if ! docker compose version >/dev/null 2>&1; then
        echo "ERROR: Docker Compose v2 is not available."
        echo "Expected command: docker compose"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: Cannot communicate with the Docker daemon."
        echo "Check that Docker is running and that your user has permission."
        exit 1
    fi
}

choose_base_directory() {
    local requested_path="${1:-}"
    local entered_path=""

    if [[ -n "$requested_path" ]]; then
        BASE_DIR="$(expand_path "$requested_path")"
    else
        echo "Docker Compose updater"
        echo
        echo "Enter the folder containing your Docker Compose project folders."
        printf 'Folder [%s]: ' "$DEFAULT_BASE_DIR"
        read -r entered_path

        if [[ -z "$entered_path" ]]; then
            BASE_DIR="$DEFAULT_BASE_DIR"
        else
            BASE_DIR="$(expand_path "$entered_path")"
        fi
    fi

    if [[ ! -d "$BASE_DIR" ]]; then
        echo "ERROR: Folder does not exist:"
        echo "  $BASE_DIR"
        exit 1
    fi

    BASE_DIR="$(cd "$BASE_DIR" && pwd -P)"
}

find_compose_directories() {
    find "$BASE_DIR" \
        -type f \
        \( \
            -name 'compose.yml' -o \
            -name 'compose.yaml' -o \
            -name 'docker-compose.yml' -o \
            -name 'docker-compose.yaml' \
        \) \
        -printf '%h\n' 2>/dev/null |
        sort -u
}

update_project() {
    local project_dir="$1"
    local project_name
    local running_containers

    project_name="$(basename "$project_dir")"

    echo
    print_line
    echo "Project: $project_name"
    echo "Folder:  $project_dir"
    print_line

    if ! cd "$project_dir"; then
        echo "ERROR: Could not enter project folder."
        FAILED_PROJECTS+=("$project_name")
        ((FAILED_COUNT += 1))
        return
    fi

    if ! docker compose config --quiet; then
        echo "ERROR: Invalid Docker Compose configuration."
        FAILED_PROJECTS+=("$project_name")
        ((FAILED_COUNT += 1))
        return
    fi

    running_containers="$(docker compose ps --status running --quiet 2>/dev/null)"

    if [[ -z "$running_containers" ]]; then
        echo "Skipping inactive project."
        SKIPPED_PROJECTS+=("$project_name")
        ((SKIPPED_COUNT += 1))
        return
    fi

    echo "Pulling current images..."

    if ! docker compose pull; then
        echo "ERROR: Image pull failed."
        FAILED_PROJECTS+=("$project_name")
        ((FAILED_COUNT += 1))
        return
    fi

    echo "Recreating the project..."

    if docker compose up -d --remove-orphans; then
        echo "Successfully updated: $project_name"
        SUCCESS_PROJECTS+=("$project_name")
        ((SUCCESS_COUNT += 1))
    else
        echo "ERROR: Failed to recreate project: $project_name"
        FAILED_PROJECTS+=("$project_name")
        ((FAILED_COUNT += 1))
    fi
}

print_summary() {
    echo
    print_line
    echo "UPDATE SUMMARY"
    print_line
    echo "Compose projects found: $FOUND_COUNT"
    echo "Successfully updated:   $SUCCESS_COUNT"
    echo "Skipped because stopped: $SKIPPED_COUNT"
    echo "Failed:                 $FAILED_COUNT"

    if (( SUCCESS_COUNT > 0 )); then
        echo
        echo "Updated projects:"
        printf '  - %s\n' "${SUCCESS_PROJECTS[@]}"
    fi

    if (( SKIPPED_COUNT > 0 )); then
        echo
        echo "Inactive projects:"
        printf '  - %s\n' "${SKIPPED_PROJECTS[@]}"
    fi

    if (( FAILED_COUNT > 0 )); then
        echo
        echo "Failed projects:"
        printf '  - %s\n' "${FAILED_PROJECTS[@]}"
    fi

    echo
    echo "Running containers:"
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

    echo
    echo "Docker Compose projects:"
    docker compose ls --all
}

main() {
    local compose_directories=()

    check_requirements
    choose_base_directory "${1:-}"

    echo
    echo "Searching recursively under:"
    echo "  $BASE_DIR"

    mapfile -t compose_directories < <(find_compose_directories)

    FOUND_COUNT="${#compose_directories[@]}"

    if (( FOUND_COUNT == 0 )); then
        echo
        echo "No Docker Compose files were found."
        exit 0
    fi

    echo "Found $FOUND_COUNT Compose project folder(s)."

    for project_dir in "${compose_directories[@]}"; do
        update_project "$project_dir"
    done

    print_summary

    if (( FAILED_COUNT > 0 )); then
        exit 1
    fi
}

main "$@"