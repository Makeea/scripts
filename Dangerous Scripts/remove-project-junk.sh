#!/bin/bash
# ===============================================================================
# remove-project-junk.sh - Linux Bash Project Cleanup Script
# ===============================================================================
# AUTHOR: Claire Rosario
# CREATED: Saturday, June 07, 2025
# VERSION: 2.0
#
# DESCRIPTION: Removes system files, build artifacts, and junk from projects
#              Designed for Linux/Unix systems with interactive prompts
#
# USAGE: ./remove-project-junk.sh [OPTIONS]
# Run with --help for detailed usage information
# ===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Default settings
DRY_RUN=false
FORCE=false
VERBOSE=false
QUIET=false
SKIP_GIT=false
SKIP_ARCHIVES=false
ONLY_SYSTEM_FILES=false
ONLY_BUILD_FILES=false
SKIP_EMPTY_DIRS=false
TARGET_PATH="."
LOG_FILE=""
MAX_FILE_SIZE_MB=""

# Statistics
FILES_DELETED=0
FOLDERS_DELETED=0
SIZE_FREED=0
GIT_FILES_REMOVED=0
ERRORS_ENCOUNTERED=0
START_TIME=$(date +%s)

# Help function
show_help() {
    echo -e "${CYAN}remove-project-junk.sh - Linux Bash Project Cleanup Script${NC}"
    echo ""
    echo "USAGE:"
    echo "  ./remove-project-junk.sh [OPTIONS]"
    echo ""
    echo "BASIC OPTIONS:"
    echo "  --dry-run              Preview what would be deleted (RECOMMENDED FIRST)"
    echo "  --force                Skip all confirmation prompts"
    echo "  --path PATH            Target directory (default: current)"
    echo ""
    echo "OUTPUT OPTIONS:"
    echo "  --verbose              Show detailed file operations"
    echo "  --quiet                Minimal output"
    echo "  --log-file FILE        Save detailed log to file"
    echo ""
    echo "CLEANUP MODES:"
    echo "  --only-system-files    Clean only OS system files"
    echo "  --only-build-files     Clean only build artifacts and cache"
    echo "  --skip-git             Don't remove files from Git tracking"
    echo "  --skip-archives        Don't delete archive files"
    echo "  --skip-empty-dirs      Don't remove empty directories"
    echo ""
    echo "CUSTOM OPTIONS:"
    echo "  --max-file-size-mb N   Don't delete files larger than N MB"
    echo ""
    echo "HELP:"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  ./remove-project-junk.sh --dry-run"
    echo "  ./remove-project-junk.sh --only-system-files"
    echo "  ./remove-project-junk.sh --force --skip-archives"
    echo ""
    echo "WHAT IT CLEANS:"
    echo -e "  ${GREEN}✓${NC} Linux: *~, .nfs*, .Trash-*"
    echo -e "  ${GREEN}✓${NC} macOS: .DS_Store, ._*, .Spotlight-V100"
    echo -e "  ${GREEN}✓${NC} Windows: Thumbs.db, Desktop.ini, *.lnk"
    echo -e "  ${GREEN}✓${NC} Build: node_modules, __pycache__, target, dist"
    echo -e "  ${GREEN}✓${NC} Cache: .cache, tmp, .sass-cache"
    echo -e "  ${GREEN}✓${NC} Logs: *.log, npm-debug.log*"
    echo -e "  ${GREEN}✓${NC} Backups: *.bak, *.swp, *.tmp"
    echo -e "  ${GREEN}✓${NC} Empty directories"
    echo ""
    echo "Make executable: chmod +x remove-project-junk.sh"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --skip-git)
            SKIP_GIT=true
            shift
            ;;
        --skip-archives)
            SKIP_ARCHIVES=true
            shift
            ;;
        --only-system-files)
            ONLY_SYSTEM_FILES=true
            shift
            ;;
        --only-build-files)
            ONLY_BUILD_FILES=true
            shift
            ;;
        --skip-empty-dirs)
            SKIP_EMPTY_DIRS=true
            shift
            ;;
        --path)
            TARGET_PATH="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --max-file-size-mb)
            MAX_FILE_SIZE_MB="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate target path
