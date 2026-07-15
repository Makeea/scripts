# 🧹 OS Junk Cleanup

Recursively finds and removes OS-generated junk files and folders — the
clutter that macOS, Windows, and Linux leave behind in shared folders and
extracted archives. Unlike the tools in `linux-dangerous-scripts/`, these
scripts **only** touch OS junk: no `node_modules`, no build artifacts, no
caches, no git integration, and archive/compressed files (`.zip`, `.rar`,
`.7z`, etc.) are never touched.

By default, items are sent to the **Recycle Bin / trash**, not permanently
deleted — pass `-Permanent` / `--permanent` if you want them gone for good.

## What gets cleaned

- **macOS**: `__MACOSX`, `.DS_Store`, `._*`, `.Spotlight-V100`, `.Trashes`,
  `.fseventsd`, `.AppleDouble`, `.apdisk`, `.localized`
- **Windows**: `Thumbs.db`, `ehthumbs.db`, `ehthumbs_vista.db`, `desktop.ini`,
  `*.lnk`, `*Zone.Identifier*`, `$RECYCLE.BIN`, `System Volume Information`
- **Linux**: `*~`, `.nfs*`, `.Trash-*`, `.directory`

## Scripts

- `Remove-OSJunk.ps1` — Windows PowerShell version.
- `remove-os-junk.sh` — Bash version for Linux/macOS/WSL.
- `Remove-OSJunk.cmd` — self-contained, double-click version for Windows. It's
  a single file (no separate `.ps1` needed) — copy just this one file into a
  folder and double-click it to clean that folder.

## Usage

### PowerShell

```powershell
# Preview only, nothing touched
.\Remove-OSJunk.ps1 -DryRun

# Clean current folder - sends junk to the Recycle Bin
.\Remove-OSJunk.ps1

# Clean a specific folder
.\Remove-OSJunk.ps1 -Path "C:\Some\Folder"

# Skip the Recycle Bin and delete permanently
.\Remove-OSJunk.ps1 -Permanent
```

### Bash

```bash
chmod +x remove-os-junk.sh

# Preview only, nothing touched
./remove-os-junk.sh --dry-run

# Clean current folder - sends junk to trash (gio/trash-cli/macOS Finder trash)
./remove-os-junk.sh

# Clean a specific folder
./remove-os-junk.sh --path /some/folder

# Skip trash and delete permanently
./remove-os-junk.sh --permanent
```

On a minimal Linux server with no trash utility installed, the script warns
and falls back to permanent delete. Install `trash-cli` for proper
recycle-bin behavior:

```bash
sudo apt install trash-cli
```

### Windows (.cmd, self-contained)

Copy just `Remove-OSJunk.cmd` into the folder you want to clean, then
double-click it — no other files required. Extra flags still work from a
terminal, e.g.:

```
Remove-OSJunk.cmd -DryRun
Remove-OSJunk.cmd -Permanent
```
