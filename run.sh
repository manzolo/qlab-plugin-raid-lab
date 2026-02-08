#!/usr/bin/env bash
# raid-lab run script — boots two VMs for LVM and ZFS disk management labs

set -euo pipefail

PLUGIN_NAME="raid-lab"
LVM_VM="raid-lab-lvm"
ZFS_VM="raid-lab-zfs"
LVM_SSH_PORT=2224
ZFS_SSH_PORT=2225
DISK_SIZE="1G"
DISK_COUNT=4

echo "============================================="
echo "  raid-lab: LVM & ZFS Disk Management Lab"
echo "============================================="
echo ""
echo "  This lab creates two VMs, each with 4 extra disks:"
echo ""
echo "    1. raid-lab-lvm  (SSH port $LVM_SSH_PORT)"
echo "       Practice LVM: pvcreate, vgcreate, lvcreate"
echo ""
echo "    2. raid-lab-zfs  (SSH port $ZFS_SSH_PORT)"
echo "       Practice ZFS: zpool, zfs snapshot, send/receive"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY=$(get_config DEFAULT_MEMORY 1024)

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by both VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  Both VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for both VMs"
echo ""

# --- LVM VM cloud-init ---
info "Creating cloud-init for $LVM_VM..."

cat > "$LAB_DIR/user-data-lvm" <<'USERDATA'
#cloud-config
hostname: raid-lab-lvm
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
ssh_pwauth: true
packages:
  - lvm2
