# raid-lab — LVM & ZFS Disk Management Lab

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for practicing disk management:

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `raid-lab-lvm` | 2224 | `lvm2` | Physical Volumes, Volume Groups, Logical Volumes |
| `raid-lab-zfs` | 2225 | `zfsutils-linux` | ZFS pools, datasets, snapshots |

Each VM is provisioned with **4 extra virtual disks** (1G each) that appear as `/dev/vdb`, `/dev/vdc`, `/dev/vdd`, `/dev/vde`.

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

## LVM Exercises

```bash
# Create physical volumes
sudo pvcreate /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo pvs

# Create a volume group
sudo vgcreate myvg /dev/vdb /dev/vdc
sudo vgs

# Create a logical volume
sudo lvcreate -L 500M -n mylv myvg
sudo lvs

# Format and mount
sudo mkfs.ext4 /dev/myvg/mylv
sudo mkdir /mnt/mylv
sudo mount /dev/myvg/mylv /mnt/mylv

# Extend the volume group and logical volume
sudo vgextend myvg /dev/vdd
sudo lvextend -L +500M /dev/myvg/mylv
sudo resize2fs /dev/myvg/mylv
```

## ZFS Exercises

```bash
# Create a mirror pool
sudo zpool create mypool mirror /dev/vdb /dev/vdc
sudo zpool status

# Create a raidz pool (use all 4 disks)
sudo zpool destroy mypool
sudo zpool create mypool raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo zpool status

# Create datasets
sudo zfs create mypool/data
sudo zfs list

# Snapshots
echo "hello" | sudo tee /mypool/data/test.txt
sudo zfs snapshot mypool/data@snap1
echo "modified" | sudo tee /mypool/data/test.txt
sudo zfs rollback mypool/data@snap1
cat /mypool/data/test.txt  # back to "hello"
```

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
