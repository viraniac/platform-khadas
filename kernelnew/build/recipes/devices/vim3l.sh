#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM3L device.
# Note: these images are using vendor kernel & u-boot, generated with the
#       Khadas Fenix build system

DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="Khadas VIM3L"
DEVICE="vim3l"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="khadas"
DEVICEBASE="vims-5.15"
# tarball from DEVICEFAMILY repo to use
#DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"
DEVICEREPO="https://github.com/viraniac/platform-${DEVICEFAMILY}.git"

UBOOTBIN="u-boot.bin.sd.bin"
### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=yes
KIOSKBROWSER=vivaldi

## Partition info
BOOT_START=16
BOOT_END=256
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
IMAGE_END=3800
INIT_TYPE="initv3"
PLYMOUTH_THEME="volumio-player"

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437" "fuse")

# Packages that will be installed
PACKAGES=("lirc" "fbset" )

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -LR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -L "${PLTDIR}/${DEVICEBASE}/boot/extlinux/extlinux.conf.${DEVICE}" "${ROOTFSMNT}"/boot/extlinux/extlinux.conf
  cp -L "${PLTDIR}/${DEVICEBASE}/boot/uEnv.txt.${DEVICE}" "${ROOTFSMNT}"/boot/uEnv.txt
  rm "${ROOTFSMNT}"/boot/extlinux/extlinux.conf.vim*
  rm "${ROOTFSMNT}"/boot/uEnv.txt.vim*

  sed -i "s/hwdevice=/hwdevice=${DEVICE}/" "${ROOTFSMNT}"/boot/uEnv.txt

  cp -R "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"

  log "Adding broadcom wlan firmware for vims onboard wlan"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/wlan-firmware/brcm/" "${ROOTFSMNT}/lib/firmware"

  log "Adding Meson video firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/${DEVICE}"/* "${ROOTFSMNT}/lib/firmware/"

  log "Adding Wifi & Bluetooth firmware and helpers NOT COMPLETED, TBS"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/hciattach-armhf" "${ROOTFSMNT}/usr/local/bin/hciattach"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/brcm_patchram_plus-armhf" "${ROOTFSMNT}/usr/local/bin/brcm_patchram_plus"

  log "Adding services"
  mkdir -p "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/bluetooth-khadas.service" "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

  log "Load modules, specific for vims, to /etc/modules" 
  cp -R "${PLTDIR}/${DEVICEBASE}/etc" "${ROOTFSMNT}/"
  cp "${PLTDIR}/${DEVICEBASE}/etc/initramfs-tools/modules.${DEVICE}" "${ROOTFSMNT}/etc/initramfs-tools/modules"
  cp "${PLTDIR}/${DEVICEBASE}/etc/modprobe.d.${DEVICE}"/* "${ROOTFSMNT}/etc/modprobe.d/"
  cp "${PLTDIR}/${DEVICEBASE}/etc/modules.${DEVICE}" "${ROOTFSMNT}/etc/modules"

  rm "${ROOTFSMNT}"/etc/initramfs-tools/modules.vim*
  rm -rf "${ROOTFSMNT}"/etc/modprobe.d.vim*
  rm "${ROOTFSMNT}"/etc/modules.vim*

  log "Adding usr/local/bin & usr/bin files"
  cp -R "${PLTDIR}/${DEVICEBASE}/usr" "${ROOTFSMNT}"

  log "Copying volumio configuration"
  cp -R "${PLTDIR}/${DEVICEBASE}/volumio" "${ROOTFSMNT}/"
}

write_device_bootloader() {

  log "Running write_device_bootloader" "ext"
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/${DEVICE}/${UBOOTBIN}" of="${LOOP_DEV}" bs=444 count=1 conv=fsync,notrunc >/dev/null 2>&1
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/${DEVICE}/${UBOOTBIN}" of="${LOOP_DEV}" bs=512 skip=1 seek=1 conv=fsync,notrunc >/dev/null 2>&1

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

### Chroot tweaks
# Will be run in chroot (before other things)
device_chroot_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  sed -i "s/#imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/uEnv.txt
  sed -i "s/#bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/uEnv.txt
  sed -i "s/#datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/uEnv.txt

#  cat <<-EOF >>/boot/dtb/amlogic/kvim3l.dtb.overlay.env
#fdt_overlays=i2s spdifout uart_c renamesound
#EOF
  
  # Do not use i2s for the time being (needs to be checked)
  cat <<-EOF >>/boot/dtb/amlogic/kvim3l.dtb.overlay.env
fdt_overlays=spdifout uart3 renamesound panfrost
EOF

  log "Fixing armv8 deprecated instruction emulation, allow dmesg"
  cat <<-EOF >>/etc/sysctl.conf
#Fixing armv8 deprecated instruction emulation with armv7 rootfs
abi.cp15_barrier=2
#Allow dmesg for non.sudo users
kernel.dmesg_restrict=0
EOF

# Bluez looks for firmware in /etc/firmware/, enable bluetooth stack
  ln -sf /lib/firmware /etc/firmware
  ln -s /lib/systemd/system/bluetooth-khadas.service /etc/systemd/system/multi-user.target.wants/bluetooth-khadas.service

# Patches used by hciattach
  ln -fs /lib/firmware/brcm/BCM43438A1.hcd /lib/firmware/brcm/BCM43430A1.hcd # AP6212
  ln -fs /lib/firmware/brcm/BCM4356A2.hcd /lib/firmware/brcm/BCM4354A2.hcd # AP6356S

  ln -s /lib/systemd/system/fan.service /etc/systemd/system/multi-user.target.wants/fan.service

  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG image" "info"
    sed -i "s/quiet loglevel=0 splash/loglevel=8 nosplash break= use_kmsg=yes/" /boot/uEnv.txt
  else
    log "Configuring default kernel parameters" "info"
    if [[ -n "${PLYMOUTH_THEME}" ]]; then
      log "Adding splash kernel parameters" "info"
      sed -i "s/loglevel=0 splash/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/uEnv.txt
    else
      log "No splash screen, just quiet" "info"
      sed -i "s/loglevel=0 splash/loglevel=0 nosplash/" /boot/uEnv.txt
    fi
  fi
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  # log "Running device_chroot_tweaks_post" "ext"
  :
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  log "Running device_image_tweaks_post" "ext"
  log "Creating uInitrd from 'volumio.initrd'" "info"
  if [[ -f "${ROOTFSMNT}"/boot/volumio.initrd ]]; then
    mkimage -v -A "${UINITRD_ARCH}" -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${ROOTFSMNT}"/boot/volumio.initrd "${ROOTFSMNT}"/boot/uInitrd
    #rm "${ROOTFSMNT}"/boot/volumio.initrd
  fi
  if [[ -f "${ROOTFSMNT}"/boot/boot.cmd ]]; then
    log "Creating boot.scr"
    mkimage -A arm -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi
}

