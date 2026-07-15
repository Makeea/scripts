#!/bin/bash
# ===============================================================================
# remove-os-junk.sh - Recursive OS junk file cleaner
# ===============================================================================
# DESCRIPTION: Recursively finds OS-generated junk files and folders
#              (macOS, Windows, Linux) under a target directory and sends
#              them to the desktop trash (gio/trash-cli/macOS Finder trash).
#              Does NOT touch build artifacts, caches, version control, or
#              archive/compressed files. Falls back to permanent delete with
#              a clear warning if no trash utility is available.
#
# USAGE: ./remove-os-junk.sh [--path <dir>] [--dry-run] [--permanent]
# ===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

TARGET_PATH="."
DRY_RUN=false
PERMANENT=false
TRASH_WARNED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            TARGET_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --permanent)
            PERMANENT=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./remove-os-junk.sh [--path <dir>] [--dry-run] [--permanent]"
            echo ""
            echo "Recursively removes OS junk files/folders (macOS, Windows, Linux)."
            echo "By default items are sent to trash; --permanent deletes them for good."
            echo "Archive/compressed files are never touched."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

if [[ ! -d "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: Directory '$TARGET_PATH' does not exist${NC}"
    exit 1
fi

TARGET_PATH=$(realpath "$TARGET_PATH")

# Junk directories, removed whole (with contents)
junk_dir_names=("__MACOSX" ".Spotlight-V100" ".Trashes" ".fseventsd" ".AppleDouble")
junk_dir_patterns=(".Trash-*")

# Junk files, matched by name/pattern
junk_file_patterns=(
    ".DS_Store" "._*" ".apdisk" ".localized"
    "Thumbs.db" "ehthumbs.db" "ehthumbs_vista.db" "desktop.ini" "*.lnk" "*Zone.Identifier*"
    "*~" ".nfs*" ".directory"
)

format_size() {
    local size=$1
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$((size/1024))KB"
    else
        echo "$((size/1048576))MB"
    fi
}

# Sends a file/folder to trash, falling back to permanent delete if no trash
# utility is available (warns once). Sets LAST_METHOD to "trash" or
# "permanent" so the caller can report accurately.
trash_item() {
    local item="$1"

    if [[ "$PERMANENT" == true ]]; then
        rm -rf "$item"
        LAST_METHOD="permanent"
        return
    fi

    if command -v gio &>/dev/null && gio trash "$item" 2>/dev/null; then
        LAST_METHOD="trash"
        return
    fi
    if command -v trash-put &>/dev/null && trash-put "$item" 2>/dev/null; then
        LAST_METHOD="trash"
        return
    fi
    if command -v trash &>/dev/null && trash "$item" 2>/dev/null; then
        LAST_METHOD="trash"
        return
    fi
    if [[ "$(uname -s)" == "Darwin" ]] && osascript -e "tell application \"Finder\" to delete POSIX file \"$item\"" &>/dev/null; then
        LAST_METHOD="trash"
        return
    fi

    if [[ "$TRASH_WARNED" == false ]]; then
        echo -e "${YELLOW}No trash utility found (install trash-cli: 'sudo apt install trash-cli', or 'gio' via glib2). Falling back to permanent delete.${NC}"
        TRASH_WARNED=true
    fi
    rm -rf "$item"
    LAST_METHOD="permanent"
}

verb_would="Would trash"
if [[ "$PERMANENT" == true ]]; then
    verb_would="Would permanently delete"
fi

echo -e "${CYAN}=== OS Junk Cleanup ===${NC}"
echo -e "${YELLOW}Target: $TARGET_PATH${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${MAGENTA}Mode: DRY RUN (preview only)${NC}"
elif [[ "$PERMANENT" == true ]]; then
    echo -e "${RED}Mode: LIVE CLEANUP (permanent delete)${NC}"
else
    echo -e "${RED}Mode: LIVE CLEANUP (trash)${NC}"
fi
echo ""

files_processed=0
folders_processed=0
size_freed=0

# Find matching directories, drop nested matches inside an already-matched dir
found_dirs=()
for name in "${junk_dir_names[@]}"; do
    while IFS= read -r -d '' dir; do
        found_dirs+=("$dir")
    done < <(find "$TARGET_PATH" -name "$name" -type d -print0 2>/dev/null)
done
for pattern in "${junk_dir_patterns[@]}"; do
    while IFS= read -r -d '' dir; do
        found_dirs+=("$dir")
    done < <(find "$TARGET_PATH" -name "$pattern" -type d -print0 2>/dev/null)
done

top_level_dirs=()
for dir in "${found_dirs[@]}"; do
    is_nested=false
    for other in "${found_dirs[@]}"; do
        if [[ "$dir" != "$other" && "$dir" == "$other"/* ]]; then
            is_nested=true
            break
        fi
    done
    if [[ "$is_nested" == false ]]; then
        top_level_dirs+=("$dir")
    fi
done

for dir in "${top_level_dirs[@]}"; do
    relative=".${dir#$TARGET_PATH}"
    size=$(du -sb "$dir" 2>/dev/null | cut -f1)
    [[ -z "$size" ]] && size=0

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}$verb_would folder: $relative ($(format_size $size))${NC}"
    else
        if [[ -d "$dir" ]]; then
            trash_item "$dir"
            verb="Trashed"; [[ "$LAST_METHOD" == "permanent" ]] && verb="Deleted (permanent)"
            echo -e "${RED}$verb folder: $relative ($(format_size $size))${NC}"
            ((folders_processed++))
            ((size_freed += size))
        fi
    fi
done

# Find matching files, skipping anything inside an already-processed junk dir
found_files=()
for pattern in "${junk_file_patterns[@]}"; do
    while IFS= read -r -d '' file; do
        found_files+=("$file")
    done < <(find "$TARGET_PATH" -name "$pattern" -type f -print0 2>/dev/null)
done

for file in "${found_files[@]}"; do
    skip=false
    for dir in "${top_level_dirs[@]}"; do
        if [[ "$file" == "$dir"/* ]]; then
            skip=true
            break
        fi
    done
    [[ "$skip" == true ]] && continue

    relative=".${file#$TARGET_PATH}"
    size=$(stat -c%s "$file" 2>/dev/null || echo 0)

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}$verb_would $relative ($(format_size $size))${NC}"
    else
        if [[ -f "$file" ]]; then
            trash_item "$file"
            verb="Trashed"; [[ "$LAST_METHOD" == "permanent" ]] && verb="Deleted (permanent)"
            echo -e "${RED}$verb $relative ($(format_size $size))${NC}"
            ((files_processed++))
            ((size_freed += size))
        fi
    fi
done

echo ""
echo -e "${CYAN}=== SUMMARY ===${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${WHITE}Would process ${#found_files[@]} file(s) and ${#top_level_dirs[@]} folder(s)${NC}"
    echo -e "${MAGENTA}\nDRY RUN - nothing was touched. Run without --dry-run to clean.${NC}"
else
    echo -e "${WHITE}Files processed: $files_processed${NC}"
    echo -e "${WHITE}Folders processed: $folders_processed${NC}"
    echo -e "${WHITE}Space freed: $(format_size $size_freed)${NC}"
    if [[ "$PERMANENT" == true ]]; then
        echo -e "${GREEN}\nCleanup complete! (permanently deleted, not recoverable)${NC}"
    elif [[ "$TRASH_WARNED" == true ]]; then
        echo -e "${GREEN}\nCleanup complete! (no trash utility found - items were permanently deleted)${NC}"
    else
        echo -e "${GREEN}\nCleanup complete! Items were sent to trash.${NC}"
    fi
fi
