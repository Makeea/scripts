#!/usr/bin/env bash

# Title: Advanced Rsync Backup Script
# Description: A user-friendly script for creating consistent backups with rsync

# Exit on error
set -e

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
DEFAULT_FLAGS="-avz"
CONFIG_FILE="$HOME/.rsync_backup.conf"
EXCLUDE_FILE="/tmp/rsync_exclude_$$.tmp"

# Function to display colorful headers
print_header() {
    echo -e "\n${GREEN}========== $1 ==========${NC}\n"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    print_error "Error: rsync is not installed. Please install it first."
    exit 1
fi

# Function to load saved configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "Loading saved configuration..."
        source "$CONFIG_FILE"
        print_info "Loaded configuration with the following details:"
        echo "Source Type: $SOURCE_TYPE"
        [[ -n "$SERVER" ]] && echo "Server: $SERVER"
        echo "Source Path: $SOURCE_PATH"
        echo "Destination Path: $DEST_PATH"
        echo "Additional Flags: $ADDITIONAL_FLAGS"
        
        read -p "Use this configuration? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        return 0
    fi
    return 1
}

# Function to save configuration
save_config() {
    read -p "Save this configuration for future use? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "SOURCE_TYPE=\"$SOURCE_TYPE\"" > "$CONFIG_FILE"
        echo "SERVER=\"$SERVER\"" >> "$CONFIG_FILE"
        echo "SOURCE_PATH=\"$SOURCE_PATH\"" >> "$CONFIG_FILE"
        echo "DEST_PATH=\"$DEST_PATH\"" >> "$CONFIG_FILE"
        echo "ADDITIONAL_FLAGS=\"$ADDITIONAL_FLAGS\"" >> "$CONFIG_FILE"
        echo "EXCLUDE_PATTERNS=\"$EXCLUDE_PATTERNS\"" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"  # Set secure permissions
        print_info "Configuration saved to $CONFIG_FILE"
    fi
}

# Function to read user input for source type
get_source_type() {
    while true; do
        read -p "Enter source type (local/ssh) [local]: " input_source_type
        SOURCE_TYPE="${input_source_type:-local}"
        
        if [[ "$SOURCE_TYPE" == "local" || "$SOURCE_TYPE" == "ssh" ]]; then
            break
        else
            print_error "Invalid input. Please enter 'local' or 'ssh'."
        fi
    done
}

# Function to read user input for server details
get_server_details() {
    if [[ "$SOURCE_TYPE" == "ssh" ]]; then
        while true; do
            read -p "Enter server details (username@hostname): " SERVER
            if [[ -n "$SERVER" && "$SERVER" =~ ^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$ ]]; then
                # Test SSH connection
                print_info "Testing SSH connection..."
                if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" echo "Connection successful" &> /dev/null; then
                    print_info "SSH connection successful!"
                    break
                else
                    print_error "Failed to connect to $SERVER. Please check your SSH configuration."
                    read -p "Retry? (y/n): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_error "Exiting script."
                        exit 1
                    fi
                fi
            else
                print_error "Invalid server format. Please use 'username@hostname'."
            fi
        done
    else
        SERVER=""
    fi
}

# Function to read user input for source folder path
get_source_path() {
    while true; do
        if [[ "$SOURCE_TYPE" == "local" ]]; then
            read -p "Enter local source folder path: " SOURCE_PATH
            # Validate local path exists
            if [[ -d "$SOURCE_PATH" ]]; then
                SOURCE_PATH=$(realpath "$SOURCE_PATH")
                break
            else
                print_error "Directory does not exist: $SOURCE_PATH"
                continue
            fi
        else
            read -p "Enter remote source folder path: " SOURCE_PATH
            # Basic validation for remote path
            if [[ -n "$SOURCE_PATH" ]]; then
                # Test if the remote path exists
                if ssh "$SERVER" "[[ -d \"$SOURCE_PATH\" ]]"; then
                    break
                else
                    print_error "Remote directory does not exist: $SOURCE_PATH"
                    continue
                fi
            else
                print_error "Source path cannot be empty."
            fi
        fi
    done
}

