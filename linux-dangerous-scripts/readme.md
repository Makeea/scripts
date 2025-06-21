# ⚠️ Dangerous Scripts

> **WARNING**  
> Use the scripts in this folder **with extreme caution**.

These scripts are designed to perform powerful, automated actions — including modifications, deletions, or system-level changes — that can result in **data loss, corruption, or unrecoverable damage** if used improperly.

- There is **no warranty**.
- There is **no support**.
- If you use these scripts incorrectly, **you are fully responsible for the outcome**.

These are intended for experienced users who understand the risks. Do **not** run anything in this directory unless you've thoroughly reviewed and understood the code.

**Proceed at your own risk.**

---

## 🧹 remove-project-junk.sh (Linux / Unix)

A powerful and potentially destructive project cleanup script that recursively deletes common junk files, build artifacts, backups, logs, and more from project directories.

> ⚠️ **Use `--dry-run` first. This script can delete folders and files permanently.**

### 🆘 Help

```bash
./remove-project-junk.sh --help
```

---

## 🧹 Remove-ProjectJunk.ps1 (Windows PowerShell)

A comprehensive and potentially destructive project cleanup script for Windows that recursively scans and deletes system files, build artifacts, cache files, and development junk from project directories.

> ⚠️ **Use `-DryRun` first. This script can delete folders and files permanently.**

### ⚡ Quick Start

```powershell
# ALWAYS preview first - shows what would be deleted
.\Remove-ProjectJunk.ps1 -DryRun

# Clean everything with interactive prompts
.\Remove-ProjectJunk.ps1

# Skip all prompts (dangerous!)
.\Remove-ProjectJunk.ps1 -Force
```

### 🎯 What It Destroys

- **Windows System Files**: `Thumbs.db`, `Desktop.ini`, `*.lnk`, `Zone.Identifier` files
- **macOS Files**: `.DS_Store`, `._*`, `.Spotlight-V100` (from Mac developers)
- **Linux Files**: `*~`, `.nfs*` (from WSL/Git repositories)
- **Build Artifacts**: `node_modules`, `__pycache__`, `target`, `dist`, `build`
- **Cache Directories**: `.cache`, `tmp`, `.sass-cache`, `.parcel-cache`
- **Log Files**: `*.log`, `npm-debug.log*`, `yarn-debug.log*`
- **Backup Files**: `*.bak`, `*.swp`, `*.tmp`, `*.old`
- **Compiled Files**: `*.pyc`, `*.class`, `*.o`, `*.obj`
- **Archive Files**: `*.zip`, `*.rar`, `*.7z` (with confirmation)
- **Empty Directories**: Recursively removes empty folders

### 🛡️ Safety Features

- **Interactive prompts** with 5-second timeouts for each category
- **Full path display** before deletion with file sizes
- **Git integration** removes tracked junk files from version control
- **Comprehensive logging** with timestamps and error tracking
- **File size limits** to prevent deletion of unexpectedly large files

### 🔧 Advanced Usage

```powershell
# Clean only system trash files
.\Remove-ProjectJunk.ps1 -OnlySystemFiles

# Clean only build artifacts and cache
.\Remove-ProjectJunk.ps1 -OnlyBuildFiles

# Skip archive files (keep .zip, .rar, etc.)
.\Remove-ProjectJunk.ps1 -SkipArchives

# Don't remove from Git tracking
.\Remove-ProjectJunk.ps1 -SkipGit

# Save detailed log
.\Remove-ProjectJunk.ps1 -LogFile "cleanup.log" -Verbose

# Clean specific directory
.\Remove-ProjectJunk.ps1 -Path "C:\MyProject" -DryRun

# Don't delete files larger than 100MB
.\Remove-ProjectJunk.ps1 -MaxFileSizeMB 100
```

### 🆘 Help

```powershell
.\Remove-ProjectJunk.ps1 -Help
```

### ⚠️ Execution Policy Issues

If you get execution policy errors:

```powershell
# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Unblock the script file
Unblock-File .\Remove-ProjectJunk.ps1

# Or run with bypass (one-time)
powershell.exe -ExecutionPolicy Bypass -File ".\Remove-ProjectJunk.ps1" -DryRun
```

---

## 🚨 Final Warning

Both scripts are **extremely powerful** and can cause **irreversible data loss**. They are designed to be destructive. 

**ALWAYS:**
- Run with preview mode first (`--dry-run` or `-DryRun`)
- Have backups of important data
- Understand what each script does before running
- Test on non-critical projects first

**You have been warned. Use at your own risk.**