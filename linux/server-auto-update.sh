#!/usr/bin/env bash

# Weekly unattended server updater.
# Detects what the host runs and updates only those parts:
# - OS packages (apt, dnf, yum, pacman, zypper, apk, SteamOS), plus Flatpak and Snap
# - Pi-hole (pihole -up)
# - Running Docker Compose projects (pull + recreate)
# - Docker cleanup (unused images, containers, networks, build cache, never volumes)
# Reboots when the OS requires it, except on Proxmox.

set -uo pipefail

SCRIPT_NAME="server-auto-update.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Makeea/scripts/master/linux/server-auto-update.sh"
INSTALL_PATH="/usr/local/sbin/server-auto-update.sh"
CRON_FILE="/etc/cron.d/server-auto-update"
ALPINE_CRONTAB="/etc/crontabs/root"
CRON_MARKER="# server-auto-update"
LOGROTATE_FILE="/etc/logrotate.d/server-auto-update"
LOCK_FILE="/run/server-auto-update.lock"
[[ -d /run ]] || LOCK_FILE="/var/run/server-auto-update.lock"

DEFAULT_TIME="03:00"
JITTER_MAX_SECONDS=1800
REBOOT_DELAY_MINUTES=1

DRY_RUN=false
NO_REBOOT=false
SKIP_OS=false
SKIP_PIHOLE=false
SKIP_DOCKER=false
SKIP_CLEANUP=false
NO_SELF_UPDATE=false
CRON_MODE=false
ACTION="run"
CRON_TIME="$DEFAULT_TIME"
LOG_USER=""
LOG_HOME=""
LOG_FILE=""
ORIGINAL_ARGS=("$@")

DISTRO_FAMILY=""
DISTRO_ID=""
DISTRO_NAME=""
PKG_MGR=""
IS_PROXMOX=false
HAS_PIHOLE=false
HAS_DOCKER=false
HAS_COMPOSE=false
REBOOT_REQUIRED=false

declare -a STEP_NAMES=()
declare -A STEP_STATUS=()
declare -a COMPOSE_UPDATED=()
declare -a COMPOSE_FAILED=()
ANY_FAILED=false

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Run once:
  curl -fsSL $SCRIPT_URL | sudo bash

Install the weekly cron job (Sunday $DEFAULT_TIME by default):
  curl -fsSL $SCRIPT_URL | sudo bash -s -- --install-cron
  curl -fsSL $SCRIPT_URL | sudo bash -s -- --install-cron --time 04:00

Options:
  --dry-run          Print the commands without running them
  --no-reboot        Never reboot, only report that a reboot is needed
  --skip-os          Skip OS package updates
  --skip-pihole      Skip the Pi-hole update
  --skip-docker      Skip Docker Compose project updates
  --skip-cleanup     Skip Docker cleanup
  --log-user USER    Write the log to ~USER/logs/updater.log (default: the sudo user)
  --install-cron     Install to $INSTALL_PATH and schedule a weekly run
  --time HH:MM       Time of day for --install-cron (default: $DEFAULT_TIME, Sunday)
  --uninstall-cron   Remove the cron job, logrotate config, and installed copy
  --no-self-update   Do not fetch the latest version from GitHub before running
  --cron             Used by the cron job. Adds a random start delay on non Pi-hole hosts
  -h, --help         Show this help
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --no-reboot) NO_REBOOT=true ;;
            --skip-os) SKIP_OS=true ;;
            --skip-pihole) SKIP_PIHOLE=true ;;
            --skip-docker) SKIP_DOCKER=true ;;
            --skip-cleanup) SKIP_CLEANUP=true ;;
            --no-self-update) NO_SELF_UPDATE=true ;;
            --cron) CRON_MODE=true ;;
            --install-cron) ACTION="install" ;;
            --uninstall-cron) ACTION="uninstall" ;;
            --log-user)
                [[ $# -ge 2 ]] || { echo "ERROR: --log-user needs a user name." >&2; exit 2; }
                LOG_USER="$2"
                shift
                ;;
            --time)
                [[ $# -ge 2 ]] || { echo "ERROR: --time needs HH:MM." >&2; exit 2; }
                CRON_TIME="$2"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                usage >&2
                exit 2
                ;;
        esac
        shift
    done
}

log() {
    local line
    line="$(printf '[%s] %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$*")"
    if [[ -n "$LOG_FILE" ]]; then
        printf '%s\n' "$line" | tee -a "$LOG_FILE"
    else
        printf '%s\n' "$line"
    fi
}

fail() {
    log "ERROR: $*"
    exit 1
}

# Run a command, or print it in dry-run mode. Output goes to the log.
run() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] $*"
        return 0
    fi

    log "+ $*"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
}

