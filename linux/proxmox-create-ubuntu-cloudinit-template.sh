#!/bin/bash

echo ""
echo "=============================================="
echo "  Proxmox Cloud-Init Template Setup Script"
echo "=============================================="
echo ""
echo "This script will:"
echo "- Download an official Ubuntu cloud image"
echo "- Create a VM with Cloud-Init (ID 9000 or 9001 by default)"
echo "- Resize the disk to 32GB"
echo "- Ask to convert the VM into a reusable template"
echo ""
echo "You can later clone the template like this:"
echo "  qm clone <VMID> 101 --name my-ubuntu-vm"
echo "  qm set 101 --ipconfig0 ip=dhcp"
echo "  qm start 101"
echo ""
echo "----------------------------------------------"
echo "Which Ubuntu version do you want to use?"
echo "1) Ubuntu 22.04 (Jammy) → default VMID 9000"
echo "2) Ubuntu 24.04 (Noble) → default VMID 9001"
read -p "Enter 1 or 2: " VERSION_CHOICE

if [ "$VERSION_CHOICE" == "1" ]; then
  OS_VERSION="jammy"
  FRIENDLY_VERSION="22.04"
  SUGGESTED_VMID=9000
elif [ "$VERSION_CHOICE" == "2" ]; then
  OS_VERSION="noble"
  FRIENDLY_VERSION="24.04"
  SUGGESTED_VMID=9001
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Prompt until a free VMID is selected
while true; do
  VMID=$SUGGESTED_VMID

  if qm status "$VMID" &>/dev/null; then
    echo ""
    echo "❌ VMID $VMID is already in use!"
    echo "To check what it is, run:"
    echo "  qm list | grep $VMID"
    read -p "Enter a different VMID to use instead: " SUGGESTED_VMID
  else
    break
  fi
done

VMNAME="ubuntu-${FRIENDLY_VERSION}-template-${VMID}"
STORAGE="local-lvm"
BRIDGE="vmbr0"
IMAGE="${OS_VERSION}-server-cloudimg-amd64.img"
URL="https://cloud-images.ubuntu.com/${OS_VERSION}/current/${IMAGE}"

cd /root || exit 1

echo ""
echo "Selected Ubuntu $FRIENDLY_VERSION → VMID $VMID"
echo "----------------------------------------------"
echo "Downloading the Ubuntu cloud image..."
if [ ! -f "$IMAGE" ]; then
  wget "$URL"
else
  echo "Image already exists. Skipping download."
fi

echo "Creating VM $VMID..."
qm create $VMID --name $VMNAME --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE
qm importdisk $VMID $IMAGE $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VMID}-disk-0
qm set $VMID --ide2 ${STORAGE}:cloudinit
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0
qm resize $VMID scsi0 32G

echo ""
read -p "Are you ready to convert VM $VMID to a template? (y/n): " CONFIRM
if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
  qm template $VMID
  echo "✅ Template created: $VMNAME (Ubuntu $FRIENDLY_VERSION)"
else
  echo ""
  echo "⏭️ Skipped converting VM $VMID."
  echo "To convert it later, run:"
  echo "  qm template $VMID"
fi
