#!/bin/bash

ARCHIVE_DIR="archives"
WORKDIR="$(pwd)"

UBOOT_VERSION="u-boot-2023.04"
KERNEL_VERSION="linux-6.1.106"

UBOOT_ARCHIVE="${UBOOT_VERSION}.tar.bz2"
KERNEL_ARCHIVE="${KERNEL_VERSION}.tar.xz"

UBOOT_SITE="https://ftp.denx.de/pub/u-boot/${UBOOT_ARCHIVE}"
KERNEL_SITE="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_ARCHIVE}"

JOBS="4"

export ROCKCHIP_TPL="${WORKDIR}/rkbin/bin/rk35/rk3568_ddr_1332MHz_v1.21.bin"
export BL31="${WORKDIR}/rkbin/bin/rk35/rk3568_bl31_v1.44.elf"

if [ ! -f "${ARCHIVE_DIR}/${UBOOT_ARCHIVE}" ]; then
    wget -O "${ARCHIVE_DIR}/${UBOOT_ARCHIVE}" "${UBOOT_SITE}"
fi

if [ ! -f "${ARCHIVE_DIR}/${KERNEL_ARCHIVE}" ]; then
    wget -O "${ARCHIVE_DIR}/${KERNEL_ARCHIVE}" "${KERNEL_SITE}"
fi

if [ ! -d "u-boot" ]; then
    tar -xjf "${ARCHIVE_DIR}/${UBOOT_ARCHIVE}"
    mv "${UBOOT_VERSION}" u-boot

    cd "${WORKDIR}/u-boot"
    for i in "${WORKDIR}/patches/u-boot/"*; do patch -p1 < "${i}"; done
    cd "${WORKDIR}"
fi

echo "Building u-boot..."

cd "${WORKDIR}/u-boot"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p build deploy
make O=build photonicat-rk3568_defconfig
make O=build -j${JOBS}
cp -v build/idbloader.img deploy/
cp -v build/u-boot.itb deploy/
cd "${WORKDIR}"

if [ ! -d "kernel" ]; then
    tar -xJf "${ARCHIVE_DIR}/${KERNEL_ARCHIVE}"
    mv "${KERNEL_VERSION}" kernel

    cd "${WORKDIR}/kernel"
    for i in "${WORKDIR}/patches/kernel/"*; do patch -Np1 < "${i}"; done
    cp -rf "${WORKDIR}/patches/kernel-overlay/." ./

    cd "${WORKDIR}"
fi

echo "Building kernel..."

cd "${WORKDIR}/kernel"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p build deploy/modules
make O=build photonicat_defconfig
make O=build Image -j${JOBS}
make O=build modules -j${JOBS}
make O=build rockchip/rk3568-photonicat.dtb
cp -v build/arch/arm64/boot/Image deploy/
cp -v build/arch/arm64/boot/dts/rockchip/rk3568-photonicat.dtb deploy/
make O=build modules_install INSTALL_MOD_PATH="${WORKDIR}/kernel/deploy/modules" INSTALL_MOD_STRIP=1
tar --owner=0 --group=0 --xform s:'^./':: -czf deploy/kmods.tar.gz -C "${WORKDIR}/kernel/deploy/modules" .
cd "${WORKDIR}"

mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d scripts/photonicat.bootscript deploy/boot.scr

echo "Base system builds completed."
#dd if=idbloader.img of=/dev/mmcblk0 seek=64 conv=notrunc
#dd if=u-boot.itb of=/dev/mmcblk0 seek=16384 conv=notrunc
