# raid-lab — LVM & ZFS Disk Management Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for practicing disk management:

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `raid-lab-lvm` | dynamic | `lvm2` | Physical Volumes, Volume Groups, Logical Volumes |
| `raid-lab-zfs` | dynamic | `zfsutils-linux` | ZFS pools, datasets, snapshots |

> All host ports are dynamically allocated. Use `qlab ports` to see the actual mappings.

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

## Exercises

> **New to LVM/ZFS?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with full examples and expected output.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **Disk Anatomy** | Explore available disks (`/dev/vdb`-`/dev/vde`) and tools on both VMs |
| 2 | **LVM Basics** | Create PVs, VG, LV, format, and mount on the LVM VM |
| 3 | **LVM Extend** | Extend a VG with a new disk and grow an LV online |
| 4 | **ZFS Basics** | Create a RAIDZ pool, datasets with compression on the ZFS VM |
| 5 | **ZFS Snapshots** | Create snapshots, modify data, and rollback |

## Automated Tests

An automated test suite validates the exercises against running VMs:

```bash
# Start the lab first
qlab run raid-lab
# Wait ~60s for cloud-init, then run all tests
qlab test raid-lab
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

## Reset

To start the lab from scratch:

```bash
qlab stop raid-lab
qlab run raid-lab
```

This recreates the overlay disks and cloud-init configuration, giving you a fresh environment.

## License

MIT
