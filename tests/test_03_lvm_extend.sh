#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — LVM Extend${RESET}"; echo ""

# Setup
cleanup_lvm
ssh_lvm "sudo pvcreate -f /dev/vdb /dev/vdc && sudo vgcreate labvg /dev/vdb /dev/vdc && sudo lvcreate --yes -L 800M -n data labvg && sudo mkfs.ext4 -q /dev/labvg/data && sudo mount /dev/labvg/data /mnt" >/dev/null 2>&1

# 3.1 Add new PV
ssh_lvm "sudo pvcreate -f /dev/vdd" >/dev/null 2>&1
assert "PV /dev/vdd created" ssh_lvm "sudo pvs /dev/vdd"

# 3.2 Extend VG
ssh_lvm "sudo vgextend labvg /dev/vdd" >/dev/null 2>&1
vg_info=$(ssh_lvm "sudo vgs labvg --noheadings -o pv_count 2>/dev/null")
assert_contains "VG extended to 3 PVs" "$vg_info" "3"

# 3.3 Extend LV
ssh_lvm "sudo lvextend -L +500M /dev/labvg/data" >/dev/null 2>&1
lv_size=$(ssh_lvm "sudo lvs labvg/data --noheadings -o lv_size --units m 2>/dev/null")
assert_contains "LV extended" "$lv_size" "1[23]"

# 3.4 Resize filesystem
ssh_lvm "sudo resize2fs /dev/labvg/data" >/dev/null 2>&1
df_after=$(ssh_lvm "df -h /mnt 2>/dev/null")
assert_contains "Filesystem resized" "$df_after" "1\.[0-9]G|/mnt"

# Cleanup
cleanup_lvm

report_results "Exercise 3"
