#!/bin/bash

# Function to read user input for source type
get_source_type() {
    read -p "Enter source type (local/ssh): " SOURCE_TYPE
}

# Function to read user input for server details
get_server_details() {
    read -p "Enter server details (username@ip): " SERVER
}

# Function to read user input for source folder path
get_source_path() {
    if [ "$SOURCE_TYPE" == "local" ]; then
        read -p "Enter local source folder path: " SOURCE_PATH
    else
        SOURCE_PATH=""
    fi
}

# Function to read user input for additional flags
get_additional_flags() {
    read -p "Enter additional rsync flags (e.g., -uav): " ADDITIONAL_FLAGS
}

# Main script
echo "Rsync Backup Script"

# Get source type
get_source_type

# Get server details
get_server_details

# Get source folder path
get_source_path

# Get additional rsync flags
get_additional_flags

# Build rsync command
RSYNC_COMMAND="rsync $ADDITIONAL_FLAGS --info=progress2 --human-readable"

if [ "$SOURCE_TYPE" == "local" ]; then
    RSYNC_COMMAND="$RSYNC_COMMAND $SOURCE_PATH"
else
    RSYNC_COMMAND="$RSYNC_COMMAND $SERVER:$SOURCE_PATH"
fi

# Prompt user to confirm and execute rsync command
read -p "Ready to execute the following rsync command? (y/n): $RSYNC_COMMAND " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    $RSYNC_COMMAND
    echo "Rsync operation completed."
else
    echo "Rsync operation aborted."
fi