write_files:
  - path: /etc/motd.raw
    content: |
      \033[1;36m=============================================\033[0m
        \033[1;32mraid-lab-lvm\033[0m — \033[1mLVM Disk Management Lab\033[0m
      \033[1;36m=============================================\033[0m

        \033[1;33mObjectives:\033[0m
          - Create Physical Volumes (PV)
          - Create a Volume Group (VG)
          - Create and resize Logical Volumes (LV)
          - Understand LVM striping and mirroring

        \033[1;33mAvailable disks:\033[0m  /dev/vdb, /dev/vdc, /dev/vdd, /dev/vde (1G each)

        \033[1;33mUseful commands:\033[0m
          \033[0;36mlsblk\033[0m                          list block devices
          \033[0;36msudo pvcreate /dev/vdb\033[0m          create physical volume
          \033[0;36msudo pvs\033[0m                        list physical volumes
          \033[0;36msudo vgcreate myvg /dev/vdb /dev/vdc\033[0m  create volume group
          \033[0;36msudo vgs\033[0m                        list volume groups
          \033[0;36msudo lvcreate -L 500M -n mylv myvg\033[0m   create logical volume
          \033[0;36msudo lvs\033[0m                        list logical volumes

        \033[1;33mCredentials:\033[0m  \033[1mlabuser\033[0m / \033[1mlabpass\033[0m
        \033[1;33mExit:\033[0m        type '\033[1mexit\033[0m'

      \033[1;36m=============================================\033[0m

runcmd:
  - chmod -x /etc/update-motd.d/*
  - "sed -i 's/^#\\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config"
  - "sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd"
  - 'printf ''%b'' "$(cat /etc/motd.raw)" > /etc/motd'
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== raid-lab-lvm VM is ready! ==="
USERDATA

cat > "$LAB_DIR/meta-data-lvm" <<METADATA
instance-id: ${LVM_VM}-001
local-hostname: ${LVM_VM}
METADATA

success "Created cloud-init for $LVM_VM"

# --- ZFS VM cloud-init ---
info "Creating cloud-init for $ZFS_VM..."

cat > "$LAB_DIR/user-data-zfs" <<'USERDATA'
#cloud-config
hostname: raid-lab-zfs
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
ssh_pwauth: true
packages:
  - zfsutils-linux
write_files:
  - path: /etc/motd.raw
    content: |
      \033[1;36m=============================================\033[0m
        \033[1;32mraid-lab-zfs\033[0m — \033[1mZFS Storage Lab\033[0m
      \033[1;36m=============================================\033[0m

        \033[1;33mObjectives:\033[0m
          - Create a ZFS pool (mirror, raidz)
          - Create datasets and set properties
          - Take snapshots and rollback
          - Practice send/receive

        \033[1;33mAvailable disks:\033[0m  /dev/vdb, /dev/vdc, /dev/vdd, /dev/vde (1G each)

        \033[1;33mUseful commands:\033[0m
          \033[0;36mlsblk\033[0m                          list block devices
          \033[0;36msudo zpool create mypool mirror /dev/vdb /dev/vdc\033[0m
          \033[0;36msudo zpool status\033[0m               pool status
          \033[0;36msudo zpool list\033[0m                 list pools
          \033[0;36msudo zfs create mypool/data\033[0m     create dataset
          \033[0;36msudo zfs list\033[0m                   list datasets
          \033[0;36msudo zfs snapshot mypool/data@snap1\033[0m  take snapshot
          \033[0;36msudo zfs rollback mypool/data@snap1\033[0m  rollback

        \033[1;33mCredentials:\033[0m  \033[1mlabuser\033[0m / \033[1mlabpass\033[0m
        \033[1;33mExit:\033[0m        type '\033[1mexit\033[0m'

      \033[1;36m=============================================\033[0m

runcmd:
  - chmod -x /etc/update-motd.d/*
  - "sed -i 's/^#\\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config"
  - "sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd"
  - 'printf ''%b'' "$(cat /etc/motd.raw)" > /etc/motd'
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - modprobe zfs 2>/dev/null || true
  - echo "=== raid-lab-zfs VM is ready! ==="
USERDATA

cat > "$LAB_DIR/meta-data-zfs" <<METADATA
instance-id: ${ZFS_VM}-001
local-hostname: ${ZFS_VM}
METADATA

success "Created cloud-init for $ZFS_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_LVM="$LAB_DIR/cidata-lvm.iso"
genisoimage -output "$CIDATA_LVM" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data-lvm" "$LAB_DIR/meta-data-lvm" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_LVM"

CIDATA_ZFS="$LAB_DIR/cidata-zfs.iso"
genisoimage -output "$CIDATA_ZFS" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data-zfs" "$LAB_DIR/meta-data-zfs" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ZFS"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_LVM="$LAB_DIR/${LVM_VM}-disk.qcow2"
if [[ -f "$OVERLAY_LVM" ]]; then rm -f "$OVERLAY_LVM"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_LVM"

OVERLAY_ZFS="$LAB_DIR/${ZFS_VM}-disk.qcow2"
if [[ -f "$OVERLAY_ZFS" ]]; then rm -f "$OVERLAY_ZFS"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_ZFS"
echo ""

# =============================================
# Step 5: Create extra virtual disks
# =============================================
info "Step 5: Extra virtual disks (${DISK_COUNT} x ${DISK_SIZE} per VM)"
echo ""
echo "  These disks will appear as /dev/vdb, /dev/vdc, /dev/vdd, /dev/vde"
echo "  inside each VM, ready for LVM or ZFS operations."
echo ""

LVM_DRIVE_ARGS=()
for i in $(seq 1 "$DISK_COUNT"); do
    disk="$LAB_DIR/lvm-disk${i}.qcow2"
    if [[ -f "$disk" ]]; then rm -f "$disk"; fi
    create_disk "$disk" "$DISK_SIZE"
    LVM_DRIVE_ARGS+=(-drive "file=$disk,format=qcow2,if=virtio")
done

ZFS_DRIVE_ARGS=()
for i in $(seq 1 "$DISK_COUNT"); do
    disk="$LAB_DIR/zfs-disk${i}.qcow2"
    if [[ -f "$disk" ]]; then rm -f "$disk"; fi
    create_disk "$disk" "$DISK_SIZE"
    ZFS_DRIVE_ARGS+=(-drive "file=$disk,format=qcow2,if=virtio")
done
echo ""

# =============================================
# Step 6: Start both VMs
# =============================================
info "Step 6: Starting VMs"
echo ""

info "Starting $LVM_VM (SSH port $LVM_SSH_PORT)..."
start_vm "$OVERLAY_LVM" "$CIDATA_LVM" "$MEMORY" "$LVM_VM" "$LVM_SSH_PORT" \
    "${LVM_DRIVE_ARGS[@]}"
echo ""

info "Starting $ZFS_VM (SSH port $ZFS_SSH_PORT)..."
start_vm "$OVERLAY_ZFS" "$CIDATA_ZFS" "$MEMORY" "$ZFS_VM" "$ZFS_SSH_PORT" \
    "${ZFS_DRIVE_ARGS[@]}"

echo ""
echo "============================================="
echo "  raid-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  LVM VM:"
echo "    SSH:   qlab shell $LVM_VM"
echo "    Log:   qlab log $LVM_VM"
echo "    Port:  $LVM_SSH_PORT"
echo ""
echo "  ZFS VM:"
echo "    SSH:   qlab shell $ZFS_VM"
echo "    Log:   qlab log $ZFS_VM"
echo "    Port:  $ZFS_SSH_PORT"
echo ""
echo "  Credentials (both VMs):"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Wait ~60s for boot + package installation."
echo ""
echo "  Stop both VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Stop a single VM:"
echo "    qlab stop $LVM_VM"
echo "    qlab stop $ZFS_VM"
echo "============================================="
