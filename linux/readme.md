# 🐧 Linux Scripts

This folder contains shell scripts for managing and configuring Linux systems.  
Most are built for Ubuntu or Debian-based distros and are meant to be simple, beginner-friendly tools for common tasks.

---

## 🚀 How to Use

### Method 1 – Make a script executable and run it:

```bash
chmod +x scriptname.sh
./scriptname.sh
```

### Method 2 – Run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/master/linux/scriptname.sh | sudo bash
```

---

## 📂 Scripts and What They Do

- `chrome.sh` – Installs the Google Chrome web browser.
- `docker.sh` – Installs Docker Engine and Docker Compose.
- `docker_compose_v1.29.2.sh` – Installs Docker Compose version 1.29.2.
- `docker_compose_v2.28.1.sh` – Installs Docker Compose version 2.28.1.
- `docker_portainer.sh` – Installs Portainer, a web UI for managing Docker containers.
- `firefox.sh` – Installs the Mozilla Firefox browser.
- `free_space.sh` – Displays available disk space using `df`.
- `git-4096-setup.sh` – Creates a 4096-bit RSA SSH key for GitHub use.
- `git-Ed25519-improved.sh` – Creates an Ed25519 SSH key with better security and helpful config.
- `git-Ed25519-setup.sh` – Generates a standard Ed25519 SSH key for GitHub.
- `jekll-old.sh` – Installs an older version of Jekyll for legacy compatibility.
- `jekll-ruby.sh` – Installs Ruby dependencies required for running Jekyll.
- `jekll.sh` – Installs the latest Jekyll site generator.
- `nodejs.sh` – Installs Node.js from the official source.
- `pia_connect.sh` – Connects to Private Internet Access (PIA) VPN using OpenVPN.
- `portainer-updater.sh` – Updates an existing Portainer Docker container.
- `portainer.sh` – Installs and runs Portainer as a Docker container.
- `proxmox-create-ubuntu-cloudinit-template.sh` – Prepares a cloud-init image for Proxmox virtual machines.
- `proxmox-qemu-guest-agent-old.sh` – Installs an older version of the QEMU guest agent.
- `proxmox-qemu-guest-agent.sh` – Installs the QEMU guest agent to allow Proxmox to manage the VM.
- `qemu-guest-agent-easy.sh` – Quick installer for the QEMU guest agent.
- `qemu-guest-agent.sh` – Another script to install QEMU guest agent, with logging.
- `remove_vnc.sh` – Uninstalls any VNC server installed on the system.
- `remove_xrdp.sh` – Uninstalls the xRDP remote desktop server.
- `rsync_backup.sh` – Creates a basic `rsync` backup of your data.
- `rsync_backup_improved.sh` – Enhanced version of the `rsync` backup with exclusions and logging.
- `server-jekll-wsl2.sh` – Sets up a Jekyll server for WSL2 environments.
- `server-pihole.sh` – Installs and configures Pi-hole on a Linux server.
- `server-post-install.sh` – Basic post-install setup for newly built servers.
- `server-staging.sh` – Prepares a Linux server for use as a staging environment.
- `server-update.sh` – Runs system updates and cleanup tasks.
- `linux-update-universal.sh` – Detects the Linux distro, installs package updates with the native package manager, performs cleanup, and reboots automatically after a successful run.
- `setup_vnc.sh` – Installs and configures a VNC remote desktop server.
- `setup_xrdp.sh` – Installs xRDP and configures desktop access via RDP.
- `system_update.sh` – Performs `apt update` and `apt upgrade` with no prompts.
- `ubuntu-desktop-GNOME-remove.sh` – Removes GNOME desktop and its packages.
- `ubuntu-desktop-GNOME.sh` – Installs the full GNOME desktop environment.
- `ubuntu-desktop-installer.sh` – Guided script to install Ubuntu desktop features.
- `unifi-6.5.55.sh` – Installs the UniFi Controller software, version 6.5.55.
- `unifi-update.sh` – Updates the UniFi Controller to the latest supported version.
- `unity-control-center-fix.sh` – Fixes issues with Unity Control Center not launching.
- `useful-desktop-tools.sh` – Installs common GUI tools like GParted and Synaptic.

---

All scripts are written to be easy to use and modify.  
Feel free to read through each one before running it.
