#!/bin/bash

# ================================================
# Proxmox Ubuntu Cloud-Init Template Script (Beginner-Friendly)
# ================================================

echo ""
echo "=============================================="
echo "  Proxmox Ubuntu Template Script"
echo "=============================================="
echo ""
echo "This script will:"
echo "- Download an Ubuntu cloud image"
echo "- Create a VM (Ubuntu 22.04 or 24.04)"
echo "- Let you pick VM ID, RAM, and disk size"
echo "- Optionally convert it into a template"
echo ""

echo "Later, you can clone your template like this:"
echo "  qm clone <VMID> 101 --name my-ubuntu-vm"
echo "  qm set 101 --ipconfig0 ip=dhcp"
echo "  qm start 101"
echo ""

# Ask the user which Ubuntu version to use
echo "Pick Ubuntu version:"
echo "1 = Ubuntu 22.04"
echo "2 = Ubuntu 24.04"
read -p "Enter 1 or 2: " version

# Set variables based on choice
if [ "$version" == "1" ]; then
  osver="jammy"
  vmver="22.04"
  vmid="9000"
elif [ "$version" == "2" ]; then
  osver="noble"
  vmver="24.04"
  vmid="9001"
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Loop until the user provides an unused VM ID
while true; do
  if qm status $vmid &>/dev/null; then
    echo ""
    echo "❌ VM ID $vmid is already used."
    echo "To check what it is, run:"
    echo "  qm list | grep $vmid"
    read -p "Enter a different VM ID to use instead: " vmid
  else
    break
  fi
done

# Ask the user how much RAM to assign
read -p "How much RAM (in MB) should the VM have? (default is 2048): " ram
if [ -z "$ram" ]; then
  ram="2048"
fi

# Ask the user how big the disk should be
read -p "How big should the disk be (in GB)? (default is 32): " disksize
if [ -z "$disksize" ]; then
  disksize="32"
fi

# Set other required values
name="ubuntu-${vmver}-template-${vmid}"
bridge="vmbr0"
storage="local-lvm"
image="${osver}-server-cloudimg-amd64.img"
url="https://cloud-images.ubuntu.com/${osver}/current/${image}"

# Move to /root (working directory)
cd /root || exit 1

# Download the cloud image if it's not already there
echo ""
echo "Getting Ubuntu $vmver image..."
if [ ! -f "$image" ]; then
  wget "$url"
else
  echo "Already have it!"
fi

# Create the VM and attach the disk
echo "Creating VM $vmid..."
qm create $vmid --name $name --memory $ram --cores 2 --net0 virtio,bridge=$bridge
qm importdisk $vmid $image $storage
qm set $vmid --scsihw virtio-scsi-pci --scsi0 ${storage}:vm-${vmid}-disk-0
qm set $vmid --ide2 ${storage}:cloudinit
qm set $vmid --boot c --bootdisk scsi0
qm set $vmid --serial0 socket --vga serial0

# Resize the disk to the user-specified size
echo "Resizing disk to ${disksize}G..."
qm resize $vmid scsi0 "${disksize}G"

# Ask the user if they want to turn this VM into a template
echo ""
read -p "Do you want to turn VM $vmid into a template now? (y/n): " make_template

if [[ "$make_template" == "y" || "$make_template" == "Y" ]]; then
  qm template $vmid

  echo ""
  echo "✅ Your VM $vmid was successfully converted to a template!"
  echo ""
  echo "📦 Proxmox renamed the disk from:"
  echo "    vm-${vmid}-disk-0 → base-${vmid}-disk-0"
  echo "This is expected — templates use a 'base-' prefix so they can be cloned efficiently."
  echo ""
  echo "⚠️ You might also see this message:"
  echo "    WARNING: Combining activation change with other commands is not advised."
  echo "Don't worry — this is normal and nothing is broken."
else
  echo ""
  echo "⏭️ Skipped converting VM $vmid."
  echo "To convert it later, run this command:"
  echo "  qm template $vmid"
fi
