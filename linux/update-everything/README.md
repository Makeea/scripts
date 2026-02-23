# Update Everything Scripts

Universal Linux update helpers with Proxmox support.

## Scripts

- `update-everything.sh`: Simple, single-node updater with distro auto-detect.
- `update-everything-sre.sh`: Safer SRE-style updater with flags and optional reboot control.
- `pve-rolling-update.sh`: Proxmox rolling update helper for clustered nodes.

## Features

- Auto detects distro (apt, dnf, yum, pacman, zypper, proxmox)
- Updates system packages and cleans unused packages
- Logs to `/var/log/update-everything.log` or `/var/log/pve-rolling-update.log`
- Reboots when required (configurable in SRE script)

## Run

Simple updater:

```bash
sudo ./update-everything.sh
```

SRE updater with flags:

```bash
sudo ./update-everything-sre.sh --dry-run
sudo ./update-everything-sre.sh --no-reboot
sudo ./update-everything-sre.sh --force-reboot
```

Proxmox rolling update (clustered nodes):

```bash
sudo ./pve-rolling-update.sh
```

## Quick Run (curl)

Preferred (download, then run):

```bash
curl -fsSL -o /tmp/update-everything.sh https://raw.githubusercontent.com/Makeea/scripts/master/linux/update-everything/update-everything.sh
chmod +x /tmp/update-everything.sh
sudo /tmp/update-everything.sh
```

SRE version:

```bash
curl -fsSL -o /tmp/update-everything-sre.sh https://raw.githubusercontent.com/Makeea/scripts/master/linux/update-everything/update-everything-sre.sh
chmod +x /tmp/update-everything-sre.sh
sudo /tmp/update-everything-sre.sh --dry-run
```

Curl + bash (less safe):

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/master/linux/update-everything/update-everything.sh | bash
```

## Notes

- Proxmox rolling updates check quorum, drain VMs/CTs, and use HA maintenance mode when available.
- The SRE script supports `--quiet` and `--help` for minimal output and usage info.