require_root() {
    [[ "${EUID}" -eq 0 ]] && return

    if ! command -v sudo >/dev/null 2>&1; then
        echo "Root privileges required. Run as root or install sudo." >&2
        echo "Example: curl -fsSL $SCRIPT_URL | sudo bash" >&2
        exit 1
    fi

    echo "Root privileges required. Re-running with sudo." >&2

    local script_path="${BASH_SOURCE[0]:-}"
    if [[ -f "$script_path" ]]; then
        exec sudo bash "$script_path" "${ORIGINAL_ARGS[@]}"
    fi

    local quoted_args=""
    if ((${#ORIGINAL_ARGS[@]})); then
        quoted_args="$(printf '%q ' "${ORIGINAL_ARGS[@]}")"
    fi
    exec sudo bash -c "curl -fsSL '$SCRIPT_URL' | bash -s -- $quoted_args"
}

user_home() {
    local user="$1"
    local home=""

    if command -v getent >/dev/null 2>&1; then
        home="$(getent passwd "$user" | cut -d: -f6)"
    else
        home="$(awk -F: -v u="$user" '$1 == u { print $6 }' /etc/passwd)"
    fi

    printf '%s\n' "$home"
}

resolve_log_user() {
    if [[ -z "$LOG_USER" ]]; then
        LOG_USER="${SUDO_USER:-root}"
    fi

    LOG_HOME="$(user_home "$LOG_USER")"
    if [[ -z "$LOG_HOME" || ! -d "$LOG_HOME" ]]; then
        echo "WARNING: No home folder found for user '$LOG_USER'. Logging as root." >&2
        LOG_USER="root"
        LOG_HOME="$(user_home root)"
        LOG_HOME="${LOG_HOME:-/root}"
    fi
}

setup_logging() {
    local log_dir="$LOG_HOME/logs"
    local group

    LOG_FILE="$log_dir/updater.log"
    mkdir -p "$log_dir" || { echo "ERROR: Cannot create $log_dir" >&2; exit 1; }
    touch "$LOG_FILE" || { echo "ERROR: Cannot write to $LOG_FILE" >&2; exit 1; }

    group="$(id -gn "$LOG_USER" 2>/dev/null || echo "$LOG_USER")"
    chown "$LOG_USER:$group" "$log_dir" "$LOG_FILE" 2>/dev/null || true
}

acquire_lock() {
    if ! command -v flock >/dev/null 2>&1; then
        log "WARNING: flock not found. Running without a lock."
        return
    fi

    exec {LOCK_FD}>"$LOCK_FILE"
    flock -n "$LOCK_FD" || fail "Another update run is already in progress."
}

download() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 60 "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 60 -O "$dest" "$url"
    else
        return 1
    fi
}

# Replace the installed copy with the latest GitHub version, then restart with it.
self_update() {
    local self_path tmp

    [[ "$NO_SELF_UPDATE" == true || "$DRY_RUN" == true ]] && return
    self_path="$(readlink -f "${BASH_SOURCE[0]:-}" 2>/dev/null || true)"
    [[ "$self_path" == "$INSTALL_PATH" ]] || return

    tmp="$(mktemp)" || return
    if ! download "$SCRIPT_URL" "$tmp"; then
        log "Self-update: download failed. Using the installed copy."
        rm -f "$tmp"
        return
    fi

    if ! bash -n "$tmp" 2>/dev/null; then
        log "Self-update: downloaded file has syntax errors. Using the installed copy."
        rm -f "$tmp"
        return
    fi

    if cmp -s "$tmp" "$INSTALL_PATH"; then
        rm -f "$tmp"
        return
    fi

    install -m 755 "$tmp" "$INSTALL_PATH"
    rm -f "$tmp"
    log "Self-update: installed a newer version. Restarting."
    exec bash "$INSTALL_PATH" "${ORIGINAL_ARGS[@]}" --no-self-update
}

detect_os() {
    [[ -r /etc/os-release ]] || fail "/etc/os-release not found."

    # shellcheck disable=SC1091
    . /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"

    if command -v pveversion >/dev/null 2>&1; then
        IS_PROXMOX=true
        DISTRO_NAME="Proxmox VE (${DISTRO_NAME})"
    fi

    case "$DISTRO_ID" in
        steamos)
            DISTRO_FAMILY="steamos"
            PKG_MGR="steamos-update"
            ;;
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            DISTRO_FAMILY="apt"
            PKG_MGR="apt"
            ;;
        fedora|almalinux|rocky|ol|amzn|centos|rhel)
            if command -v dnf >/dev/null 2>&1; then
                DISTRO_FAMILY="dnf"
                PKG_MGR="dnf"
            elif command -v yum >/dev/null 2>&1; then
                DISTRO_FAMILY="yum"
                PKG_MGR="yum"
            else
                fail "No supported package manager found for $DISTRO_NAME"
            fi
            ;;
        arch|manjaro|endeavouros)
            DISTRO_FAMILY="pacman"
            PKG_MGR="pacman"
            ;;
        opensuse-leap|opensuse-tumbleweed|opensuse*|sles|sled)
            DISTRO_FAMILY="zypper"
            PKG_MGR="zypper"
            ;;
        alpine)
            DISTRO_FAMILY="apk"
            PKG_MGR="apk"
            ;;
        *)
            if command -v apt-get >/dev/null 2>&1; then
                DISTRO_FAMILY="apt"
                PKG_MGR="apt"
            elif command -v dnf >/dev/null 2>&1; then
                DISTRO_FAMILY="dnf"
                PKG_MGR="dnf"
            elif command -v yum >/dev/null 2>&1; then
                DISTRO_FAMILY="yum"
                PKG_MGR="yum"
            elif command -v pacman >/dev/null 2>&1; then
                DISTRO_FAMILY="pacman"
                PKG_MGR="pacman"
            elif command -v zypper >/dev/null 2>&1; then
                DISTRO_FAMILY="zypper"
                PKG_MGR="zypper"
            elif command -v apk >/dev/null 2>&1; then
                DISTRO_FAMILY="apk"
                PKG_MGR="apk"
            else
                fail "Unsupported Linux distribution: $DISTRO_NAME"
            fi
            ;;
    esac
}

