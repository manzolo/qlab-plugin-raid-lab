#!/usr/bin/env bash
# raid-lab run script — boots two VMs for LVM and ZFS disk management labs

set -euo pipefail

PLUGIN_NAME="raid-lab"
LVM_VM="raid-lab-lvm"
ZFS_VM="raid-lab-zfs"
DISK_SIZE="1G"
DISK_COUNT=4

echo "============================================="
echo "  raid-lab: LVM & ZFS Disk Management Lab"
echo "============================================="
echo ""
echo "  This lab creates two VMs, each with 4 extra disks:"
echo ""
echo "    1. raid-lab-lvm"
echo "       Practice LVM: pvcreate, vgcreate, lvcreate"
echo ""
echo "    2. raid-lab-zfs"
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
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1024)}"

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
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - lvm2
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mraid-lab-lvm\033[0m — \033[1mLVM Disk Management Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mDisks:\033[0m  /dev/vdb  /dev/vdc  /dev/vdd  /dev/vde  (1G each)

        \033[1;33mQuick start — try these commands in order:\033[0m

        \033[1;35m1.\033[0m \033[0;32msudo pvcreate /dev/vdb /dev/vdc /dev/vdd\033[0m
        \033[1;35m2.\033[0m \033[0;32msudo vgcreate labvg /dev/vdb /dev/vdc\033[0m
        \033[1;35m3.\033[0m \033[0;32msudo lvcreate -L 800M -n data labvg\033[0m
        \033[1;35m4.\033[0m \033[0;32msudo mkfs.ext4 /dev/labvg/data\033[0m
        \033[1;35m5.\033[0m \033[0;32msudo mount /dev/labvg/data /mnt\033[0m
        \033[1;35m6.\033[0m \033[0;32msudo vgextend labvg /dev/vdd\033[0m
        \033[1;35m7.\033[0m \033[0;32msudo lvextend -L +500M --resizefs /dev/labvg/data\033[0m

        \033[1;33mInspect:\033[0m
          \033[0;32mlsblk\033[0m   \033[0;32mpvs\033[0m   \033[0;32mvgs\033[0m   \033[0;32mlvs\033[0m   \033[0;32mdf -h /mnt\033[0m

        \033[1;33mAdvanced:\033[0m  snapshots, striping — see README
        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== raid-lab-lvm VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-lvm"

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
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - zfsutils-linux
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mraid-lab-zfs\033[0m — \033[1mZFS File System Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mDisks:\033[0m  /dev/vdb  /dev/vdc  /dev/vdd  /dev/vde  (1G each)

        \033[1;33mQuick start — try these commands in order:\033[0m

        \033[1;35m1.\033[0m \033[0;32msudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd /dev/vde\033[0m
        \033[1;35m2.\033[0m \033[0;32msudo zfs create tank/data\033[0m
        \033[1;35m3.\033[0m \033[0;32msudo zfs set compression=lz4 tank/data\033[0m
        \033[1;35m4.\033[0m \033[0;32mecho "hello ZFS" | sudo tee /tank/data/file.txt\033[0m
        \033[1;35m5.\033[0m \033[0;32msudo zfs snapshot tank/data@v1\033[0m
        \033[1;35m6.\033[0m \033[0;32mecho "modified" | sudo tee /tank/data/file.txt\033[0m
        \033[1;35m7.\033[0m \033[0;32msudo zfs rollback tank/data@v1\033[0m
        \033[1;35m8.\033[0m \033[0;32mcat /tank/data/file.txt\033[0m            \033[2m# back to "hello ZFS"\033[0m

        \033[1;33mInspect:\033[0m
          \033[0;32mzpool status\033[0m   \033[0;32mzpool list\033[0m   \033[0;32mzfs list\033[0m   \033[0;32mzfs list -t snapshot\033[0m

        \033[1;33mAdvanced:\033[0m  mirror, send/receive, scrub — see README
        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - modprobe zfs 2>/dev/null || true
  - echo "=== raid-lab-zfs VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-zfs"

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
    -graft-points "user-data=$LAB_DIR/user-data-lvm" "meta-data=$LAB_DIR/meta-data-lvm" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_LVM"

CIDATA_ZFS="$LAB_DIR/cidata-zfs.iso"
genisoimage -output "$CIDATA_ZFS" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-zfs" "meta-data=$LAB_DIR/meta-data-zfs" 2>/dev/null
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
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_LVM" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for LVM VM."
    exit 1
}

OVERLAY_ZFS="$LAB_DIR/${ZFS_VM}-disk.qcow2"
if [[ -f "$OVERLAY_ZFS" ]]; then rm -f "$OVERLAY_ZFS"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_ZFS" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for ZFS VM."
    exit 1
}
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

# Multi-VM: resource check, cleanup trap, rollback on failure
MEMORY_TOTAL=$(( MEMORY * 2 ))
check_host_resources "$MEMORY_TOTAL" 2
declare -a STARTED_VMS=()
register_vm_cleanup STARTED_VMS

info "Starting $LVM_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_LVM" "$CIDATA_LVM" "$MEMORY" "$LVM_VM" auto \
    "${LVM_DRIVE_ARGS[@]}" || exit 1
echo ""

info "Starting $ZFS_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_ZFS" "$CIDATA_ZFS" "$MEMORY" "$ZFS_VM" auto \
    "${ZFS_DRIVE_ARGS[@]}" || exit 1

# Successful start — disable cleanup trap
trap - EXIT

echo ""
echo "============================================="
echo "  raid-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  LVM VM:"
echo "    SSH:   qlab shell $LVM_VM"
echo "    Log:   qlab log $LVM_VM"
echo ""
echo "  ZFS VM:"
echo "    SSH:   qlab shell $ZFS_VM"
echo "    Log:   qlab log $ZFS_VM"
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
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
