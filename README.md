# 🛠️ Makeea's Script Collection

Welcome to the official script collection by [Makeea](https://github.com/Makeea).  
This repo is a personal toolbox of scripts designed to make everyday technical tasks easier for anyone from beginners to pros.

---

## 📂 What's Inside?

- `linux/` – Shell scripts for Linux systems, including Docker, Git, Proxmox, backups, and desktop setups.
- `batch/` – Windows `.bat` scripts for silent installs, file handling, and printer queue fixes.
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

## 🧰 Featured Scripts

| Script | Description |
|--------|-------------|
| `linux/docker.sh` | Install Docker and Docker Compose on Ubuntu |
| `linux/proxmox-create-ubuntu-cloudinit-template.sh` | Create a cloud-init template for Proxmox |
| `linux/git-Ed25519-setup.sh` | Secure SSH key generator for GitHub access |
| `linux/linux-update-universal.sh` | Cross-distro Linux updater with logging, cleanup, and Proxmox-safe reboot handling |
| `batch/Clear Print Queue.bat` | Clears printer queue on Windows systems |
| `linux/rsync_backup.sh` | Automates backup using rsync |

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
