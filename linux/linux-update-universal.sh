#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="linux-update-universal.sh"
LOG_FILE="/var/log/linux-update-universal.log"
LOCK_FILE="/var/run/linux-update-universal.lock"
DISTRO_FAMILY=""
DISTRO_ID=""
DISTRO_NAME=""
PKG_MGR=""

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
        fail "Run this script as root. Example: curl -fsSL <url> | sudo bash"
    fi
}

setup_logging() {
    touch "$LOG_FILE" 2>/dev/null || fail "Cannot write to $LOG_FILE"
}

acquire_lock() {
    exec {LOCK_FD}>"$LOCK_FILE"
    flock -n "$LOCK_FD" || fail "Another update run is already in progress."
}

detect_os() {
    [[ -r /etc/os-release ]] || fail "/etc/os-release not found."

    # shellcheck disable=SC1091
    . /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"

    case "$DISTRO_ID" in
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
        *)
            if command -v apt >/dev/null 2>&1; then
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
            else
                fail "Unsupported Linux distribution: $DISTRO_NAME"
            fi
            ;;
    esac
}

update_apt() {
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

update_dnf() {
    log "Running dnf upgrade..."
    dnf upgrade --refresh -y

    log "Running dnf autoremove..."
    dnf autoremove -y || true

    log "Running dnf clean all..."
    dnf clean all
}

update_yum() {
    log "Running yum update..."
    yum update -y

    if yum help autoremove >/dev/null 2>&1; then
        log "Running yum autoremove..."
        yum autoremove -y || true
    fi

    log "Running yum clean all..."
    yum clean all
}

update_pacman() {
    log "Running pacman full system sync and upgrade..."
    pacman -Syu --noconfirm
}

update_zypper() {
    log "Running zypper refresh..."
    zypper --non-interactive refresh

    log "Running zypper update..."
    zypper --non-interactive update

    log "Running zypper clean..."
    zypper --non-interactive clean --all
}

show_summary() {
    log "Update summary:"
    log "Distro: $DISTRO_NAME"
    log "Family: $DISTRO_FAMILY"
    log "Package manager: $PKG_MGR"

    case "$DISTRO_FAMILY" in
        apt)
            apt list --upgradable 2>/dev/null || true
            ;;
        dnf)
            dnf check-update || true
            ;;
        yum)
            yum check-update || true
            ;;
        pacman)
            log "Pacman update completed."
            ;;
        zypper)
            zypper list-updates || true
            ;;
    esac
}

reboot_system() {
    log "Update completed successfully. Rebooting now."
    reboot
}

main() {
    require_root
    setup_logging
    acquire_lock
    detect_os

    log "Starting $SCRIPT_NAME"
    log "Detected distro: $DISTRO_NAME"
    log "Using package manager: $PKG_MGR"
    log "Major OS version upgrades are not performed by this script."

    case "$DISTRO_FAMILY" in
        apt)
            update_apt
            ;;
        dnf)
            update_dnf
            ;;
        yum)
            update_yum
            ;;
        pacman)
            update_pacman
            ;;
        zypper)
            update_zypper
            ;;
        *)
            fail "Unsupported distro family: $DISTRO_FAMILY"
            ;;
    esac

    show_summary
    reboot_system
}

main "$@"
