# RAID Lab — Step-by-Step Guide

This lab teaches disk management with **LVM** (Logical Volume Manager) and **ZFS** (Zettabyte File System). Each technology runs on its own VM with 4 extra virtual disks.

## Prerequisites

Start the lab:

```bash
qlab run raid-lab
```

Wait ~60 seconds for VMs to boot. Connect to each VM:

```bash
# Terminal 1 — LVM VM
qlab shell raid-lab-lvm

# Terminal 2 — ZFS VM
qlab shell raid-lab-zfs
```

## Architecture

```
┌──────────────────────┐    ┌──────────────────────┐
│  raid-lab-lvm        │    │  raid-lab-zfs         │
│                      │    │                       │
│  Disks:              │    │  Disks:               │
│   /dev/vdb  (1G)     │    │   /dev/vdb  (1G)      │
│   /dev/vdc  (1G)     │    │   /dev/vdc  (1G)      │
│   /dev/vdd  (1G)     │    │   /dev/vdd  (1G)      │
│   /dev/vde  (1G)     │    │   /dev/vde  (1G)      │
│                      │    │                       │
│  Tools: lvm2         │    │  Tools: zfsutils-linux │
│  Commands:           │    │  Commands:            │
│   pvcreate, vgcreate │    │   zpool, zfs          │
│   lvcreate, lvextend │    │   zfs snapshot        │
└──────────────────────┘    └───────────────────────┘
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

---

## Exercise 01 — Disk Anatomy

**Goal:** Explore the available disks on each VM.

**Why:** Before managing storage, you must understand what disks are available and how the system sees them.

### 1.1 List block devices

On the **LVM VM**:

```bash
lsblk
```

**Expected output:**

```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    252:0    0    2G  0 disk
├─vda1 252:1    0  1.9G  0 part /
...
vdb    252:16   0    1G  0 disk
vdc    252:32   0    1G  0 disk
vdd    252:48   0    1G  0 disk
vde    252:64   0    1G  0 disk
```

The disks `vdb` through `vde` are your 4 extra disks for LVM practice.

### 1.2 Verify LVM tools

```bash
which pvcreate vgcreate lvcreate
```

### 1.3 Verify ZFS tools

On the **ZFS VM**:

```bash
which zpool zfs
lsblk
```

---

## Exercise 02 — LVM Basics

**Goal:** Create physical volumes, volume groups, and logical volumes.

**Why:** LVM adds a layer of abstraction between physical disks and filesystems, allowing flexible storage management (resize, snapshot, etc.).

### 2.1 Create physical volumes

On the **LVM VM**:

```bash
sudo pvcreate /dev/vdb /dev/vdc /dev/vdd
sudo pvs
```

**Expected output:**

```
  PV         VG Fmt  Attr PSize    PFree
  /dev/vdb      lvm2 ---  1020.00m 1020.00m
  /dev/vdc      lvm2 ---  1020.00m 1020.00m
  /dev/vdd      lvm2 ---  1020.00m 1020.00m
```

### 2.2 Create a volume group

```bash
sudo vgcreate labvg /dev/vdb /dev/vdc
sudo vgs
```

### 2.3 Create a logical volume

```bash
sudo lvcreate -L 800M -n data labvg
sudo lvs
```

### 2.4 Format and mount

```bash
sudo mkfs.ext4 /dev/labvg/data
sudo mount /dev/labvg/data /mnt
df -h /mnt
```

### 2.5 Write data

```bash
echo "Hello LVM" | sudo tee /mnt/test.txt
cat /mnt/test.txt
```

---

## Exercise 03 — LVM Extend

**Goal:** Extend a volume group and logical volume without downtime.

**Why:** One of LVM's biggest advantages is the ability to grow storage on-the-fly.

### 3.1 Add a disk to the VG

```bash
sudo vgextend labvg /dev/vdd
sudo vgs
```

### 3.2 Extend the LV

```bash
sudo lvextend -L +500M /dev/labvg/data
sudo lvs
```

### 3.3 Resize the filesystem

```bash
sudo resize2fs /dev/labvg/data
df -h /mnt
```

**Verification:** The filesystem should now be larger (~1.3G).

---

## Exercise 04 — ZFS Basics

**Goal:** Create a ZFS pool and dataset.

**Why:** ZFS combines volume management and filesystem into one. It provides data integrity, compression, and snapshots out of the box.

### 4.1 Create a raidz pool

On the **ZFS VM**:

```bash
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo zpool status tank
```

### 4.2 Create a dataset

```bash
sudo zfs create tank/data
sudo zfs set compression=lz4 tank/data
sudo zfs list
```

### 4.3 Write data

```bash
echo "hello ZFS" | sudo tee /tank/data/file.txt
cat /tank/data/file.txt
```

---

## Exercise 05 — ZFS Snapshots

**Goal:** Create snapshots and rollback changes.

**Why:** ZFS snapshots are instantaneous, space-efficient copies. They let you safely experiment and roll back if needed.

### 5.1 Create a snapshot

```bash
sudo zfs snapshot tank/data@v1
sudo zfs list -t snapshot
```

### 5.2 Modify data

```bash
echo "modified" | sudo tee /tank/data/file.txt
cat /tank/data/file.txt
```

### 5.3 Rollback

```bash
sudo zfs rollback tank/data@v1
cat /tank/data/file.txt
```

**Expected output:** `hello ZFS` (the original content is restored).

---

## Troubleshooting

### LVM commands fail

```bash
sudo pvs    # Check physical volumes
sudo vgs    # Check volume groups
sudo lvs    # Check logical volumes
```

### ZFS module not loaded

```bash
sudo modprobe zfs
zpool status
```

### Disks not found

```bash
lsblk -d
```

If only `vda` is shown, cloud-init may still be running:

```bash
cloud-init status --wait
```
