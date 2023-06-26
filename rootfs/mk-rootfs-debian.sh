#!/bin/bash

DEB_REPO="http://deb.debian.org/debian"
DEB_DISTRO="bookworm"
PREINSTALL_PACKAGES="nano,build-essential,autotools-dev,meson,git,libglib2.0-dev,libjson-c-dev,libgpiod-dev,libusb-1.0-0-dev"
OVERLAY_DIR="overlay-debian"
SOURCES_LIST_FILE="sources.list.debian"

ROOTFS_DIR="rootfs-debian"
ROOTFS_BASE_ARCHIVE="rootfs-debian-base.tar.xz"

ROOTFS_MINIMAL_ARCHIVE="rootfs-debian-minimal.tar.xz"
ROOTFS_MINIMAL_DIR="rootfs-debian-minimal"

ROOTFS_FULL_ARCHIVE="rootfs-debian-full.tar.xz"
ROOTFS_FULL_DIR="rootfs-debian-full"

if [ $(id -u) != "0" ]; then
    echo "Need root privilege to create rootfs!"
    exit 1
fi

if [ ! -f "${ROOTFS_BASE_ARCHIVE}" ]; then
    echo "No base rootfs found, start building..."
    debootstrap --arch=arm64 --include="${PREINSTALL_PACKAGES}" "${DEB_DISTRO}" "${ROOTFS_DIR}" "${DEB_REPO}"
    tar --xform s:'^./':: -cJpf "${ROOTFS_BASE_ARCHIVE}" -C "${ROOTFS_DIR}" .
    echo "Base rootfs building completed."
fi

if [ ! -f "${ROOTFS_MINIMAL_ARCHIVE}" ]; then
    echo "No rootfs-minimal found, start building..."
    if [ ! -d "${ROOTFS_MINIMAL_DIR}" ]; then
        mkdir -p "${ROOTFS_MINIMAL_DIR}"
        tar -xJf "${ROOTFS_BASE_ARCHIVE}" -C "${ROOTFS_MINIMAL_DIR}"
    fi

    cp /usr/bin/qemu-aarch64-static "${ROOTFS_MINIMAL_DIR}/usr/bin/"

    if [ -d "${OVERLAY_DIR}" ]; then
        cp -rf "${OVERLAY_DIR}" "${ROOTFS_MINIMAL_DIR}/"
    fi

    cp -f "${SOURCES_LIST_FILE}" "${ROOTFS_MINIMAL_DIR}/etc/apt/sources.list"
    rm -f "${ROOTFS_MINIMAL_DIR}/etc/resolv.conf"
    cp /etc/resolv.conf "${ROOTFS_MINIMAL_DIR}/etc/resolv.conf"

    mount --bind /dev "${ROOTFS_MINIMAL_DIR}/dev"

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
echo 'root:photonicat' | chpasswd
echo 'photonicat:photonicat' | chpasswd
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" >/etc/timezone
echo "photonicat-debian" >/etc/hostname
echo "127.0.0.1 localhost" >/etc/hosts
echo "127.0.1.1 photonicat-debian" >>/etc/hosts
echo "" >>/etc/hosts
echo "# The following lines are desirable for IPv6 capable hosts" >>/etc/hosts
echo "::1       localhost ip6-localhost ip6-loopback" >>/etc/hosts
echo "ff02::1   ip6-allnodes" >>/etc/hosts
echo "ff02::2   ip6-allrouters" >>/etc/hosts

apt-get install -fy sudo fakeroot devscripts cmake binfmt-support dh-make \
    dh-exec device-tree-compiler bc cpio parted dosfstools mtools \
    libssl-dev dpkg-dev isc-dhcp-client-ddns build-essential libgpiod2 \
    libjson-c5 libusb-1.0-0 nano network-manager i2c-tools ntp git \
    openssh-server build-essential autotools-dev meson libglib2.0-dev \
    libjson-c-dev libgpiod-dev libusb-1.0-0-dev gdb

apt-get clean
rm -f /etc/resolv.conf
ln -sf ../run/NetworkManager/resolv.conf /etc/resolv.conf

EOF

    umount -f "${ROOTFS_MINIMAL_DIR}/dev"

    tar --xform s:'^./':: -cJpf "${ROOTFS_MINIMAL_ARCHIVE}" -C "${ROOTFS_MINIMAL_DIR}" .
    echo "rootfs-minimal building completed."
fi


if [ ! -f "${ROOTFS_FULL_ARCHIVE}" ]; then
    echo "No rootfs-full found, start building..."
    if [ ! -d "${ROOTFS_FULL_DIR}" ]; then
        mkdir -p "${ROOTFS_FULL_DIR}"
        tar -xJf "${ROOTFS_MINIMAL_ARCHIVE}" -C "${ROOTFS_FULL_DIR}"
    fi

    cp -f "${SOURCES_LIST_FILE}" "${ROOTFS_FULL_DIR}/etc/apt/sources.list"
    rm -f "${ROOTFS_FULL_DIR}/etc/resolv.conf"
    cp /etc/resolv.conf "${ROOTFS_FULL_DIR}/etc/resolv.conf"

    mount --bind /dev "${ROOTFS_FULL_DIR}/dev"

    cat << EOF | chroot "${ROOTFS_FULL_DIR}"

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

apt-get install -fy pipewire pipewire-alsa pipewire-pulse pavucontrol \
    zenity xfce4 lightdm fonts-cantarell fonts-wqy-zenhei \
    fonts-noto-cjk ibus ibus-libpinyin ibus-anthy ibus-gtk ibus-gtk3 \
    im-config parole gstreamer1.0-plugins-bad gstreamer1.0-plugins-base \
    gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-plugins-base-apps \
    cheese glmark2 glmark2-wayland firefox-esr blackbird-gtk-theme \
    bluebird-gtk-theme audacious

echo "# im-config(8) generated on Mon, 12 Dec 2022 14:26:48 +0800" >/home/photonicat/.xinputrc
echo "run_im ibus" >>/home/photonicat/.xinputrc
echo "# im-config signature: 17cc603f959ab57482fe436d81262b61  -" >>/home/photonicat/.xinputrc
chmod +x /home/photonicat/.xinputrc
chown photonicat:photonicat /home/photonicat/.xinputrc

apt-get clean

rm -f /etc/resolv.conf
ln -sf ../run/NetworkManager/resolv.conf /etc/resolv.conf

EOF

    umount -f "${ROOTFS_FULL_DIR}/dev"

    tar --xform s:'^./':: -cJpf "${ROOTFS_FULL_ARCHIVE}" -C "${ROOTFS_FULL_DIR}" .
    echo "rootfs-full building completed."
fi
