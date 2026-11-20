#!/bin/bash

# ==========================================
# LFS PARTITION MOUNTING SCRIPT
# ==========================================

set -e

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Run this script as root."
    exit 1
fi

# Check required commands
for CMD in lsblk blkid mount swapon findmnt; do
    command -v "$CMD" >/dev/null 2>&1 || {
        echo "[ERROR] Missing command: $CMD"
        exit 1
    }
done

echo "=========================================="
echo "          LFS MOUNTING TOOL"
echo "=========================================="

# Select disk
echo ""
echo "Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL

echo ""
read -rp "Enter disk name (e.g. sda, vda): " DISK

DEVICE="/dev/$DISK"

if [[ ! -b "$DEVICE" ]]; then
    echo "[ERROR] Disk does not exist."
    exit 1
fi

# Handle standard and NVMe disk naming
if [[ "$DISK" =~ [0-9]$ ]]; then
    PART1="${DEVICE}p1"
    PART2="${DEVICE}p2"
    PART3="${DEVICE}p3"
else
    PART1="${DEVICE}1"
    PART2="${DEVICE}2"
    PART3="${DEVICE}3"
fi

# Verify partitions
for PART in "$PART1" "$PART2" "$PART3"; do
    if [[ ! -b "$PART" ]]; then
        echo "[ERROR] Missing partition: $PART"
        exit 1
    fi
done

# Verify filesystems
check_fs() {
    ACTUAL=$(blkid -s TYPE -o value "$1" 2>/dev/null || true)

    if [[ "$ACTUAL" != "$2" ]]; then
        echo "[ERROR] $1: expected $2, found ${ACTUAL:-NONE}"
        exit 1
    fi

    echo "[OK] $1 filesystem: $ACTUAL"
}

echo ""
echo "Checking filesystems..."

check_fs "$PART1" "vfat"
check_fs "$PART2" "swap"
check_fs "$PART3" "ext4"

# LFS mount point
echo ""
read -rp "Enter LFS mount point (default: /mnt/lfs): " LFS
LFS=${LFS:-/mnt/lfs}

# Create mount directories
mkdir -p "$LFS"

# Confirm mounting
echo ""
echo "Mount configuration:"
echo "Root: $PART3 -> $LFS"
echo "EFI:  $PART1 -> $LFS/boot/efi"
echo "Swap: $PART2"

read -rp "Continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Operation cancelled."
    exit 1
fi

# ==========================================
# MOUNT ROOT PARTITION
# ==========================================

echo ""
echo "[INFO] Mounting root partition..."

mount --mkdir "$PART3" "$LFS"

echo "[OK] Root partition mounted."

# ==========================================
# MOUNT EFI PARTITION
# ==========================================

echo ""
echo "[INFO] Mounting EFI partition..."

mount --mkdir "$PART1" "$LFS/boot/efi"

echo "[OK] EFI partition mounted."

# ==========================================
# ENABLE SWAP
# ==========================================

echo ""
echo "[INFO] Enabling swap..."

swapon "$PART2"

echo "[OK] Swap enabled."

# ==========================================
# SANITY CHECK
# ==========================================

echo ""
echo "=========================================="
echo "          MOUNT SANITY CHECK"
echo "=========================================="

ERRORS=0

# Check root mount
if findmnt -rn -S "$PART3" -T "$LFS" >/dev/null; then
    echo "[OK] Root partition mounted at $LFS"
else
    echo "[ERROR] Root partition not mounted correctly."
    ((ERRORS++))
fi

# Check EFI mount
if findmnt -rn -S "$PART1" -T "$LFS/boot/efi" >/dev/null; then
    echo "[OK] EFI partition mounted at $LFS/boot/efi"
else
    echo "[ERROR] EFI partition not mounted correctly."
    ((ERRORS++))
fi

# Check swap
if swapon --noheadings --raw --show=NAME | grep -Fxq "$PART2"; then
    echo "[OK] Swap is active."
else
    echo "[ERROR] Swap is not active."
    ((ERRORS++))
fi

echo ""

if [[ "$ERRORS" -eq 0 ]]; then
    echo "=========================================="
    echo "       MOUNT SANITY CHECK PASSED"
    echo "=========================================="
else
    echo "=========================================="
    echo "       MOUNT SANITY CHECK FAILED"
    echo "       Errors: $ERRORS"
    echo "=========================================="
    exit 1
fi

# ==========================================
# FINAL STATUS
# ==========================================

echo ""
echo "Mounted filesystems:"
findmnt -R "$LFS"

echo ""
echo "Active swap:"
swapon --show

echo ""
echo "[SUCCESS] LFS partitions mounted successfully!"
echo "LFS directory: $LFS"

