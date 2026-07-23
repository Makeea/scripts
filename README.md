# 🛠️ Makeea's Script Collection

Welcome to the official script collection by [Makeea](https://github.com/Makeea).  
This repo is a personal toolbox of scripts designed to make everyday technical tasks easier for anyone from beginners to pros.

---

## 📂 What's Inside?

- `linux/` – Shell scripts for Linux systems, including Docker, Git, Proxmox, backups, and desktop setups.
- `batch/` – Windows `.bat` scripts for silent installs, file handling, and printer queue fixes.
- `junk-cleanup/` – Recursively sends OS junk files (macOS/Windows/Linux) to the Recycle Bin/trash; PowerShell, Bash, and self-contained `.cmd` versions.
- `pihole.md` – Setup notes and tweaks for Pi-hole network ad blocking.

---

## 🚀 Quick Start

### 🧼 Update Your Linux Server

This script updates and upgrades your Linux system with just one command.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/master/linux/server-update.sh

▶️ **Run it:**

```bash
curl -L https://raw.githubusercontent.com/Makeea/scripts/master/linux/server-update.sh | bash
```

**What it does:**

- Runs `apt update` and `apt upgrade`
- Automatically accepts prompts
- Cleans up unused packages

---

### 🌍 Update Linux Across Multiple Distros

This universal update script detects your Linux distribution and uses the native package manager automatically.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/master/linux/linux-update-universal.sh

▶️ **Run it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/master/linux/linux-update-universal.sh | bash
```

**What it does:**

- Detects the distro from `/etc/os-release`
- Detects Proxmox VE hosts and handles them safely
- Supports `apt`, `dnf`, `yum`, `pacman`, and `zypper`
- Runs updates and cleanup commands for the detected package manager
- Writes logs to `/var/log/linux-update-universal.log`
- Prevents overlapping runs with a lock file
- Reboots automatically after a successful update on non-Proxmox systems

**Good to know:**

- Run it with `bash`; the script will use `sudo` itself when needed and available
- It does not perform major OS version upgrades
- On Proxmox, it does not reboot automatically and will tell you if a reboot is recommended
- Best for routine package updates on Debian, Ubuntu, Fedora, Rocky, AlmaLinux, Arch, Manjaro, openSUSE, and similar systems

---

### 🟦 Update a Pi-hole Server

This updater refreshes Debian or Ubuntu packages on a Pi-hole host and then runs the Pi-hole updater.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/master/linux/pihole-update.sh

▶️ **Run it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/master/linux/pihole-update.sh | bash
```

**What it does:**

- Uses `apt` to update and upgrade system packages
- Runs `pihole -up` to update Pi-hole itself
- Writes logs to `/var/log/pihole-update.log`
- Prevents overlapping runs with a lock file
- Tells you if a reboot is recommended

**Good to know:**

- Run it with `bash`; the script will use `sudo` itself when needed and available
- It is intended for Debian, Ubuntu, Raspberry Pi OS, and similar Pi-hole hosts
- It does not reboot automatically

---

### 🔐 Import GitHub SSH Key to Your Server

This command lets you import your GitHub SSH key directly to a server so you can log in without typing your password.

▶️ **Steps:**

1. Make sure the tool is installed:

```bash
sudo apt install ssh-import-id
```

2. Replace `<username>` with your GitHub account name:

```bash
ssh-import-id-gh <username>
```

**What it does:**

- Downloads your public SSH key from GitHub
- Adds it to `~/.ssh/authorized_keys`
- Great for fast and secure remote access

---

### 🔋 Check Windows Battery Health

This script checks a Windows laptop's battery condition and saves a battery health report.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/powershell/Get-BatteryReport.ps1

▶️ **Run it:**

```powershell
irm https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/powershell/Get-BatteryReport.ps1 | iex
```

**What it does:**

- Detects whether the system has a battery and skips gracefully on desktops
- Calculates battery health % (full charge capacity vs. design capacity) with a plain-language condition rating (Good / Fair / Poor / Very Poor)
- Saves the native Windows `powercfg` battery report to `C:\reports\battery-report-<timestamp>.html`
- Appends each run's health summary to `C:\reports\battery-health-history.csv` so degradation can be tracked over time

**Good to know:**

- Health rating uses a commonly cited industry rule of thumb: capacity retention below ~80% is when noticeable battery degradation typically starts
- No administrator rights required

---

### 🔋 Check Linux Battery Health

This script checks a Linux laptop's battery condition and saves a battery health report.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/linux/battery-report.sh

▶️ **Run it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/linux/battery-report.sh | bash
```

**What it does:**

- Reads battery capacity data from `/sys/class/power_supply` and skips gracefully on battery-less systems (desktops/servers)
- Calculates battery health % (full charge capacity vs. design capacity) with a plain-language condition rating (Good / Fair / Poor / Very Poor)
- Saves a battery report to `/var/reports/battery-report-<timestamp>.txt`
- Appends each run's health summary to `/var/reports/battery-health-history.csv` so degradation can be tracked over time

**Good to know:**

- Health rating uses the same rule of thumb as the Windows version: capacity retention below ~80% is when noticeable battery degradation typically starts
- If `/var/reports` doesn't already exist and can't be created without elevated permissions, run with `sudo`

---

### 🔋 Check macOS Battery Health

This script checks a MacBook's battery condition and saves a battery health report.

📄 **Script link:**  
https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/macos/battery-report.sh

▶️ **Run it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/refs/heads/master/macos/battery-report.sh | bash
```

**What it does:**

- Reads battery health data from `system_profiler` (Apple's own Cycle Count, Condition, and Maximum Capacity) and skips gracefully on desktop Macs
- Applies the same Good / Fair / Poor / Very Poor rating as the Windows and Linux versions, shown alongside Apple's own Condition label
- Saves the full battery report to `/var/reports/battery-report-<timestamp>.txt`
- Appends each run's health summary to `/var/reports/battery-health-history.csv` so degradation can be tracked over time

**Good to know:**

- If `/var/reports` doesn't already exist and can't be created without elevated permissions, run with `sudo`

---

## 🧰 Featured Scripts

| Script | Description |
|--------|-------------|
| `linux/docker.sh` | Install Docker and Docker Compose on Ubuntu |
| `linux/proxmox-create-ubuntu-cloudinit-template.sh` | Create a cloud-init template for Proxmox |
| `linux/git-Ed25519-setup.sh` | Secure SSH key generator for GitHub access |
| `linux/linux-update-universal.sh` | Cross-distro Linux updater with logging, cleanup, and Proxmox-safe reboot handling |
| `linux/pihole-update.sh` | Update system packages on a Pi-hole host and run the Pi-hole updater |
| `batch/Clear Print Queue.bat` | Clears printer queue on Windows systems |
| `linux/rsync_backup.sh` | Automates backup using rsync |
| `powershell/Get-BatteryReport.ps1` | Checks Windows battery health/condition and saves a report to `C:\reports` |
| `linux/battery-report.sh` | Checks Linux battery health/condition and saves a report to `/var/reports` |
| `macos/battery-report.sh` | Checks macOS battery health/condition and saves a report to `/var/reports` |

---

## ✅ Requirements

**Linux scripts:**

- Ubuntu 20.04 or newer (Debian-based distros)
- `bash`, `curl`, `sudo` privileges

**Windows scripts:**

- Windows 10 or 11
- Administrator rights for certain tasks

---

## 🤝 Contributing

Want to improve a script or add your own?  
Fork the repo, make your changes, and submit a pull request!

---

## 📄 License

All scripts in this repository are available under the [MIT License](LICENSE).

---

Made with ❤️ by [Makeea](https://github.com/Makeea)
