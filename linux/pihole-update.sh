#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="pihole-update.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Makeea/scripts/master/linux/pihole-update.sh"
LOG_FILE="/var/log/pihole-update.log"
LOCK_FILE="/var/run/pihole-update.lock"
REBOOT_REQUIRED=false

log() {
    local message="$1"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" | tee -a "$LOG_FILE"
}

fail() {
    local message="$1"
    log "ERROR: $message"
    exit 1
}

cleanup() {
    if [[ -n "${LOCK_FD:-}" ]]; then
        flock -u "$LOCK_FD" || true
    fi
}

trap cleanup EXIT
trap 'fail "Script failed on line $LINENO."' ERR

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            printf 'Root privileges required. Re-running with sudo.\n' >&2
            exec sudo bash -c "curl -fsSL '$SCRIPT_URL' | bash"
        fi

        printf 'Root privileges required. Run as root or install sudo.\n' >&2
        printf 'Example as root: curl -fsSL %s | bash\n' "$SCRIPT_URL" >&2
        exit 1
    fi
}

setup_logging() {
    touch "$LOG_FILE" 2>/dev/null || fail "Cannot write to $LOG_FILE"
}

acquire_lock() {
    exec {LOCK_FD}>"$LOCK_FILE"
    flock -n "$LOCK_FD" || fail "Another Pi-hole update run is already in progress."
}

detect_supported_os() {
    [[ -r /etc/os-release ]] || fail "/etc/os-release not found."

    # shellcheck disable=SC1091
    . /etc/os-release

    case "${ID:-unknown}" in
        debian|ubuntu|raspbian|linuxmint|pop)
            ;;
        *)
            fail "This script supports Pi-hole hosts on Debian or Ubuntu based systems."
            ;;
    esac
}

require_pihole() {
    command -v pihole >/dev/null 2>&1 || fail "Pi-hole is not installed on this system."
}

update_system() {
    export DEBIAN_FRONTEND=noninteractive

    log "Running apt update..."
    apt update

    log "Running apt full-upgrade..."
    apt full-upgrade -y

    log "Running apt autoremove..."
    apt autoremove -y --purge

    log "Running apt autoclean..."
    apt autoclean
}

update_pihole() {
    log "Running Pi-hole update..."
    pihole -up
}

detect_reboot_requirement() {
    REBOOT_REQUIRED=false

    if [[ -f /var/run/reboot-required ]]; then
        REBOOT_REQUIRED=true
    fi
}

show_summary() {
    log "Update summary:"
    log "System packages updated with apt."
    log "Pi-hole application update attempted with pihole -up."

    if [[ "$REBOOT_REQUIRED" == true ]]; then
        log "A reboot is recommended."
    else
        log "No reboot is currently required."
    fi
}

main() {
    require_root
    setup_logging
    acquire_lock
    detect_supported_os
    require_pihole

    log "Starting $SCRIPT_NAME"
    log "This script updates system packages and Pi-hole, but does not reboot automatically."

    update_system
    update_pihole
    detect_reboot_requirement
    show_summary
}

main "$@"
