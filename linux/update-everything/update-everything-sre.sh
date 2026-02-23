#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="1.0.0"
LOGFILE="/var/log/update-everything.log"
DRY_RUN=false
NO_REBOOT=false
FORCE_REBOOT=false
QUIET=false

RED="\033[0;31m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
NC="\033[0m"

log() {
  [[ "$QUIET" == true ]] && return
  echo -e "$1" | tee -a "$LOGFILE"
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    log "${YELLOW}[DRY RUN]${NC} $*"
  else
    eval "$@" | tee -a "$LOGFILE"
  fi
}

usage() {
  cat <<EOF
update-everything v$VERSION

Options:
  --dry-run        Show what would run
  --no-reboot      Never reboot
  --force-reboot   Reboot regardless
  --quiet          Minimal output
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --no-reboot) NO_REBOOT=true ;;
    --force-reboot) FORCE_REBOOT=true ;;
    --quiet) QUIET=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root or sudo"
  exit 1
fi

log "${GREEN}=== Update start $(date) ===${NC}"

detect_distro() {
  if command -v pveversion >/dev/null 2>&1; then
    echo "proxmox"
  elif command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo "unknown"
  fi
}

DISTRO=$(detect_distro)
log "Detected distro: $DISTRO"

check_proxmox_cluster() {
  if command -v pvecm >/dev/null 2>&1; then
    if pvecm status 2>/dev/null | grep -q "Quorate"; then
      log "${YELLOW}Proxmox cluster detected — ensure node is drained${NC}"
    fi
  fi
}

check_proxmox_cluster

export DEBIAN_FRONTEND=noninteractive

case "$DISTRO" in

  proxmox|apt)
    run "apt update"
    run "apt full-upgrade -y"
    run "apt autoremove -y --purge"
    run "apt autoclean"
    run "apt clean"
    ;;

  dnf)
    run "dnf upgrade --refresh -y"
    run "dnf autoremove -y"
    run "dnf clean all"
    ;;

  yum)
    run "yum update -y"
    run "yum autoremove -y"
    run "yum clean all"
    ;;

  pacman)
    run "pacman -Syu --noconfirm"
    ;;

  zypper)
    run "zypper refresh"
    run "zypper update -y"
    run "zypper clean"
    ;;

  *)
    log "${RED}Unsupported distro${NC}"
    exit 3
    ;;

esac

needs_reboot=false

if [[ -f /var/run/reboot-required ]]; then
  needs_reboot=true
elif command -v needs-restarting >/dev/null 2>&1; then
  if needs-restarting -r >/dev/null 2>&1; then
    needs_reboot=true
  fi
fi

if [[ "$FORCE_REBOOT" == true ]]; then
  needs_reboot=true
fi

if [[ "$NO_REBOOT" == true ]]; then
  needs_reboot=false
fi

if [[ "$needs_reboot" == true ]]; then
  log "${YELLOW}Rebooting system${NC}"
  run "reboot"
else
  log "${GREEN}No reboot required${NC}"
fi

log "${GREEN}=== Update complete $(date) ===${NC}"
exit 0