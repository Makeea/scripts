#!/usr/bin/env bash

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
COMPOSE_ROOT="${COMPOSE_ROOT:-/home/rootadmin/docker-data}"
LOCK_FILE="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/${SCRIPT_NAME}.${UID}.lock"
DRY_RUN=false
DOCKER_CMD=()

declare -A PROJECT_SERVICES=()
declare -A PROJECT_NAMES=()
declare -A PROJECT_DIRS=()
declare -A PROJECT_CONFIGS=()

UPDATED=0
FAILED=0
SKIPPED=0

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--help]

Pull and recreate only the currently running Docker Compose services whose
Compose configuration is located beneath $COMPOSE_ROOT.

Options:
  --dry-run  Discover services and print the commands without running them
  --help     Show this help text
EOF
}

fail() {
    log "ERROR: $*" >&2
    exit 1
}

parse_args() {
    while (($#)); do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                fail "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

select_docker_command() {
    command -v docker >/dev/null 2>&1 || fail "docker is not installed or not in PATH."

    if docker info >/dev/null 2>&1; then
        DOCKER_CMD=(docker)
    elif command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
        DOCKER_CMD=(sudo -n docker)
    else
        fail "Cannot access the Docker daemon (and passwordless sudo is unavailable)."
    fi

    "${DOCKER_CMD[@]}" compose version >/dev/null 2>&1 || fail "Docker Compose v2 is unavailable."
}

acquire_lock() {
    command -v flock >/dev/null 2>&1 || fail "flock is required but is not installed."
    exec {LOCK_FD}>"$LOCK_FILE" || fail "Cannot open lock file: $LOCK_FILE"
    flock -n "$LOCK_FD" || fail "Another $SCRIPT_NAME run is already in progress."
}

is_beneath_root() {
    local path="$1"
    [[ "$path" == "$COMPOSE_ROOT_REAL" || "$path" == "$COMPOSE_ROOT_REAL/"* ]]
}

discover_running_services() {
    local project service working_dir config_files oneoff key existing
    local working_dir_real config config_real
    local -a configs=()

    while IFS=$'\t' read -r project service working_dir config_files oneoff; do
        [[ -n "$project" && -n "$service" && -n "$working_dir" && -n "$config_files" ]] || {
            ((SKIPPED++))
            log "WARNING: Skipping a running container with incomplete Compose labels."
            continue
        }
        [[ "$oneoff" != "True" && "$oneoff" != "true" ]] || continue

        working_dir_real="$(realpath -e -- "$working_dir" 2>/dev/null)" || {
            ((SKIPPED++))
            log "WARNING: Skipping $project/$service: working directory does not exist."
            continue
        }
        is_beneath_root "$working_dir_real" || {
            ((SKIPPED++))
            log "WARNING: Skipping $project/$service: working directory is outside $COMPOSE_ROOT_REAL."
            continue
        }

        IFS=',' read -r -a configs <<< "$config_files"
        config_files=""
        for config in "${configs[@]}"; do
            if [[ "$config" != /* ]]; then
                config="$working_dir_real/$config"
            fi
            config_real="$(realpath -e -- "$config" 2>/dev/null)" || break
            is_beneath_root "$config_real" || break
            [[ -f "$config_real" ]] || break
            config_files+="${config_files:+,}$config_real"
        done
        if ((${#configs[@]} == 0)) || [[ $(awk -F, '{print NF}' <<< "$config_files") -ne ${#configs[@]} ]]; then
            ((SKIPPED++))
            log "WARNING: Skipping $project/$service: a Compose config is missing or outside $COMPOSE_ROOT_REAL."
            continue
        fi

        key="$project"$'\034'"$working_dir_real"$'\034'"$config_files"
        existing="${PROJECT_SERVICES[$key]:-}"
        if [[ "$existing" != *"|$service|"* ]]; then
            PROJECT_SERVICES[$key]="${existing}|$service|"
        fi
        PROJECT_NAMES[$key]="$project"
        PROJECT_DIRS[$key]="$working_dir_real"
        PROJECT_CONFIGS[$key]="$config_files"
    done < <("${DOCKER_CMD[@]}" ps \
        --filter label=com.docker.compose.project \
        --format '{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}\t{{.Label "com.docker.compose.project.working_dir"}}\t{{.Label "com.docker.compose.project.config_files"}}\t{{.Label "com.docker.compose.oneoff"}}')
}

print_command() {
    printf '[%s] DRY RUN:' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' %q' "$@"
    printf '\n'
}

run_project() {
    local key="$1" project working_dir config_files service_blob config
    local -a compose_base services configs

    project="${PROJECT_NAMES[$key]}"
    working_dir="${PROJECT_DIRS[$key]}"
    config_files="${PROJECT_CONFIGS[$key]}"
    service_blob="${PROJECT_SERVICES[$key]}"

    IFS=',' read -r -a configs <<< "$config_files"
    service_blob="${service_blob#|}"
    service_blob="${service_blob%|}"
    IFS='|' read -r -a services <<< "$service_blob"

    compose_base=("${DOCKER_CMD[@]}" compose -p "$project" --project-directory "$working_dir")
    for config in "${configs[@]}"; do
        compose_base+=(-f "$config")
    done

    log "Project $project: running services: ${services[*]}"
    if $DRY_RUN; then
        print_command "${compose_base[@]}" pull "${services[@]}"
        print_command "${compose_base[@]}" up -d --no-deps "${services[@]}"
        ((UPDATED++))
        return
    fi

    if ! "${compose_base[@]}" pull "${services[@]}"; then
        log "ERROR: Project $project: image pull failed; skipping recreate." >&2
        ((FAILED++))
        return
    fi
    if ! "${compose_base[@]}" up -d --no-deps "${services[@]}"; then
        log "ERROR: Project $project: recreate failed." >&2
        ((FAILED++))
        return
    fi

    ((UPDATED++))
    log "Project $project: update complete."
}

main() {
    local key
    local -a keys=()

    parse_args "$@"
    select_docker_command
    acquire_lock

    command -v realpath >/dev/null 2>&1 || fail "realpath is required but is not installed."
    COMPOSE_ROOT_REAL="$(realpath -e -- "$COMPOSE_ROOT" 2>/dev/null)" || fail "Compose root does not exist: $COMPOSE_ROOT"
    [[ -d "$COMPOSE_ROOT_REAL" ]] || fail "Compose root is not a directory: $COMPOSE_ROOT_REAL"

    log "Scanning running Compose services beneath $COMPOSE_ROOT_REAL."
    discover_running_services

    if ((${#PROJECT_SERVICES[@]} == 0)); then
        log "No eligible running Compose services found. Skipped records: $SKIPPED."
        exit 0
    fi

    mapfile -t keys < <(printf '%s\n' "${!PROJECT_SERVICES[@]}" | LC_ALL=C sort)
    for key in "${keys[@]}"; do
        run_project "$key"
    done

    log "Summary: updated=$UPDATED failed=$FAILED skipped=$SKIPPED"
    ((FAILED == 0)) || exit 1
}

main "$@"
