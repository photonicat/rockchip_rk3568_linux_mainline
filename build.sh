#!/bin/bash

ARCHIVE_DIR="archives"
WORKDIR="$(pwd)"

UBOOT_ARCHIVE="${ARCHIVE_DIR}/u-boot-2023.04.tar.bz2"

export ROCKCHIP_TPL="${WORKDIR}/rkbin/bin/rk35/rk3568_ddr_1332MHz_v1.13.bin"
export BL31="${WORKDIR}/rkbin/bin/rk35/rk3568_bl31_v1.34.elf"

if [ ! -f "${UBOOT_ARCHIVE}" ]; then
    wget -O "${UBOOT_ARCHIVE}" https://ftp.denx.de/pub/u-boot/u-boot-2023.04.tar.bz2
fi

if [ ! -d "u-boot" ]; then
    tar -xjf "${UBOOT_ARCHIVE}"
    mv u-boot-2023.04 u-boot

    cd "${WORKDIR}/u-boot"
    for i in "${WORKDIR}/patches/u-boot/"*; do patch -p1 < "${i}"; done
    cd "${WORKDIR}"
fi

cd "${WORKDIR}/u-boot"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p build deploy
make O=build photonicat-rk3568_defconfig
make O=build -j4
cp -v build/idbloader.img deploy/
cp -v build/u-boot.itb deploy/
cd "${WORKDIR}"

#dd if=idbloader.img of=/dev/mmcblk0 seek=64 conv=notrunc
#dd if=u-boot.itb of=/dev/mmcblk0 seek=16384 conv=notrunc
