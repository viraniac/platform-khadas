#!/bin/bash

source vim4.conf
export NO_GIT_UPDATE=1


cd $FENIX
source config/version

source env/setenv.sh -q -s  KHADAS_BOARD=VIM4 LINUX=5.15 UBOOT=2019.01 DISTRIBUTION=Ubuntu DISTRIB_RELEASE=jammy DISTRIB_RELEASE_VERSION=22.04 DISTRIB_TYPE=server DISTRIB_ARCH=arm64 INSTALL_TYPE=SD-USB COMPRESS_IMAGE=no

make uboot-deb

echo "Backup u-boot .deb file to platform files"
rm $PLATFORM/kernelnew/khadas/debs/${DEVICE}/linux-u-boot*.deb || true
cp build/images/debs/$VERSION/VIM4/linux-u-boot*.deb ${PLATFORM}/kernelnew/khadas/debs/${DEVICE}/

echo "Populate ${PLATFORM} with necessary u-boot files"
[ -e "/tmp/u-boot" ] && rm -r /tmp/u-boot
mkdir /tmp/u-boot
dpkg-deb -R $PLATFORM/kernelnew/khadas/debs/${DEVICE}/linux-u-boot* /tmp/u-boot
mkdir -p $PLATFORM/${DEVICE}/u-boot
cp /tmp/u-boot/usr/lib/u-boot/* $PLATFORM/${DEVICE}/u-boot
rm -r /tmp/u-boot

echo "Done..."
