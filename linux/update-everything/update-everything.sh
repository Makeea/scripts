#!/usr/bin/env bash

set -euo pipefail

LOGFILE="/var/log/update-everything.log"
REBOOT_FLAG="/var/run/reboot-required"

echo "==== Update started $(date) ====" | tee -a "$LOGFILE"

# Require root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Detect OS
if command -v pveversion >/dev/null 2>&1; then
  DISTRO="proxmox"
elif command -v apt >/dev/null 2>&1; then
  DISTRO="apt"
elif command -v dnf >/dev/null 2>&1; then
  DISTRO="dnf"
elif command -v yum >/dev/null 2>&1; then
  DISTRO="yum"
elif command -v pacman >/dev/null 2>&1; then
  DISTRO="pacman"
elif command -v zypper >/dev/null 2>&1; then
  DISTRO="zypper"
else
  echo "Unsupported distro"
  exit 1
fi

echo "Detected: $DISTRO" | tee -a "$LOGFILE"

case "$DISTRO" in

  proxmox|apt)
    export DEBIAN_FRONTEND=noninteractive
    apt update | tee -a "$LOGFILE"
    apt full-upgrade -y | tee -a "$LOGFILE"
    apt autoremove -y --purge | tee -a "$LOGFILE"
    apt autoclean | tee -a "$LOGFILE"
    apt clean | tee -a "$LOGFILE"
    ;;

  dnf)
    dnf upgrade --refresh -y | tee -a "$LOGFILE"
    dnf autoremove -y | tee -a "$LOGFILE"
    dnf clean all | tee -a "$LOGFILE"
    ;;

  yum)
    yum update -y | tee -a "$LOGFILE"
    yum autoremove -y | tee -a "$LOGFILE"
    yum clean all | tee -a "$LOGFILE"
    ;;

  pacman)
    pacman -Syu --noconfirm | tee -a "$LOGFILE"
    ;;

  zypper)
    zypper refresh | tee -a "$LOGFILE"
    zypper update -y | tee -a "$LOGFILE"
    zypper clean | tee -a "$LOGFILE"
    ;;

esac

# Reboot logic
if [[ -f "$REBOOT_FLAG" ]] || needs-restarting -r >/dev/null 2>&1; then
  echo "Reboot required — rebooting now" | tee -a "$LOGFILE"
  reboot
else
  echo "No reboot required" | tee -a "$LOGFILE"
fi

echo "==== Update completed $(date) ====" | tee -a "$LOGFILE"