detect_profile() {
    detect_os

    command -v pihole >/dev/null 2>&1 && HAS_PIHOLE=true

    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            HAS_DOCKER=true
            docker compose version >/dev/null 2>&1 && HAS_COMPOSE=true
        else
            log "WARNING: Docker is installed but the daemon is not reachable. Skipping Docker steps."
        fi
    fi

    log "Host: $(hostname)"
    log "Distro: $DISTRO_NAME | package manager: $PKG_MGR"
    log "Proxmox: $IS_PROXMOX | Pi-hole: $HAS_PIHOLE | Docker: $HAS_DOCKER | Compose: $HAS_COMPOSE"
}

update_apt() {
    export DEBIAN_FRONTEND=noninteractive
    local apt_opts=(
        -y
        -o DPkg::Lock::Timeout=600
        -o Dpkg::Options::=--force-confdef
        -o Dpkg::Options::=--force-confold
    )

    run apt-get -o DPkg::Lock::Timeout=600 update || return 1
    run apt-get "${apt_opts[@]}" full-upgrade || return 1
    run apt-get "${apt_opts[@]}" autoremove --purge || return 1
    run apt-get autoclean || return 1
}

update_dnf() {
    run dnf upgrade --refresh -y || return 1
    run dnf autoremove -y || true
    run dnf clean all || return 1
}

update_yum() {
    run yum update -y || return 1
    if yum help autoremove >/dev/null 2>&1; then
        run yum autoremove -y || true
    fi
    run yum clean all || return 1
}

update_pacman() {
    run pacman -Syu --noconfirm || return 1
}

update_zypper() {
    run zypper --non-interactive refresh || return 1
    run zypper --non-interactive update || return 1
    run zypper --non-interactive clean --all || return 1
}

update_apk() {
    run apk update || return 1
    run apk upgrade || return 1
    run apk cache clean || true
}

update_steamos() {
    command -v steamos-update >/dev/null 2>&1 || { log "steamos-update not found."; return 1; }

    local status=0
    run steamos-update || status=$?

    case "$status" in
        0) log "SteamOS update applied. A reboot is required to activate it." ;;
        7) log "No SteamOS update available." ;;
        *) return "$status" ;;
    esac
}

