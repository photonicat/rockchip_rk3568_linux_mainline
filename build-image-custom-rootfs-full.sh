#!/bin/sh

export WORKDIR="$(pwd)"
export PATH="${PATH}:/sbin:/usr/sbin"

IMG_FILE="deploy/rk3568-custom-full.img"
ROOTFS_FILE="${1}"
PARTITION_SCRIPT="scripts/photonicat-disk-parts-full.sfdisk"
BOOTFS_IMG_FILE="deploy/rk3568-custom-full-bootfs.img"
ROOTFS_IMG_FILE="deploy/rk3568-custom-full-rootfs.img"

IMG_SIZE="13312"
BOOTFS_SIZE="256"
ROOTFS_SIZE="12288"

if [ $(id -u) != "0" ]; then
    echo "Need root privilege to create rootfs!"
    exit 1
fi

if [ ! -f "${ROOTFS_FILE}" ]; then
    echo "Need a rootfs tarball to make system image!"
    exit 2
fi

if [ ! -f "u-boot/deploy/idbloader.img" ]; then
    echo "Missing idbloader.img, build u-boot first!"
    exit 3
fi

if [ ! -f "u-boot/deploy/u-boot.itb" ]; then
    echo "Missing u-boot.itb, build u-boot first!"
    exit 3
fi

if [ ! -f "kernel/deploy/Image" ]; then
    echo "Missing kernel image, build kernel first!"
    exit 4
fi

if [ ! -f "kernel/deploy/rk3568-photonicat.dtb" ]; then
    echo "Missing kernel device tree, build kernel first!"
    exit 4
fi

if [ ! -f "kernel/deploy/kmods.tar.gz" ]; then
    echo "Missing kernel modules, build kernel first!"
    exit 4
fi

if [ ! -f "deploy/boot.scr" ]; then
    echo "Missing boot.scr, build boot script first!"
    exit 5
fi


echo "Creating disk image..."
dd if=/dev/zero of="${IMG_FILE}" bs=1M count="${IMG_SIZE}"
sfdisk -X gpt "${IMG_FILE}" < "${PARTITION_SCRIPT}"

echo "Setup bootloader..."
dd if="u-boot/deploy/idbloader.img" of="${IMG_FILE}" seek=64 conv=notrunc
dd if="u-boot/deploy/u-boot.itb" of="${IMG_FILE}" seek=16384 conv=notrunc

echo "Creating bootfs..."
dd if=/dev/zero of="${BOOTFS_IMG_FILE}" bs=1M count="${BOOTFS_SIZE}"
mkfs.vfat -F 32 "${BOOTFS_IMG_FILE}"

TMP_MOUNT_DIR="$(mktemp -d)"
mkdir -p "${TMP_MOUNT_DIR}/bootfs"

mount "${BOOTFS_IMG_FILE}" "${TMP_MOUNT_DIR}/bootfs"
cp -v "kernel/deploy/Image" "${TMP_MOUNT_DIR}/bootfs/"
cp -v "kernel/deploy/rk3568-photonicat.dtb" "${TMP_MOUNT_DIR}/bootfs/"
cp -v deploy/boot.scr "${TMP_MOUNT_DIR}/bootfs/"
umount -f "${TMP_MOUNT_DIR}/bootfs"
rmdir "${TMP_MOUNT_DIR}/bootfs"
gzip -f "${BOOTFS_IMG_FILE}"

echo "Creating rootfs..."
dd if=/dev/zero of="${ROOTFS_IMG_FILE}" bs=1M count="${ROOTFS_SIZE}"
mkfs.ext4 -F "${ROOTFS_IMG_FILE}"

mkdir -p "${TMP_MOUNT_DIR}/rootfs"
mount "${ROOTFS_IMG_FILE}" "${TMP_MOUNT_DIR}/rootfs"
tar -xpf "${ROOTFS_FILE}" --xattrs --xattrs-include='*' -C "${TMP_MOUNT_DIR}/rootfs"
tar -xf "kernel/deploy/kmods.tar.gz" -C "${TMP_MOUNT_DIR}/rootfs/usr"
umount -f "${TMP_MOUNT_DIR}/rootfs"
rmdir "${TMP_MOUNT_DIR}/rootfs"
gzip -f "${ROOTFS_IMG_FILE}"

rmdir "${TMP_MOUNT_DIR}"

echo "Making system image..."
zcat "${BOOTFS_IMG_FILE}.gz" | dd of="${IMG_FILE}" bs=1M seek=32 conv=notrunc
zcat "${ROOTFS_IMG_FILE}.gz" | dd of="${IMG_FILE}" bs=1M seek="$(expr 32 + ${BOOTFS_SIZE})" conv=notrunc
gzip -f "${IMG_FILE}"
echo "Create system image completed."
