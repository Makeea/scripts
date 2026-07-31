#!/usr/bin/env bash

set -Eeuo pipefail

LOCKFILE="/var/lock/pve-update.lock"
LOGFILE="/var/log/pve-rolling-update.log"
HOST=$(hostname)

exec 9>"$LOCKFILE"
flock -n 9 || { echo "Another update is running"; exit 1; }

log() {
  echo "$(date '+%F %T') $*" | tee -a "$LOGFILE"
}

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
}

check_quorum() {
  log "Checking cluster quorum"
  pvecm status | grep -q "Quorate: Yes" || {
    log "Cluster not quorate — aborting"
    exit 2
  }
}

check_ceph() {
  if command -v ceph >/dev/null 2>&1; then
    log "Checking Ceph health"
    ceph health | grep -q HEALTH_OK || {
      log "Ceph not healthy — aborting"
      exit 3
    }
  fi
}

drain_node() {
  log "Migrating VMs and containers off $HOST"

  for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    log "Migrating VM $vmid"
    qm migrate "$vmid" --online
  done

  for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    log "Migrating CT $ctid"
    pct migrate "$ctid"
  done
}

enter_maintenance() {
  if command -v ha-manager >/dev/null 2>&1; then
    log "Setting HA maintenance mode"
    ha-manager node-maintenance enable "$HOST" || true
  fi
}

exit_maintenance() {
  if command -v ha-manager >/dev/null 2>&1; then
    log "Disabling HA maintenance mode"
    ha-manager node-maintenance disable "$HOST" || true
  fi
}

update_node() {
  log "Running system update"
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt full-upgrade -y
  apt autoremove -y --purge
  apt autoclean
  apt clean
}

reboot_node() {
  log "Rebooting node"
  reboot
}

post_checks() {
  log "Running post-upgrade checks"
  pvecm status | grep -q "Quorate: Yes" || {
    log "Quorum lost after reboot"
    exit 4
  }
}

main() {
  require_root
  log "=== Starting rolling update on $HOST ==="

  check_quorum
  check_ceph
  enter_maintenance
  drain_node
  update_node

  if [[ -f /var/run/reboot-required ]]; then
    reboot_node
  fi

  exit_maintenance
  post_checks

  log "=== Update complete on $HOST ==="
}

main