update_flatpak() {
    command -v flatpak >/dev/null 2>&1 || return 0

    run flatpak update --system -y --noninteractive || return 1

    if [[ "$LOG_USER" != "root" ]] && command -v sudo >/dev/null 2>&1; then
        run sudo -u "$LOG_USER" flatpak update --user -y --noninteractive \
            || log "WARNING: Flatpak user update for $LOG_USER failed."
    fi
}

update_snap() {
    command -v snap >/dev/null 2>&1 || return 0
    run snap refresh || return 1
}

step_os() {
    case "$DISTRO_FAMILY" in
        apt) update_apt ;;
        dnf) update_dnf ;;
        yum) update_yum ;;
        pacman) update_pacman ;;
        zypper) update_zypper ;;
        apk) update_apk ;;
        steamos) update_steamos ;;
        *) log "Unsupported distro family: $DISTRO_FAMILY"; return 1 ;;
    esac || return 1

    update_flatpak || return 1
    update_snap || return 1
}

step_pihole() {
    run pihole -up || return 1

    [[ "$DRY_RUN" == true ]] && return 0

    run pihole status || true
    if ! pgrep -x pihole-FTL >/dev/null 2>&1; then
        log "ERROR: pihole-FTL is not running after the update."
        return 1
    fi
    log "pihole-FTL is running."
}

update_compose_project() {
    local project="$1"
    local workdir="$2"
    local config_files="$3"
    local services="$4"
    local -a file_args=()
    local -a service_list=()
    local -a files=()
    local file

    log "Compose project: $project ($workdir)"

    if [[ ! -d "$workdir" ]]; then
        log "ERROR: Project folder no longer exists: $workdir"
        return 1
    fi

    IFS=',' read -r -a files <<< "$config_files"
    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue
        if [[ ! -f "$file" ]]; then
            log "ERROR: Compose file no longer exists: $file"
            return 1
        fi
        file_args+=(-f "$file")
    done

    read -r -a service_list <<< "$services"

    (
        cd "$workdir" || exit 1
        run docker compose -p "$project" "${file_args[@]}" pull "${service_list[@]}" || exit 1
        run docker compose -p "$project" "${file_args[@]}" up -d --remove-orphans "${service_list[@]}" || exit 1
    )
}

