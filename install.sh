#!/usr/bin/env bash
# raid-lab install script

set -euo pipefail

echo ""
echo "  [raid-lab] Installing..."
echo ""
echo "  This plugin creates two VMs for practicing disk management:"
echo ""
echo "    1. raid-lab-lvm  — LVM (Logical Volume Manager)"
echo "       Learn pvcreate, vgcreate, lvcreate, lvextend"
echo ""
echo "    2. raid-lab-zfs  — ZFS (Zettabyte File System)"
echo "       Learn zpool create, zfs snapshot, zfs send/receive"
echo ""
echo "  Each VM is provisioned with 4 extra virtual disks (1G each)"
echo "  that you can use to create volume groups, pools, and arrays."
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [raid-lab] Installation complete."
echo "  Run with: qlab run raid-lab"
