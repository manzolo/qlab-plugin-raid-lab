# raid-lab — LVM & ZFS Disk Management Lab

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for practicing disk management:

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `raid-lab-lvm` | 2224 | `lvm2` | Physical Volumes, Volume Groups, Logical Volumes |
| `raid-lab-zfs` | 2225 | `zfsutils-linux` | ZFS pools, datasets, snapshots |

Each VM is provisioned with **4 extra virtual disks** (1 GB each) that appear as `/dev/vdb`, `/dev/vdc`, `/dev/vdd`, `/dev/vde`.

## Quick Start

```bash
qlab init
qlab install raid-lab
qlab run raid-lab
# Wait ~60s for boot + package installation
qlab shell raid-lab-lvm    # connect to LVM VM
qlab shell raid-lab-zfs    # connect to ZFS VM
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

---

## LVM Guided Tutorial

### 1. Explore available disks

```bash
lsblk
# You should see vdb, vdc, vdd, vde (1G each) with no partitions
```

### 2. Create Physical Volumes (PV)

```bash
sudo pvcreate /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo pvs                    # list PVs
sudo pvdisplay /dev/vdb     # detailed info on a single PV
```

### 3. Create a Volume Group (VG)

```bash
sudo vgcreate labvg /dev/vdb /dev/vdc
sudo vgs                    # summary
sudo vgdisplay labvg        # detailed info (note Free PE)
```

### 4. Create a Logical Volume, format, and mount

```bash
sudo lvcreate -L 800M -n data labvg
sudo lvs                    # verify
sudo mkfs.ext4 /dev/labvg/data
sudo mkdir -p /mnt/data
sudo mount /dev/labvg/data /mnt/data
df -h /mnt/data             # ~800M available
echo "LVM works!" | sudo tee /mnt/data/hello.txt
```

### 5. Extend the VG and grow the LV online

```bash
# Add a new disk to the volume group
sudo vgextend labvg /dev/vdd
sudo vgs                    # Free space increased

# Grow the logical volume by 500M and resize the filesystem in one step
sudo lvextend -L +500M --resizefs /dev/labvg/data
df -h /mnt/data             # now ~1.3G
cat /mnt/data/hello.txt     # data is still there
```

### 6. Create a striped Logical Volume

```bash
# A striped LV splits I/O across multiple PVs for better throughput
sudo lvcreate -L 200M -i 2 -n striped labvg
sudo lvs -o +stripes,stripe_size
sudo lvdisplay /dev/labvg/striped
```

### 7. Create an LVM snapshot

```bash
# Write some data
sudo mkfs.ext4 /dev/labvg/striped
sudo mkdir -p /mnt/striped
sudo mount /dev/labvg/striped /mnt/striped
echo "before snapshot" | sudo tee /mnt/striped/state.txt

# Take a snapshot (100M reserved for COW changes)
sudo lvcreate -L 100M -s -n snap_striped /dev/labvg/striped
sudo lvs                    # note the snapshot origin

# Modify data
echo "after snapshot" | sudo tee /mnt/striped/state.txt

# Restore the snapshot (unmount first)
sudo umount /mnt/striped
sudo lvconvert --merge /dev/labvg/snap_striped
# Reactivate and remount
sudo lvchange -an /dev/labvg/striped && sudo lvchange -ay /dev/labvg/striped
sudo mount /dev/labvg/striped /mnt/striped
cat /mnt/striped/state.txt  # "before snapshot" — restored!
```

### 8. Clean up

```bash
sudo umount /mnt/data /mnt/striped
sudo lvremove -f labvg/striped labvg/data
sudo vgremove labvg
sudo pvremove /dev/vdb /dev/vdc /dev/vdd /dev/vde
```

---

## ZFS Guided Tutorial

### 1. Explore available disks

```bash
lsblk
# You should see vdb, vdc, vdd, vde (1G each)
```

### 2. Create a simple pool (single disk)

```bash
sudo zpool create tank /dev/vdb
sudo zpool status tank       # ONLINE, no redundancy
sudo zpool list              # capacity and usage
df -h /tank                  # auto-mounted
sudo zpool destroy tank      # clean up for next step
```

### 3. Create a mirror pool (RAID1)

```bash
sudo zpool create tank mirror /dev/vdb /dev/vdc
sudo zpool status tank       # two disks in mirror
# Write some data
echo "mirror test" | sudo tee /tank/hello.txt

# Simulate a disk failure and resilver
sudo zpool offline tank /dev/vdc
sudo zpool status tank       # vdc is OFFLINE
cat /tank/hello.txt          # data is still readable!
sudo zpool online tank /dev/vdc
sudo zpool scrub tank        # trigger resilver
sudo zpool status tank       # back to healthy
sudo zpool destroy tank
```

### 4. Create a RAIDZ pool (RAID5-like)

```bash
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo zpool status tank       # raidz1 with 4 disks
sudo zpool list tank         # usable capacity is ~3G (one disk for parity)
```

### 5. Create datasets with compression

```bash
# Create a dataset with lz4 compression (default)
sudo zfs create tank/data
sudo zfs set compression=lz4 tank/data
sudo zfs get compression tank/data

# Create a second dataset with a quota
sudo zfs create tank/logs
sudo zfs set quota=500M tank/logs
sudo zfs set compression=zstd tank/logs
sudo zfs list -o name,used,avail,quota,compress
```

### 6. Snapshots and rollbacks

```bash
# Write data
echo "version 1" | sudo tee /tank/data/file.txt
sudo zfs snapshot tank/data@v1

# Modify data
echo "version 2" | sudo tee /tank/data/file.txt
sudo zfs snapshot tank/data@v2

# List snapshots
sudo zfs list -t snapshot

# Browse a snapshot (read-only)
ls /tank/data/.zfs/snapshot/v1/
cat /tank/data/.zfs/snapshot/v1/file.txt   # "version 1"

# Rollback to v1 (destroys v2 snapshot)
sudo zfs rollback -r tank/data@v1
cat /tank/data/file.txt     # "version 1" — restored!
```

### 7. Send and receive (backup/clone)

```bash
# Take a fresh snapshot
echo "important data" | sudo tee /tank/data/important.txt
sudo zfs snapshot tank/data@backup

# Send the snapshot to a new dataset
sudo zfs send tank/data@backup | sudo zfs receive tank/restore
ls /tank/restore/            # same files as tank/data
cat /tank/restore/important.txt

# Incremental send (send only differences)
echo "new data" | sudo tee /tank/data/new.txt
sudo zfs snapshot tank/data@backup2
sudo zfs send -i tank/data@backup tank/data@backup2 | sudo zfs receive tank/restore
cat /tank/restore/new.txt    # incremental data received
```

### 8. Inspect and scrub

```bash
# Check pool I/O stats
sudo zpool iostat tank 1 5   # refresh every 1s, 5 samples

# Scrub to verify data integrity
sudo zpool scrub tank
sudo zpool status tank       # check scrub progress and errors

# View all ZFS properties
sudo zfs get all tank/data | head -20
```

### 9. Clean up

```bash
sudo zpool destroy tank
```

---

## Managing VMs

```bash
qlab status                # show all running VMs
qlab stop raid-lab         # stop both VMs
qlab stop raid-lab-lvm     # stop only LVM VM
qlab stop raid-lab-zfs     # stop only ZFS VM
qlab log raid-lab-lvm      # view LVM VM boot log
qlab log raid-lab-zfs      # view ZFS VM boot log
qlab uninstall raid-lab    # stop all VMs and remove plugin
```