# Find running Compose projects from container labels, so no folder needs to be configured.
# Only services that are running now get pulled and recreated.
step_compose() {
    local -A project_dirs=()
    local -A project_files=()
    local -A project_services=()
    local project workdir files service result=0

    while IFS='|' read -r project workdir files service; do
        [[ -z "$project" || -z "$workdir" ]] && continue
        project_dirs["$project"]="$workdir"
        project_files["$project"]="$files"
        if [[ " ${project_services[$project]:-} " != *" $service "* ]]; then
            project_services["$project"]="${project_services[$project]:-} $service"
        fi
    done < <(docker ps \
        --filter 'label=com.docker.compose.project' \
        --format '{{.Label "com.docker.compose.project"}}|{{.Label "com.docker.compose.project.working_dir"}}|{{.Label "com.docker.compose.project.config_files"}}|{{.Label "com.docker.compose.service"}}')

    if ((${#project_dirs[@]} == 0)); then
        log "No running Compose projects found."
        return 0
    fi

    log "Found ${#project_dirs[@]} running Compose project(s)."

    while read -r project; do
        if update_compose_project "$project" "${project_dirs[$project]}" \
            "${project_files[$project]}" "${project_services[$project]}"; then
            COMPOSE_UPDATED+=("$project")
        else
            COMPOSE_FAILED+=("$project")
            result=1
        fi
    done < <(printf '%s\n' "${!project_dirs[@]}" | sort)

    return "$result"
}

step_cleanup() {
    log "Free space on / before cleanup:"
    df -h / 2>&1 | tee -a "$LOG_FILE"

    run docker system prune --all --force || return 1

    log "Free space on / after cleanup:"
    df -h / 2>&1 | tee -a "$LOG_FILE"
}

run_step() {
    local name="$1"
    local fn="$2"

    STEP_NAMES+=("$name")
    log "===== $name ====="

    if "$fn"; then
        STEP_STATUS["$name"]="OK"
    else
        STEP_STATUS["$name"]="FAILED"
        ANY_FAILED=true
        log "Step failed: $name"
    fi
}

skip_step() {
    local name="$1"
    local reason="$2"

    STEP_NAMES+=("$name")
    STEP_STATUS["$name"]="SKIPPED ($reason)"
}

detect_reboot_requirement() {
    REBOOT_REQUIRED=false

    if [[ -f /var/run/reboot-required || -f /run/reboot-required ]]; then
        REBOOT_REQUIRED=true
        return
    fi

    case "$DISTRO_FAMILY" in
        dnf|yum)
            if command -v needs-restarting >/dev/null 2>&1 && ! needs-restarting -r >/dev/null 2>&1; then
                REBOOT_REQUIRED=true
            fi
            ;;
        steamos)
            if command -v atomupd-manager >/dev/null 2>&1 \
                && [[ "$(atomupd-manager get-update-status 2>/dev/null || true)" == "successful" ]]; then
                REBOOT_REQUIRED=true
            fi
            ;;
    esac
}

print_summary() {
    local name

    log "===== Summary ====="
    log "Host: $(hostname) | $DISTRO_NAME"
    for name in "${STEP_NAMES[@]}"; do
        log "$(printf '%-16s %s' "$name" "${STEP_STATUS[$name]}")"
    done

    if ((${#COMPOSE_UPDATED[@]})); then
        log "Compose updated: ${COMPOSE_UPDATED[*]}"
    fi
    if ((${#COMPOSE_FAILED[@]})); then
        log "Compose failed: ${COMPOSE_FAILED[*]}"
    fi

    log "Reboot required: $REBOOT_REQUIRED"
    log "Elapsed: $((SECONDS / 60))m $((SECONDS % 60))s"
}

reboot_decision() {
    if [[ "$REBOOT_REQUIRED" != true ]]; then
        log "No reboot required."
        return
    fi

    if [[ "$IS_PROXMOX" == true ]]; then
        log "Reboot recommended. Automatic reboot is disabled on Proxmox. Reboot this node by hand."
        return
    fi

    if [[ "$NO_REBOOT" == true ]]; then
        log "Reboot required, but --no-reboot is set. Reboot by hand."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] Would reboot in $REBOOT_DELAY_MINUTES minute(s)."
        return
    fi

    log "Rebooting in $REBOOT_DELAY_MINUTES minute(s)."
    if command -v shutdown >/dev/null 2>&1; then
        shutdown -r "+$REBOOT_DELAY_MINUTES" "server-auto-update: rebooting to finish updates" >/dev/null 2>&1 && return
    fi
    nohup sh -c "sleep $((REBOOT_DELAY_MINUTES * 60)); reboot" >/dev/null 2>&1 &
}

ensure_cron_installed() {
    if command -v cron >/dev/null 2>&1 || command -v crond >/dev/null 2>&1; then
        return
    fi

    log "No cron daemon found. Installing one."
    case "$DISTRO_FAMILY" in
        apt) run apt-get install -y cron ;;
        dnf) run dnf install -y cronie ;;
        yum) run yum install -y cronie ;;
        pacman) run pacman -S --noconfirm --needed cronie ;;
        zypper) run zypper --non-interactive install cron ;;
        *) log "WARNING: Install a cron daemon by hand." ;;
    esac

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now cron 2>/dev/null || systemctl enable --now crond 2>/dev/null || true
    fi
}

write_logrotate() {
    [[ -d /etc/logrotate.d ]] || return 0

    local group
    group="$(id -gn "$LOG_USER" 2>/dev/null || echo "$LOG_USER")"

    cat > "$LOGROTATE_FILE" <<EOF
$LOG_FILE {
    su $LOG_USER $group
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0644 $LOG_USER $group
}
EOF
    log "Wrote $LOGROTATE_FILE"
}

