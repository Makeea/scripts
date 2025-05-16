#!/bin/bash

# ===========================
# Ubuntu Disk Cleanup Script
# ===========================
# This script helps you free up disk space on your Ubuntu system.
# It removes old package files, unnecessary packages, old logs,
# unused Linux kernels (except the one you're using), and optionally
# unused Docker stuff (images, containers, volumes).

# ---------------------------
# STEP 1: Clean APT cache
# ---------------------------
# This deletes downloaded .deb files from /var/cache/apt/archives
echo "[*] Cleaning up APT cache..."
sudo apt clean

# -----------------------------------------
# STEP 2: Remove unused packages
# -----------------------------------------
# This gets rid of old libraries and things no longer needed
echo "[*] Removing orphaned packages..."
sudo apt autoremove -y

# ---------------------------------------------------
# STEP 3: Clean journal logs older than 7 days
# ---------------------------------------------------
# System logs can take up a lot of space over time
echo "[*] Cleaning system logs older than 7 days..."
sudo journalctl --vacuum-time=7d

# ---------------------------------------------------
# STEP 4: Remove old kernels (keep the current one)
# ---------------------------------------------------
# This finds old Linux kernels and removes them
echo "[*] Finding and removing old Linux kernels..."

# Get the currently running kernel version (just the number part)
CURRENT_KERNEL=$(uname -r | sed 's/-generic//')

# Find all installed linux-image packages except the current one
OLD_KERNELS=$(dpkg --list | awk '/linux-image-[0-9]+/{print $2}' | grep -v "$CURRENT_KERNEL" | grep -v "$(uname -r)")

# If there are old kernels found, remove them
if [ -n "$OLD_KERNELS" ]; then
    echo "[*] Removing the following old kernels:"
    echo "$OLD_KERNELS"
    sudo apt purge -y $OLD_KERNELS
else
    echo "[*] No old kernels found to remove."
fi

# ---------------------------------------------------
# STEP 5 (Optional): Clean up Docker stuff
# ---------------------------------------------------
# Ask the user if they want to delete unused Docker stuff
read -p "[?] Do you want to remove ALL unused Docker data (images, containers, volumes)? (y/N): " DOCKER_CONFIRM

# If the user says yes, run the Docker prune command
if [[ "$DOCKER_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[*] Cleaning up Docker data..."
    sudo docker system prune -a -f --volumes
else
    echo "[*] Skipping Docker cleanup."
fi

# ---------------------------------------------------
# STEP 6: Show how much disk space is used now
# ---------------------------------------------------
echo "[*] Disk usage after cleanup:"
sudo df -h

# -------------------
# All done!
# -------------------
echo "[✓] Cleanup finished!"
