#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — LVM Basics${RESET}"; echo ""

# Cleanup any previous state
cleanup_lvm

# 2.1 Create physical volumes
ssh_lvm "sudo pvcreate -f /dev/vdb /dev/vdc" >/dev/null 2>&1
pvs=$(ssh_lvm "sudo pvs --noheadings 2>/dev/null")
assert_contains "PV /dev/vdb created" "$pvs" "vdb"
assert_contains "PV /dev/vdc created" "$pvs" "vdc"

# 2.2 Create volume group
ssh_lvm "sudo vgcreate labvg /dev/vdb /dev/vdc" >/dev/null 2>&1
vgs=$(ssh_lvm "sudo vgs --noheadings 2>/dev/null")
assert_contains "VG labvg created" "$vgs" "labvg"

# 2.3 Create logical volume
ssh_lvm "sudo lvcreate --yes -L 800M -n data labvg" >/dev/null 2>&1
lvs=$(ssh_lvm "sudo lvs --noheadings 2>/dev/null")
assert_contains "LV data created" "$lvs" "data"

# 2.4 Format and mount
ssh_lvm "sudo mkfs.ext4 -q /dev/labvg/data && sudo mount /dev/labvg/data /mnt" >/dev/null 2>&1
df_out=$(ssh_lvm "df -h /mnt 2>/dev/null")
assert_contains "LV mounted at /mnt" "$df_out" "/dev/mapper/labvg-data|/mnt"

# 2.5 Write data
ssh_lvm "echo 'LVM test' | sudo tee /mnt/test.txt" >/dev/null 2>&1
content=$(ssh_lvm "cat /mnt/test.txt 2>/dev/null")
assert_contains "Data written to LV" "$content" "LVM test"

# Cleanup
cleanup_lvm

report_results "Exercise 2"
