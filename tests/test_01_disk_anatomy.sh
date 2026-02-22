#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — Disk Anatomy${RESET}"; echo ""

# 1.1 LVM VM has extra disks
lvm_disks=$(ssh_lvm "lsblk -d -n -o NAME,SIZE 2>/dev/null")
assert_contains "LVM VM has /dev/vdb" "$lvm_disks" "vdb"
assert_contains "LVM VM has /dev/vdc" "$lvm_disks" "vdc"
assert_contains "LVM VM has /dev/vdd" "$lvm_disks" "vdd"
assert_contains "LVM VM has /dev/vde" "$lvm_disks" "vde"

# 1.2 ZFS VM has extra disks
zfs_disks=$(ssh_zfs "lsblk -d -n -o NAME,SIZE 2>/dev/null")
assert_contains "ZFS VM has /dev/vdb" "$zfs_disks" "vdb"
assert_contains "ZFS VM has /dev/vdc" "$zfs_disks" "vdc"
assert_contains "ZFS VM has /dev/vdd" "$zfs_disks" "vdd"
assert_contains "ZFS VM has /dev/vde" "$zfs_disks" "vde"

# 1.3 LVM tools installed
assert "pvcreate available" ssh_lvm "which pvcreate"
assert "vgcreate available" ssh_lvm "which vgcreate"
assert "lvcreate available" ssh_lvm "which lvcreate"

# 1.4 ZFS tools installed
assert "zpool available" ssh_zfs "which zpool"
assert "zfs available" ssh_zfs "which zfs"

report_results "Exercise 1"
