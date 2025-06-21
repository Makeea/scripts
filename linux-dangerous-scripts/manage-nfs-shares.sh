#!/bin/bash

# -----------------------------------------------------------------------------
# Ubuntu NFS Mount/Unmount Script
# Author: Claire Rosario
# Version: 1.7
# Description:
#   Automates mounting/unmounting NFS shares with fstab persistence.
#   Supports dry-run mode, preview/restore of fstab, systemd reload,
#   and logs actions to /var/log/nfs-setup.log
# -----------------------------------------------------------------------------

set -e

# -------------------------------
# CONFIGURATION + FLAGS
# -------------------------------
DRY_RUN=false
SELECTED_SHARES=()
INVOKING_USER=$(logname)
HOME_BASE="/home/$INVOKING_USER"
DEFAULT_MOUNT_BASE="/mnt"
MOUNT_BASE=""
ACTION="mount"
LOG_FILE="/var/log/nfs-setup.log"
FSTAB_BACKUP="/etc/fstab.backup.nfs.$(date +%Y%m%d_%H%M%S)"

# -------------------------------
# UTILITY FUNCTIONS
# -------------------------------

log() {
    echo "[$(date '+%F %T')] $*" | sudo tee -a "$LOG_FILE" > /dev/null
}

print_header() {
    echo -e "\n=== $1 ==="
    log "$1"
}

safe_run() {
    if $DRY_RUN; then
        echo "Dry-run: $*"
        log "Dry-run: $*"
    else
        log "Running: $*"
        eval "$@"
    fi
}

remove_fstab_entry() {
    local share_path="$1"
    local mount_point="$2"
    local line="$NFS_SERVER:$share_path $mount_point nfs defaults,_netdev 0 0"
    sudo sed -i "\|^$line\$|d" /etc/fstab
    log "Removed fstab entry: $line"
}

backup_fstab() {
    if $DRY_RUN; then
        echo "Dry-run: Would back up /etc/fstab to $FSTAB_BACKUP"
        log "Dry-run: Would back up /etc/fstab to $FSTAB_BACKUP"
    else
        sudo cp /etc/fstab "$FSTAB_BACKUP"
        log "Backed up /etc/fstab to $FSTAB_BACKUP"

        echo
        echo "=== Preview of original fstab backup ==="
        cat "$FSTAB_BACKUP"
        echo "=== End preview ==="
    fi
}

# -------------------------------
# RESTORE MODE
# -------------------------------

if ls /etc/fstab.backup.nfs.* 1>/dev/null 2>&1; then
    echo
    echo "Restore option available: You have fstab backups saved."
    echo "Would you like to restore the most recent backup now?"
    read -rp "Restore fstab from backup? [y/N]: " restore_choice
    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        LATEST_BACKUP=$(ls -t /etc/fstab.backup.nfs.* | head -n 1)
        sudo cp "$LATEST_BACKUP" /etc/fstab
        echo "Restored /etc/fstab from $LATEST_BACKUP"
        log "Restored /etc/fstab from $LATEST_BACKUP"
        echo "=== Preview of restored fstab ==="
        cat /etc/fstab
        echo "=== End preview ==="
        exit 0
    fi
fi

# -------------------------------
# MODE SELECTION
# -------------------------------

echo
echo "Choose mode:"
echo "  1) Mount NFS shares"
echo "  2) Remove NFS shares"

read -rp "Enter choice [1 or 2]: " ACTION_CHOICE
case "$ACTION_CHOICE" in
    2)
        ACTION="remove"
        ;;
    *)
        ACTION="mount"
        ;;
esac

# -------------------------------
# ARGUMENT PARSING
# -------------------------------

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Dry run mode enabled — no actual changes will be made."
    log "Dry run mode enabled"
fi

# -------------------------------
# PREREQUISITE CHECK
# -------------------------------

print_header "Checking prerequisites"

if ! command -v showmount &> /dev/null; then
    echo "'showmount' is missing. Required for NFS share discovery."

    if $DRY_RUN; then
        echo "Dry-run: Skipping install of 'nfs-common'. Please install manually:"
        echo "    sudo apt update && sudo apt install -y nfs-common"
        log "Dry-run: would install nfs-common"
        exit 1
    else
        echo "Installing nfs-common..."
        log "Installing nfs-common..."
        sudo apt update && sudo apt install -y nfs-common
    fi
else
    echo "'nfs-common' and 'showmount' are available."
    log "Dependencies verified"
fi

# -------------------------------
# MOUNT BASE PROMPT
# -------------------------------

if [[ "$ACTION" == "mount" ]]; then
    echo
    echo "Choose where to mount the NFS shares:"
    echo "  1) /mnt (default)"
    echo "  2) $HOME_BASE"

    read -rp "Enter choice [1 or 2]: " MOUNT_CHOICE
    case "$MOUNT_CHOICE" in
        2)
            MOUNT_BASE="$HOME_BASE"
            ;;
        *)
            MOUNT_BASE="$DEFAULT_MOUNT_BASE"
            ;;
    esac

    echo "Using mount base: $MOUNT_BASE"
    $DRY_RUN || sudo mkdir -p "$MOUNT_BASE"
    log "Mount base set to $MOUNT_BASE"
else
    echo "Unmount mode selected — will remove entries and mount points."
    log "Mode: remove"
fi

# -------------------------------
# NFS SERVER DISCOVERY
# -------------------------------

read -rp "Enter NFS server IP or hostname: " NFS_SERVER
log "Target NFS server: $NFS_SERVER"

echo "Probing for available NFS exports..."
EXPORTS=$(showmount -e "$NFS_SERVER" 2>/dev/null)

