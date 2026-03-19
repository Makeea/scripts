#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="linux-update-universal.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Makeea/scripts/master/linux/linux-update-universal.sh"
LOG_FILE="/var/log/linux-update-universal.log"
LOCK_FILE="/var/run/linux-update-universal.lock"
DISTRO_FAMILY=""
DISTRO_ID=""
DISTRO_NAME=""
PKG_MGR=""
IS_PROXMOX=false
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

        printf 'Root privileges required. Run as root or use a root-aware launcher.\n' >&2
        printf 'Example as root: curl -fsSL %s | bash\n' "$SCRIPT_URL" >&2
        printf 'Example with sudo: curl -fsSL %s | sudo bash\n' "$SCRIPT_URL" >&2
        exit 1
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

    if command -v pveversion >/dev/null 2>&1; then
        IS_PROXMOX=true
        DISTRO_NAME="Proxmox VE (${DISTRO_NAME})"
    fi

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

detect_reboot_requirement() {
    REBOOT_REQUIRED=false

    if [[ -f /var/run/reboot-required ]]; then
        REBOOT_REQUIRED=true
        return
    fi

    case "$DISTRO_FAMILY" in
        dnf|yum)
            if command -v needs-restarting >/dev/null 2>&1; then
                if needs-restarting -r >/dev/null 2>&1; then
                    REBOOT_REQUIRED=true
                fi
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
    if [[ "$IS_PROXMOX" == true ]]; then
        if [[ "$REBOOT_REQUIRED" == true ]]; then
            log "Update completed successfully. Reboot is recommended, but automatic reboot is disabled on Proxmox."
        else
            log "Update completed successfully. No reboot is currently required on Proxmox."
        fi
        return
    fi

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
    detect_reboot_requirement
    reboot_system
}

main "$@"