install_cron() {
    local hour minute self_path

    if [[ ! "$CRON_TIME" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        fail "Invalid --time '$CRON_TIME'. Use HH:MM, for example 04:00."
    fi
    hour="$((10#${BASH_REMATCH[1]}))"
    minute="$((10#${BASH_REMATCH[2]}))"

    [[ "$DISTRO_FAMILY" == "steamos" ]] && fail "Cron install is not supported on SteamOS (read-only system)."

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] Would install $INSTALL_PATH and run it Sundays at $(printf '%02d:%02d' "$hour" "$minute") as root."
        return
    fi

    self_path="$(readlink -f "${BASH_SOURCE[0]:-}" 2>/dev/null || true)"
    if [[ -f "$self_path" ]]; then
        [[ "$self_path" != "$INSTALL_PATH" ]] && install -m 755 "$self_path" "$INSTALL_PATH"
    else
        local tmp
        tmp="$(mktemp)"
        download "$SCRIPT_URL" "$tmp" || fail "Could not download $SCRIPT_URL"
        bash -n "$tmp" || fail "Downloaded script has syntax errors."
        install -m 755 "$tmp" "$INSTALL_PATH"
        rm -f "$tmp"
    fi
    log "Installed $INSTALL_PATH"

    ensure_cron_installed

    local command="$INSTALL_PATH --cron --log-user $LOG_USER >/dev/null 2>&1"

    if [[ "$DISTRO_FAMILY" == "apk" ]]; then
        # BusyBox crond on Alpine does not read /etc/cron.d.
        touch "$ALPINE_CRONTAB"
        sed -i "/$CRON_MARKER\$/d" "$ALPINE_CRONTAB"
        printf '%s %s * * 0 %s %s\n' "$minute" "$hour" "$command" "$CRON_MARKER" >> "$ALPINE_CRONTAB"
        log "Added weekly job to $ALPINE_CRONTAB"
    else
        cat > "$CRON_FILE" <<EOF
# Weekly server update. Installed by $SCRIPT_NAME --install-cron.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$minute $hour * * 0 root $command
EOF
        chmod 644 "$CRON_FILE"
        log "Wrote $CRON_FILE"
    fi

    write_logrotate

    log "Weekly run scheduled: Sunday $(printf '%02d:%02d' "$hour" "$minute"). Log: $LOG_FILE"
}

uninstall_cron() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] Would remove $CRON_FILE, $LOGROTATE_FILE, $INSTALL_PATH"
        return
    fi

    rm -f "$CRON_FILE" "$LOGROTATE_FILE" "$INSTALL_PATH"
    if [[ -f "$ALPINE_CRONTAB" ]]; then
        sed -i "/$CRON_MARKER\$/d" "$ALPINE_CRONTAB"
    fi
    log "Removed the cron job, logrotate config, and $INSTALL_PATH. The log file was kept."
}

main() {
    parse_args "$@"
    require_root
    resolve_log_user
    setup_logging
    self_update

    case "$ACTION" in
        install)
            detect_os
            install_cron
            exit 0
            ;;
        uninstall)
            uninstall_cron
            exit 0
            ;;
    esac

    acquire_lock
    log "Starting $SCRIPT_NAME"
    [[ "$DRY_RUN" == true ]] && log "Dry run. No changes will be made."
    detect_profile

    if [[ "$CRON_MODE" == true && "$HAS_PIHOLE" != true && "$DRY_RUN" != true ]]; then
        local delay=$((RANDOM % JITTER_MAX_SECONDS))
        log "Waiting ${delay}s before starting, so hosts do not all update at once."
        sleep "$delay"
    fi

    if [[ "$SKIP_OS" == true ]]; then
        skip_step "OS packages" "flag"
    else
        run_step "OS packages" step_os
    fi

    if [[ "$HAS_PIHOLE" != true ]]; then
        skip_step "Pi-hole" "not installed"
    elif [[ "$SKIP_PIHOLE" == true ]]; then
        skip_step "Pi-hole" "flag"
    else
        run_step "Pi-hole" step_pihole
    fi

    if [[ "$HAS_COMPOSE" != true ]]; then
        skip_step "Compose" "not available"
    elif [[ "$SKIP_DOCKER" == true ]]; then
        skip_step "Compose" "flag"
    else
        run_step "Compose" step_compose
    fi

    if [[ "$HAS_DOCKER" != true ]]; then
        skip_step "Docker cleanup" "not available"
    elif [[ "$SKIP_CLEANUP" == true ]]; then
        skip_step "Docker cleanup" "flag"
    else
        run_step "Docker cleanup" step_cleanup
    fi

    detect_reboot_requirement
    print_summary
    reboot_decision

    [[ "$ANY_FAILED" == true ]] && exit 1
    exit 0
}

main "$@"