if [[ $? -ne 0 || -z "$EXPORTS" ]]; then
    echo "Could not fetch exports from $NFS_SERVER."
    log "Failed to fetch exports from $NFS_SERVER"
    exit 1
fi

echo -e "\nAvailable NFS Shares on $NFS_SERVER:"
echo "$EXPORTS" | tail -n +2

# -------------------------------
# CHECK CURRENT MOUNTS (REMOVE)
# -------------------------------

if [[ "$ACTION" == "remove" ]]; then
    echo
    echo "Checking currently mounted NFS shares from $NFS_SERVER..."
    mapfile -t CURRENTLY_MOUNTED < <(mount -t nfs | grep "^$NFS_SERVER" | awk '{print $3}')

    if [ ${#CURRENTLY_MOUNTED[@]} -eq 0 ]; then
        echo "No active NFS mounts from $NFS_SERVER found."
    else
        echo "The following NFS shares are currently mounted from $NFS_SERVER:"
        for ((i=0; i<${#CURRENTLY_MOUNTED[@]}; i++)); do
            echo "$((i+1))) ${CURRENTLY_MOUNTED[$i]}"
        done

        read -rp "Would you like to unmount these now? [y/N]: " UNMOUNT_CHOICE
        if [[ "$UNMOUNT_CHOICE" =~ ^[Yy]$ ]]; then
            for mnt in "${CURRENTLY_MOUNTED[@]}"; do
                safe_run sudo umount "$mnt"
                log "Unmounted $mnt (preselected)"
            done
        fi
    fi
fi

# -------------------------------
# SHARE SELECTION
# -------------------------------

echo -e "\nSelect shares to $ACTION (comma-separated numbers):"
i=1
mapfile -t SHARE_LIST < <(echo "$EXPORTS" | tail -n +2 | awk '{print $1}')
for share in "${SHARE_LIST[@]}"; do
    echo "$i) $share"
    ((i++))
done

read -rp "Enter your selection (e.g. 1,3): " SELECTIONS
IFS=',' read -ra INDICES <<< "$SELECTIONS"

for index in "${INDICES[@]}"; do
    SELECTED_SHARES+=("${SHARE_LIST[$((index - 1))]}")
done

# -------------------------------
# BACKUP FSTAB
# -------------------------------

backup_fstab

# -------------------------------
# MOUNT OR REMOVE LOOP
# -------------------------------

for SHARE_PATH in "${SELECTED_SHARES[@]}"; do
    SHARE_NAME=$(basename "$SHARE_PATH")
    MOUNT_POINT="${MOUNT_BASE:-/mnt}/$SHARE_NAME"

    print_header "Processing: $SHARE_PATH → $MOUNT_POINT"

    if [[ "$ACTION" == "mount" ]]; then
        if [ ! -d "$MOUNT_POINT" ]; then
            echo "Creating mount point at $MOUNT_POINT..."
            safe_run sudo mkdir -p "$MOUNT_POINT"
        else
            echo "Mount point already exists."
        fi

        FSTAB_ENTRY="$NFS_SERVER:$SHARE_PATH $MOUNT_POINT nfs defaults,_netdev 0 0"
        if grep -qsF "$FSTAB_ENTRY" /etc/fstab; then
            echo "Entry already exists in /etc/fstab."
            log "Skipped fstab (already present): $FSTAB_ENTRY"
        else
            echo "Adding entry to /etc/fstab..."
            $DRY_RUN || echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
            log "Added to fstab: $FSTAB_ENTRY"
        fi

        echo "Attempting mount..."
        if $DRY_RUN; then
            echo "Dry-run: sudo mount $MOUNT_POINT"
            log "Dry-run: mount $MOUNT_POINT"
        else
            if sudo mount "$MOUNT_POINT"; then
                echo "Mounted successfully."
                log "Mounted $MOUNT_POINT"
            else
                echo "Mount failed."
                log "Failed to mount $MOUNT_POINT"
            fi
        fi

    else
        echo "Attempting unmount..."
        if mountpoint -q "$MOUNT_POINT"; then
            safe_run sudo umount "$MOUNT_POINT"
            log "Unmounted $MOUNT_POINT"
        else
            echo "Not currently mounted."
            log "Not mounted: $MOUNT_POINT"
        fi

        echo "Removing fstab entry..."
        $DRY_RUN || remove_fstab_entry "$SHARE_PATH" "$MOUNT_POINT"

        echo "Removing mount point directory..."
        safe_run sudo rmdir "$MOUNT_POINT" || echo "Could not remove $MOUNT_POINT (may not be empty)"
        log "Attempted to remove mount point $MOUNT_POINT"
    fi
done

# -------------------------------
# PREVIEW MODIFIED FSTAB & SYSTEMD RELOAD
# -------------------------------

if ! $DRY_RUN; then
    echo
    echo "=== Preview of modified /etc/fstab ==="
    cat /etc/fstab
    echo "=== End preview ==="

    read -rp "Reload systemd daemon (systemctl daemon-reexec)? [y/N]: " RELOADD
    if [[ "$RELOADD" =~ ^[Yy]$ ]]; then
        sudo systemctl daemon-reexec
        log "Ran systemctl daemon-reexec"
    fi
fi

# -------------------------------
# FINAL STATUS
# -------------------------------

if [[ "$ACTION" == "mount" ]]; then
    echo -e "\nSetup complete. NFS shares will be mounted automatically on reboot."
    log "Mount operation complete"
else
    echo -e "\nCleanup complete. NFS shares were unmounted and removed."
    log "Unmount operation complete"
fi

if $DRY_RUN; then
    echo "Reminder: No changes were made due to dry-run mode."
    log "Dry run finished with no changes made"
fi
