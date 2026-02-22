#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — ZFS Snapshots${RESET}"; echo ""

# Setup
cleanup_zfs
ssh_zfs "sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde && sudo zfs create tank/data" >/dev/null 2>&1

# 5.1 Write initial data
ssh_zfs "echo 'version 1' | sudo tee /tank/data/file.txt" >/dev/null 2>&1

# 5.2 Create snapshot
ssh_zfs "sudo zfs snapshot tank/data@v1" >/dev/null 2>&1
snapshots=$(ssh_zfs "sudo zfs list -t snapshot 2>/dev/null")
assert_contains "Snapshot v1 created" "$snapshots" "tank/data@v1"

# 5.3 Modify data
ssh_zfs "echo 'version 2' | sudo tee /tank/data/file.txt" >/dev/null 2>&1
content_modified=$(ssh_zfs "cat /tank/data/file.txt 2>/dev/null")
assert_contains "Data modified to v2" "$content_modified" "version 2"

# 5.4 Rollback to snapshot
ssh_zfs "sudo zfs rollback tank/data@v1" >/dev/null 2>&1
content_rolled=$(ssh_zfs "cat /tank/data/file.txt 2>/dev/null")
assert_contains "Rollback restored v1" "$content_rolled" "version 1"

# 5.5 Destroy snapshot
ssh_zfs "sudo zfs destroy tank/data@v1" >/dev/null 2>&1
snaps_after=$(ssh_zfs "sudo zfs list -t snapshot 2>/dev/null" || echo "no snapshots")
assert_not_contains "Snapshot destroyed" "$snaps_after" "tank/data@v1"

# Cleanup
cleanup_zfs

report_results "Exercise 5"
