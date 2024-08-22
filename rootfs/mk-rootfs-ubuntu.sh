#!/bin/bash

DEB_REPO="http://mirrors.ustc.edu.cn/ubuntu-ports"
DEB_DISTRO="noble"
PREINSTALL_PACKAGES="nano,build-essential"
OVERLAY_DIR="overlay-ubuntu"
SOURCES_LIST_FILE="sources.list.ubuntu"

ROOTFS_DIR="rootfs-ubuntu"
ROOTFS_BASE_ARCHIVE="rootfs-ubuntu-base.tar.gz"

ROOTFS_MINIMAL_ARCHIVE="rootfs-ubuntu-minimal.tar.gz"
ROOTFS_MINIMAL_DIR="rootfs-ubuntu-minimal"

ROOTFS_FULL_ARCHIVE="rootfs-ubuntu-full.tar.gz"
ROOTFS_FULL_DIR="rootfs-ubuntu-full"

if [ $(id -u) != "0" ]; then
    echo "Need root privilege to create rootfs!"
    exit 1
fi

if [ ! -f "${ROOTFS_BASE_ARCHIVE}" ]; then
    echo "No base rootfs found, start building..."
    debootstrap --arch=arm64 --include="${PREINSTALL_PACKAGES}" "${DEB_DISTRO}" "${ROOTFS_DIR}" "${DEB_REPO}"
    tar --xform s:'^./':: -czpf "${ROOTFS_BASE_ARCHIVE}" --xattrs -C "${ROOTFS_DIR}" .
    echo "Base rootfs building completed."
fi

if [ ! -f "${ROOTFS_MINIMAL_ARCHIVE}" ]; then
    echo "No rootfs-minimal found, start building..."
    if [ ! -d "${ROOTFS_MINIMAL_DIR}" ]; then
        mkdir -p "${ROOTFS_MINIMAL_DIR}"
        tar -xzf "${ROOTFS_BASE_ARCHIVE}" --xattrs --xattrs-include='*' -C "${ROOTFS_MINIMAL_DIR}"
    fi

    cp /usr/bin/qemu-aarch64-static "${ROOTFS_MINIMAL_DIR}/usr/bin/"

    if [ -d "${OVERLAY_DIR}" ]; then
        cp -rf "${OVERLAY_DIR}/." "${ROOTFS_MINIMAL_DIR}/"
    fi

    cp -f "${SOURCES_LIST_FILE}" "${ROOTFS_MINIMAL_DIR}/etc/apt/sources.list"
    rm -f "${ROOTFS_MINIMAL_DIR}/etc/resolv.conf"
    cp /etc/resolv.conf "${ROOTFS_MINIMAL_DIR}/etc/resolv.conf"

    mount --bind /dev "${ROOTFS_MINIMAL_DIR}/dev"
    mount --bind /proc "${ROOTFS_MINIMAL_DIR}/proc"

    cat << EOF | chroot "${ROOTFS_MINIMAL_DIR}"

rm -rf /debootstrap || true

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

apt-get update

apt-get install -fy locales
sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/default/locale
dpkg-reconfigure locales

useradd photonicat -m -u 1000 -s /bin/bash || true
usermod -a -G sudo photonicat
usermod -a -G video photonicat
usermod -a -G render photonicat
echo 'root:photonicat' | chpasswd
echo 'photonicat:photonicat' | chpasswd
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" >/etc/timezone
echo "photonicat-ubuntu" >/etc/hostname
echo "127.0.0.1 localhost" >/etc/hosts
echo "127.0.1.1 photonicat-ubuntu" >>/etc/hosts
echo "" >>/etc/hosts
echo "# The following lines are desirable for IPv6 capable hosts" >>/etc/hosts
echo "::1       localhost ip6-localhost ip6-loopback" >>/etc/hosts
echo "ff02::1   ip6-allnodes" >>/etc/hosts
echo "ff02::2   ip6-allrouters" >>/etc/hosts

apt-get install -fy sudo fakeroot devscripts cmake binfmt-support dh-make \
    dh-exec device-tree-compiler bc cpio parted dosfstools mtools alsa-utils \
    libssl-dev dpkg-dev isc-dhcp-client-ddns build-essential libgpiod2 \
    libjson-c5 libusb-1.0-0 nano network-manager i2c-tools git \
    usbutils pciutils htop openssh-server build-essential autotools-dev \
    meson libglib2.0-dev libjson-c-dev libgpiod-dev libusb-1.0-0-dev gdb \
    p7zip-full net-tools iotop wget linux-firmware

apt-get clean

usermod -a -G audio photonicat

rm -f /etc/resolv.conf
ln -sf ../run/NetworkManager/resolv.conf /etc/resolv.conf

EOF

    umount -f "${ROOTFS_MINIMAL_DIR}/dev"
    umount -f "${ROOTFS_MINIMAL_DIR}/proc"

    tar --xform s:'^./':: -czpf "${ROOTFS_MINIMAL_ARCHIVE}" --xattrs -C "${ROOTFS_MINIMAL_DIR}" .
    echo "rootfs-minimal building completed."
fi


if [ ! -f "${ROOTFS_FULL_ARCHIVE}" ]; then
    echo "No rootfs-full found, start building..."
    if [ ! -d "${ROOTFS_FULL_DIR}" ]; then
        mkdir -p "${ROOTFS_FULL_DIR}"
        tar -xzf "${ROOTFS_MINIMAL_ARCHIVE}" --xattrs --xattrs-include='*' -C "${ROOTFS_FULL_DIR}"
    fi

    cp -f "${SOURCES_LIST_FILE}" "${ROOTFS_FULL_DIR}/etc/apt/sources.list"
    rm -f "${ROOTFS_FULL_DIR}/etc/resolv.conf"
    cp /etc/resolv.conf "${ROOTFS_FULL_DIR}/etc/resolv.conf"

    mount --bind /dev "${ROOTFS_FULL_DIR}/dev"
    mount --bind /proc "${ROOTFS_FULL_DIR}/proc"

    cat << EOF | chroot "${ROOTFS_FULL_DIR}"

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

apt-get install -fy pipewire pipewire-pulse pavucontrol \
    zenity ubuntu-gnome-desktop gnome celluloid fonts-cantarell fonts-wqy-zenhei \
    fonts-noto-cjk ibus ibus-libpinyin ibus-gtk ibus-gtk3 \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-tools gstreamer1.0-alsa \
    gstreamer1.0-plugins-base-apps cheese glmark2-es2 glmark2-es2-wayland \
    firefox audacious gnome-shell-extensions vlc gparted

apt-get clean

usermod -a -G render gdm
touch /usr/share/pipewire/media-session.d/with-pulseaudio

rm -f /etc/resolv.conf
ln -sf ../run/NetworkManager/resolv.conf /etc/resolv.conf

EOF

    umount -f "${ROOTFS_FULL_DIR}/dev"
    umount -f "${ROOTFS_FULL_DIR}/proc"

    tar --xform s:'^./':: -czpf "${ROOTFS_FULL_ARCHIVE}" --xattrs -C "${ROOTFS_FULL_DIR}" .
    echo "rootfs-full building completed."
fi
