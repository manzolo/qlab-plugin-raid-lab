#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — ZFS Basics${RESET}"; echo ""

# Cleanup
cleanup_zfs

# 4.1 Create a zpool (raidz)
ssh_zfs "sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde" >/dev/null 2>&1
pool_status=$(ssh_zfs "sudo zpool status tank 2>/dev/null")
assert_contains "zpool tank created" "$pool_status" "tank"
assert_contains "Pool is ONLINE" "$pool_status" "ONLINE"

# 4.2 Create a dataset
ssh_zfs "sudo zfs create tank/data" >/dev/null 2>&1
zfs_list=$(ssh_zfs "sudo zfs list 2>/dev/null")
assert_contains "Dataset tank/data created" "$zfs_list" "tank/data"

# 4.3 Set compression
ssh_zfs "sudo zfs set compression=lz4 tank/data" >/dev/null 2>&1
compression=$(ssh_zfs "sudo zfs get compression tank/data -H -o value 2>/dev/null")
assert_contains "Compression set to lz4" "$compression" "lz4"

# 4.4 Write data
ssh_zfs "echo 'hello ZFS' | sudo tee /tank/data/file.txt" >/dev/null 2>&1
content=$(ssh_zfs "cat /tank/data/file.txt 2>/dev/null")
assert_contains "Data written to ZFS" "$content" "hello ZFS"

# Cleanup
cleanup_zfs

report_results "Exercise 4"
