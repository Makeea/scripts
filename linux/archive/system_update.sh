#!/bin/bash

# =====================================
# Ubuntu 24.04 Updater Script (Beginner Style)
# =====================================
# This script updates all packages, handles cleanup,
# and optionally installs packages that are usually held back.
# It will also reboot if required.

# -------------------------------
# STEP 1: Update package list
# -------------------------------
echo "[*] Updating package list..."
sudo apt update

# --------------------------------------------
# STEP 2: Upgrade all packages (phased too)
# --------------------------------------------
echo "[*] Upgrading packages including phased updates..."
sudo apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y

# -------------------------------------------------------
# STEP 3: Full upgrade handles dependency changes, etc.
# -------------------------------------------------------
echo "[*] Performing full upgrade..."
sudo apt full-upgrade -y

# ------------------------------------------
# STEP 4: Ask if user wants to install held-back packages
# ------------------------------------------
read -t 10 -p "[?] Install held-back packages too? (y/N): " HELD

# If no input (timeout or empty), default to no
HELD=${HELD:-n}

if [[ "$HELD" =~ ^[Yy]$ ]]; then
    echo "[*] Installing held-back packages..."
    # This finds packages that are still upgradable and tries to install them directly
    sudo apt install -y $(apt list --upgradable 2>/dev/null | grep -v "Listing..." | cut -d/ -f1)
else
    echo "[*] Skipping held-back packages."
fi

# ----------------------------
# STEP 5: Clean up the system
# ----------------------------
echo "[*] Cleaning up unused packages and cache..."
sudo apt autoremove -y
sudo apt autoclean

# ----------------------------
# STEP 6: Reboot if needed
# ----------------------------
if [ -f /var/run/reboot-required ]; then
    echo "[!] A reboot is required to finish updates."
    read -p "Do you want to reboot now? (y/N): " REBOOT_CONFIRM
    if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[*] Rebooting now..."
        sudo reboot
    else
        echo "[*] Reboot skipped. Please remember to do it later."
    fi
else
    echo "[✓] System is fully updated. No reboot needed!"
fi
