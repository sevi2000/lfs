#!/bin/bash

set -o pipefail

# ==========================================
# DISK PARTITIONING AND FORMATTING SCRIPT
# ==========================================

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Please run as root."
    exit 1
fi

# Check required commands
for CMD in parted partprobe lsblk blkid mkfs.fat mkfs.ext4 mkswap blockdev udevadm; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "[ERROR] Required command not found: $CMD"
        exit 1
    fi
done

ERRORS=0

# ==========================================
# DISPLAY AVAILABLE DISKS
# ==========================================

echo "=========================================="
echo "       DISK PARTITIONING TOOL"
echo "=========================================="

echo ""
echo "Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL

echo ""
read -rp "Enter disk name (e.g. vda, sda): " DISK

DEVICE="/dev/$DISK"

# ==========================================
# VALIDATE DISK
# ==========================================

if [[ ! -b "$DEVICE" ]]; then
    echo "[ERROR] Disk $DEVICE does not exist."
    exit 1
fi

if [[ "$(lsblk -dn -o TYPE "$DEVICE")" != "disk" ]]; then
    echo "[ERROR] Selected device is not a disk."
    exit 1
fi

# Prevent operating on a disk containing mounted partitions
if lsblk -nrpo MOUNTPOINT "$DEVICE" | grep -qE '.+'; then
    echo "[ERROR] Disk contains mounted filesystems."
    echo "Unmount them before proceeding."
    exit 1
fi

# Check minimum disk size (49 GiB)
SIZE=$(blockdev --getsize64 "$DEVICE")
MIN_SIZE=$((49 * 1024 * 1024 * 1024))

if (( SIZE < MIN_SIZE )); then
    echo "[ERROR] Disk must be at least 49 GiB."
    exit 1
fi

echo ""
echo "Selected disk:"
lsblk "$DEVICE"

echo ""
echo "WARNING: ALL DATA ON $DEVICE WILL BE DESTROYED!"
read -rp "Type YES to continue: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
    echo "Operation cancelled."
    exit 1
fi

# ==========================================
# CREATE PARTITION TABLE
# ==========================================

echo ""
echo "[INFO] Creating GPT partition table..."

parted -s "$DEVICE" mklabel gpt || exit 1

# ==========================================
# CREATE PARTITIONS
# ==========================================

echo "[INFO] Creating partition 1 (1 GiB)..."

parted -s "$DEVICE" mkpart primary fat32 1MiB 1025MiB || exit 1

echo "[INFO] Creating partition 2 (4 GiB)..."

parted -s "$DEVICE" mkpart primary linux-swap 1025MiB 5121MiB || exit 1

echo "[INFO] Creating partition 3 (remaining space)..."

parted -s "$DEVICE" mkpart primary ext4 5121MiB 100% || exit 1

# Update kernel partition table
partprobe "$DEVICE" || exit 1
udevadm settle

# Determine partition naming (supports NVMe and standard disks)
if [[ "$DISK" =~ [0-9]$ ]]; then
    PART1="${DEVICE}p1"
    PART2="${DEVICE}p2"
    PART3="${DEVICE}p3"
else
    PART1="${DEVICE}1"
    PART2="${DEVICE}2"
    PART3="${DEVICE}3"
fi

# ==========================================
# WAIT FOR PARTITIONS
# ==========================================

echo ""
echo "[INFO] Waiting for partitions..."

for PART in "$PART1" "$PART2" "$PART3"; do
    for i in {1..10}; do
        [[ -b "$PART" ]] && break
        sleep 1
    done

    if [[ ! -b "$PART" ]]; then
        echo "[ERROR] Partition $PART was not created."
        exit 1
    fi
done

# ==========================================
# CREATE FILESYSTEMS
# ==========================================

echo ""
echo "[INFO] Creating FAT32 filesystem..."

mkfs.fat -F 32 "$PART1" || exit 1

echo "[INFO] Creating SWAP..."

mkswap "$PART2" || exit 1

echo "[INFO] Creating EXT4 filesystem..."

mkfs.ext4 -F "$PART3" || exit 1

udevadm settle

# ==========================================
# SANITY CHECK
# ==========================================

sanity_check() {

    local ERRORS=0

    echo ""
    echo "=========================================="
    echo "             SANITY CHECK"
    echo "=========================================="

    # Check partition count
    COUNT=$(lsblk -ln -o TYPE "$DEVICE" | grep -c '^part$')

    if [[ "$COUNT" -eq 3 ]]; then
        echo "[OK] Exactly 3 partitions found."
    else
        echo "[ERROR] Expected 3 partitions, found $COUNT."
        ((ERRORS++))
    fi

    # Check GPT partition table
    #TABLE=$(parted -sm "$DEVICE" print | cut -d: -f6)
    TABLE=$(parted -sm "$DEVICE" print | sed -n '2p' | cut -d: -f6)

    if [[ "$TABLE" == "gpt" ]]; then
        echo "[OK] GPT partition table detected."
    else
        echo "[ERROR] Expected GPT, found $TABLE."
        ((ERRORS++))
    fi

    # Check filesystems
    check_fs() {

        local PART="$1"
        local EXPECTED="$2"
        local ACTUAL

        ACTUAL=$(blkid -s TYPE -o value "$PART" 2>/dev/null)

        if [[ "$ACTUAL" == "$EXPECTED" ]]; then
            echo "[OK] $PART filesystem: $ACTUAL"
        else
            echo "[ERROR] $PART expected $EXPECTED, found ${ACTUAL:-NONE}."
            ((ERRORS++))
        fi
    }

    check_fs "$PART1" "vfat"
    check_fs "$PART2" "swap"
    check_fs "$PART3" "ext4"

    # Check partition sizes (tolerance: 16 MiB)
    check_size() {

        local PART="$1"
        local EXPECTED="$2"
        local ACTUAL
        local DIFF

        ACTUAL=$(blockdev --getsize64 "$PART")
        DIFF=$(( ACTUAL > EXPECTED ? ACTUAL - EXPECTED : EXPECTED - ACTUAL ))

        if (( DIFF <= 16777216 )); then
            echo "[OK] $PART size is correct."
        else
            echo "[ERROR] $PART size mismatch."
            ((ERRORS++))
        fi
    }

    check_size "$PART1" $((1024 * 1024 * 1024))
    check_size "$PART2" $((4096 * 1024 * 1024))

    # Check third partition exists and has sufficient size
    SIZE3=$(blockdev --getsize64 "$PART3")

    if (( SIZE3 > 40 * 1024 * 1024 * 1024 )); then
        echo "[OK] $PART3 has sufficient remaining space."
    else
        echo "[ERROR] $PART3 is smaller than expected."
        ((ERRORS++))
    fi

    # Final result
    echo ""
    echo "=========================================="

    if [[ "$ERRORS" -eq 0 ]]; then
        echo "       SANITY CHECK PASSED"
        echo "=========================================="
        return 0
    else
        echo "       SANITY CHECK FAILED"
        echo "       Errors: $ERRORS"
        echo "=========================================="
        return 1
    fi
}

# ==========================================
# FINAL VERIFICATION
# ==========================================

if ! sanity_check; then
    echo "[ERROR] Disk configuration validation failed!"
    exit 1
fi

echo ""
echo "=========================================="
echo "       FINAL DISK CONFIGURATION"
echo "=========================================="

lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID "$DEVICE"

echo ""
echo "[SUCCESS] Disk partitioning completed!"
echo "[SUCCESS] Filesystems created successfully!"