if [[ ! -d "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: Directory '$TARGET_PATH' does not exist${NC}"
    exit 1
fi

# Convert to absolute path
TARGET_PATH=$(realpath "$TARGET_PATH")

# Initialize logging
if [[ -n "$LOG_FILE" ]]; then
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi
    echo "=== Cleanup Started: $(date) ===" > "$LOG_FILE"
    echo "Parameters: DryRun=$DRY_RUN, Force=$FORCE, Path=$TARGET_PATH" >> "$LOG_FILE"
fi

# Logging function
log_message() {
    local level="$1"
    local color="$2"
    local message="$3"
    
    if [[ "$QUIET" == false || "$level" == "ERROR" ]]; then
        echo -e "${color}${message}${NC}"
    fi
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    fi
}

# Display header
if [[ "$QUIET" == false ]]; then
    log_message "INFO" "$CYAN" "=== LINUX BASH CLEANUP v2.0 ==="
    log_message "INFO" "$YELLOW" "Target: $TARGET_PATH"
    if [[ "$DRY_RUN" == true ]]; then
        log_message "INFO" "$MAGENTA" "Mode: DRY RUN (Preview Only)"
    else
        log_message "INFO" "$RED" "Mode: LIVE CLEANUP"
    fi
    
    # Show active options
    options=()
    [[ "$FORCE" == true ]] && options+=("Force")
    [[ "$VERBOSE" == true ]] && options+=("Verbose")
    [[ "$ONLY_SYSTEM_FILES" == true ]] && options+=("OnlySystemFiles")
    [[ "$ONLY_BUILD_FILES" == true ]] && options+=("OnlyBuildFiles")
    [[ "$SKIP_GIT" == true ]] && options+=("SkipGit")
    [[ "$SKIP_ARCHIVES" == true ]] && options+=("SkipArchives")
    
    if [[ ${#options[@]} -gt 0 ]]; then
        IFS=', '
        log_message "INFO" "$CYAN" "Options: ${options[*]}"
        unset IFS
    fi
    log_message "INFO" "$CYAN" "$(printf '=%.0s' {1..50})"
fi

# Size formatting function
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

# Check file size function
check_file_size() {
    local file_path="$1"
    
    if [[ -n "$MAX_FILE_SIZE_MB" ]]; then
        local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo 0)
        local size_mb=$((file_size / 1048576))
        if [[ $size_mb -gt $MAX_FILE_SIZE_MB ]]; then
            return 1
        fi
    fi
    return 0
}

# Show items and prompt function
show_and_prompt() {
    local category="$1"
    local item_type="$2"
    shift 2
    local items=("$@")
    
    if [[ ${#items[@]} -eq 0 ]]; then
        return 1
    fi
    
    log_message "INFO" "$GREEN" "\n--- $category ---"
    log_message "INFO" "$YELLOW" "Found ${#items[@]} $item_type:"
    
    # Show all items with paths and sizes
    for item in "${items[@]}"; do
        local relative_path="${item#$TARGET_PATH}"
        if [[ "$relative_path" == "$item" ]]; then
            relative_path="$item"
        else
            relative_path=".${relative_path}"
        fi
        
        if [[ "$item_type" == "folders" ]]; then
            local size=$(du -sb "$item" 2>/dev/null | cut -f1 || echo 0)
            log_message "INFO" "$WHITE" "  → $relative_path ($(format_size $size))"
        else
            # Check file size limits
            if ! check_file_size "$item"; then
                if [[ "$VERBOSE" == true ]]; then
                    log_message "INFO" "$YELLOW" "  ⚠ Skipped (too large): $relative_path"
                fi
                continue
            fi
            
            local size=$(stat -c%s "$item" 2>/dev/null || echo 0)
            log_message "INFO" "$WHITE" "  → $relative_path ($(format_size $size))"
        fi
    done
    
    # Interactive prompt
    if [[ "$DRY_RUN" == false && "$FORCE" == false ]]; then
        echo -e -n "${CYAN}Delete all items in '$category'? You have 5 seconds to decide (default: Yes)...${NC}\n"
        echo -e -n "${CYAN}Press 'n' and Enter to skip, or wait 5 seconds to proceed: ${NC}"
        
        if read -t 5 -r response; then
            if [[ "$response" =~ ^[nN] ]]; then
                log_message "INFO" "$YELLOW" "Skipped $category"
                return 1
            fi
        else
            echo ""
            log_message "INFO" "$GREEN" "Time expired - proceeding with cleanup..."
        fi
    fi
    return 0
}

# Delete items function
delete_items() {
    local item_type="$1"
    shift
    local items=("$@")
    
    for item in "${items[@]}"; do
        # Skip if item no longer exists
        if [[ ! -e "$item" ]]; then
            continue
        fi
        
        local relative_path="${item#$TARGET_PATH}"
        if [[ "$relative_path" == "$item" ]]; then
            relative_path="$item"
        else
            relative_path=".${relative_path}"
        fi
        
        # Check file size limits for files
        if [[ "$item_type" == "file" ]] && ! check_file_size "$item"; then
            continue
        fi
        
        if [[ "$DRY_RUN" == true ]]; then
            log_message "INFO" "$YELLOW" "Would delete: $relative_path"
        else
            if [[ "$item_type" == "folder" ]]; then
                if rm -rf "$item" 2>/dev/null; then
                    log_message "INFO" "$RED" "Deleted folder: $relative_path"
                    ((FOLDERS_DELETED++))
                    [[ -n "$LOG_FILE" ]] && echo "Deleted folder: $relative_path" >> "$LOG_FILE"
                else
                    log_message "ERROR" "$RED" "Failed folder: $relative_path"
                    ((ERRORS_ENCOUNTERED++))
                fi
            else
                local file_size=$(stat -c%s "$item" 2>/dev/null || echo 0)
                if rm -f "$item" 2>/dev/null; then
                    log_message "INFO" "$RED" "Deleted: $relative_path"
                    ((FILES_DELETED++))
                    ((SIZE_FREED += file_size))
                    [[ -n "$LOG_FILE" ]] && echo "Deleted: $relative_path" >> "$LOG_FILE"
                else
                    log_message "ERROR" "$RED" "Failed: $relative_path"
                    ((ERRORS_ENCOUNTERED++))
                fi
            fi
        fi
    done
}

# Git removal function
remove_from_git() {
    local category="$1"
    shift
    local patterns=("$@")
    
    if [[ "$SKIP_GIT" == true || ! -d ".git" ]]; then
        return
    fi
    
    for pattern in "${patterns[@]}"; do
        if git rm -r --cached "$pattern" &>/dev/null; then
            if [[ "$VERBOSE" == true ]]; then
                log_message "INFO" "$CYAN" "Removed from Git: $pattern"
            fi
            ((GIT_FILES_REMOVED++))
        fi
    done
}

# MAIN CLEANUP PROCESS
log_message "INFO" "$YELLOW" "Starting cleanup process..."

# Change to target directory
cd "$TARGET_PATH" || exit 1

# File patterns by category
declare -A file_patterns
file_patterns["Linux System Files"]="*~ .nfs*"
file_patterns["macOS Files (from Mac devs)"]=".DS_Store ._* .Spotlight-V100 .Trashes .fseventsd .localized"
file_patterns["Windows Files (from Win devs)"]="Thumbs.db ehthumbs.db Desktop.ini *.lnk *.stackdump"
file_patterns["Editor Backup Files"]="*.bak *.old *.orig *.swp *.swo *.tmp *.temp"
file_patterns["Development Log Files"]="*.log npm-debug.log* yarn-debug.log* yarn-error.log* debug.log"
file_patterns["Cache Files"]=".eslintcache .sass-cache *.cache .nyc_output .coverage"

# Folder patterns by category
declare -A folder_patterns
folder_patterns["Build Directories"]="node_modules __pycache__ .pytest_cache target build dist bin obj .next .nuxt"
folder_patterns["Cache Directories"]=".cache cache .tmp tmp temp .sass-cache .parcel-cache"
folder_patterns["System Directories"]=".Trash-* .AppleDouble .LSOverride"
folder_patterns["IDE Directories"]=".vscode .idea .settings .metadata .vs .venv venv .tox"

# Process file patterns
if [[ "$ONLY_BUILD_FILES" == false ]]; then
    for category in "${!file_patterns[@]}"; do
        # Skip non-system files if only cleaning system files
        if [[ "$ONLY_SYSTEM_FILES" == true && "$category" != *"System Files"* && "$category" != *"Files"* ]]; then
            continue
        fi
        
        files=()
        pattern_array=(${file_patterns[$category]})
        
        for pattern in "${pattern_array[@]}"; do
            while IFS= read -r -d '' file; do
                if [[ -f "$file" ]]; then
                    files+=("$file")
                fi
            done < <(find "$TARGET_PATH" -name "$pattern" -type f -print0 2>/dev/null)
        done
        
        if show_and_prompt "$category" "files" "${files[@]}"; then
            delete_items "file" "${files[@]}"
            if [[ "$DRY_RUN" == false ]]; then
                remove_from_git "$category" "${pattern_array[@]}"
            fi
        fi
    done
fi

# Process folder patterns
if [[ "$ONLY_SYSTEM_FILES" == false ]]; then
    for category in "${!folder_patterns[@]}"; do
        # Skip non-build folders if only cleaning build files
        if [[ "$ONLY_BUILD_FILES" == true && "$category" != *"Build"* && "$category" != *"Cache"* ]]; then
            continue
        fi
        
        folders=()
        pattern_array=(${folder_patterns[$category]})
        
        for pattern in "${pattern_array[@]}"; do
            while IFS= read -r -d '' folder; do
                if [[ -d "$folder" ]]; then
                    folders+=("$folder")
                fi
            done < <(find "$TARGET_PATH" -name "$pattern" -type d -print0 2>/dev/null)
        done
        
        if show_and_prompt "$category" "folders" "${folders[@]}"; then
            delete_items "folder" "${folders[@]}"
        fi
    done
fi

# Handle compiled files
if [[ "$ONLY_SYSTEM_FILES" == false ]]; then
    compiled_files=()
    compiled_extensions=("*.pyc" "*.pyo" "*.class" "*.o" "*.obj" "*.so" "*.a")
    
    for ext in "${compiled_extensions[@]}"; do
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                compiled_files+=("$file")
            fi
        done < <(find "$TARGET_PATH" -name "$ext" -type f -print0 2>/dev/null)
    done
    
    if show_and_prompt "Compiled Files" "files" "${compiled_files[@]}"; then
        delete_items "file" "${compiled_files[@]}"
    fi
fi

# Handle archive files
if [[ "$ONLY_SYSTEM_FILES" == false && "$SKIP_ARCHIVES" == false ]]; then
    archive_files=()
    archive_extensions=("*.zip" "*.rar" "*.7z" "*.tar" "*.gz" "*.bz2" "*.xz")
    
    for ext in "${archive_extensions[@]}"; do
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                archive_files+=("$file")
            fi
        done < <(find "$TARGET_PATH" -name "$ext" -type f -print0 2>/dev/null)
    done
    
    if show_and_prompt "Archive Files" "files" "${archive_files[@]}"; then
        delete_items "file" "${archive_files[@]}"
    fi
fi

# Handle empty directories
if [[ "$SKIP_EMPTY_DIRS" == false ]]; then
    empty_dirs=()
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" && $(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l) -eq 0 ]]; then
            empty_dirs+=("$dir")
        fi
    done < <(find "$TARGET_PATH" -type d -print0 2>/dev/null)
    
    if show_and_prompt "Empty Directories" "folders" "${empty_dirs[@]}"; then
        delete_items "folder" "${empty_dirs[@]}"
    fi
fi

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Final summary
if [[ "$QUIET" == false ]]; then
    log_message "INFO" "$CYAN" "\n=== CLEANUP SUMMARY ==="
    log_message "INFO" "$WHITE" "Files deleted: $FILES_DELETED"
    log_message "INFO" "$WHITE" "Folders deleted: $FOLDERS_DELETED"
    log_message "INFO" "$WHITE" "Space freed: $(format_size $SIZE_FREED)"
    if [[ "$SKIP_GIT" == false ]]; then
        log_message "INFO" "$WHITE" "Git files removed: $GIT_FILES_REMOVED"
    fi
    if [[ $ERRORS_ENCOUNTERED -gt 0 ]]; then
        log_message "INFO" "$RED" "Errors: $ERRORS_ENCOUNTERED"
    else
        log_message "INFO" "$WHITE" "Errors: $ERRORS_ENCOUNTERED"
    fi
    log_message "INFO" "$WHITE" "Time: ${EXECUTION_TIME} seconds"

    if [[ "$DRY_RUN" == true ]]; then
        log_message "INFO" "$MAGENTA" "\nDRY RUN - No files were deleted. Run without --dry-run to clean."
    else
        log_message "INFO" "$GREEN" "\nCleanup completed!"
        if [[ -d ".git" && $GIT_FILES_REMOVED -gt 0 && "$SKIP_GIT" == false ]]; then
            log_message "INFO" "$YELLOW" "Next steps: git status, then git commit -m 'Remove junk files'"
        fi
    fi
fi

# Finalize logging
if [[ -n "$LOG_FILE" ]]; then
    echo "=== Cleanup Completed: $(date) ===" >> "$LOG_FILE"
    echo "Statistics: Files=$FILES_DELETED, Folders=$FOLDERS_DELETED, Errors=$ERRORS_ENCOUNTERED" >> "$LOG_FILE"
    if [[ "$QUIET" == false ]]; then
        log_message "INFO" "$CYAN" "Log saved to: $LOG_FILE"
    fi
fi

# Exit with appropriate code
if [[ $ERRORS_ENCOUNTERED -gt 0 ]]; then
    exit 1
else
    exit 0
fi