# Function to read user input for destination folder path
get_destination_path() {
    while true; do
        read -p "Enter destination folder path: " DEST_PATH
        
        # Validate path or create it
        if [[ ! -d "$DEST_PATH" ]]; then
            read -p "Directory does not exist. Create it? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p "$DEST_PATH"
            else
                continue
            fi
        fi
        
        DEST_PATH=$(realpath "$DEST_PATH")
        break
    done
}

# Function to read user input for exclude patterns
get_exclude_patterns() {
    read -p "Enter patterns to exclude (comma-separated, leave empty for none): " EXCLUDE_PATTERNS
    
    if [[ -n "$EXCLUDE_PATTERNS" ]]; then
        # Create temporary exclude file
        > "$EXCLUDE_FILE"
        
        # Convert comma-separated list to line-by-line file
        IFS=',' read -ra PATTERNS <<< "$EXCLUDE_PATTERNS"
        for pattern in "${PATTERNS[@]}"; do
            echo "${pattern// /}" >> "$EXCLUDE_FILE"
        done
    fi
}

# Function to read user input for additional flags
get_additional_flags() {
    read -p "Enter additional rsync flags [${DEFAULT_FLAGS}]: " input_flags
    ADDITIONAL_FLAGS="${input_flags:-$DEFAULT_FLAGS}"
}

# Function to build and execute rsync command
execute_rsync() {
    # Build base rsync command with progress
    RSYNC_CMD="rsync $ADDITIONAL_FLAGS --info=progress2 --human-readable"
    
    # Add exclude file if it exists
    if [[ -f "$EXCLUDE_FILE" && -s "$EXCLUDE_FILE" ]]; then
        RSYNC_CMD="$RSYNC_CMD --exclude-from=$EXCLUDE_FILE"
    fi
    
    # Add source
    if [[ "$SOURCE_TYPE" == "ssh" ]]; then
        RSYNC_CMD="$RSYNC_CMD $SERVER:\"$SOURCE_PATH\""
    else
        RSYNC_CMD="$RSYNC_CMD \"$SOURCE_PATH\""
    fi
    
    # Add destination with trailing slash to copy contents
    RSYNC_CMD="$RSYNC_CMD \"$DEST_PATH/\""
    
    # Display command and prompt for confirmation
    print_info "Ready to execute the following rsync command:"
    echo "$RSYNC_CMD"
    
    read -p "Execute this command? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_header "Starting Rsync Operation"
        
        # Add dry-run option for testing
        read -p "Run in dry-run mode first (no actual changes)? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Running in dry-run mode..."
            eval "$RSYNC_CMD --dry-run"
            
            read -p "Proceed with actual operation? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_warning "Rsync operation aborted."
                return
            fi
        fi
        
        # Execute the rsync command
        START_TIME=$(date +%s)
        eval "$RSYNC_CMD"
        END_TIME=$(date +%s)
        
        # Calculate duration
        DURATION=$((END_TIME - START_TIME))
        HOURS=$((DURATION / 3600))
        MINUTES=$(( (DURATION % 3600) / 60 ))
        SECONDS=$((DURATION % 60))
        
        print_header "Rsync Operation Completed"
        print_info "Duration: ${HOURS}h ${MINUTES}m ${SECONDS}s"
        
        # Calculate space used
        if [[ -d "$DEST_PATH" ]]; then
            SPACE_USED=$(du -sh "$DEST_PATH" | cut -f1)
            print_info "Backup size: $SPACE_USED"
        fi
    else
        print_warning "Rsync operation aborted."
    fi
}

# Cleanup function to remove temporary files
cleanup() {
    [[ -f "$EXCLUDE_FILE" ]] && rm -f "$EXCLUDE_FILE"
}

# Register cleanup on script exit
trap cleanup EXIT

# Main script
print_header "Advanced Rsync Backup Script"

# Try to load saved configuration
if ! load_config; then
    # Get all required inputs
    get_source_type
    [[ "$SOURCE_TYPE" == "ssh" ]] && get_server_details
    get_source_path
    get_destination_path
    get_exclude_patterns
    get_additional_flags
    
    # Save configuration for future use
    save_config
fi

# Execute rsync
execute_rsync

print_header "Backup Process Complete"