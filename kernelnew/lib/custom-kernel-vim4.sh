#!/bin/bash

source vim4.conf
export NO_GIT_UPDATE=1

echo "Fetch the pre-compiled Khadas vim4 device tree overlay module .deb file"
if [ ! -e $DT_OVERLAYS ]; then
   git clone http://github.com/numbqq/dt-overlays-debs --depth=1
else
   cd $DT_OVERLAYS
   git pull
   cd ..
fi   
if [ -f $PLATFORM/kernelnew/khadas/debs/vim4/khadas-vim4-linux-5.4-dt-overlays* ];then
   rm $PLATFORM/kernelnew/khadas/debs/vim4/khadas-vim4-linux-5.4-dt-overlays* 
fi   
echo "... and back it up to the platform folder"
cp $DT_OVERLAYS/jammy/arm64/VIM4/khadas-vim4-linux-5.4-dt-overlays_*.deb $PLATFORM/kernelnew/khadas/debs/vim4/

cd $FENIX
source config/version

if [ ! -e build/linux ]; then
   mkdir -p build/linux	
   git clone http://github.com/khadas/linux -b khadas-vims-5.15.y build/linux --depth=1
   git clone http://github.com/khadas/common_drivers -b khadas-vims-5.15.y build/linux/common_drivers --depth=1
   cd build/linux
   echo "Backup original Khadas kernel config"
   cp common_drivers/arch/arm64/configs/kvims_defconfig $PLATFORM/kernelnew/khadas/configs/${DEVICE}/kvims_defconfig-original
   echo "Replace by our own config" 
   cp $PLATFORM/kernelnew/khadas/configs/${DEVICE}/kvims_defconfig common_drivers/arch/arm64/configs/
else
   cd build/linux
   echo "Temporary restore backup khadas config"
   cp $PLATFORM/kernelnew/khadas/configs/${DEVICE}/kvims_defconfig-original common_drivers/arch/arm64/configs/kvims_defconfig
   git pull
   echo "Replace by our own config"
   cp $PLATFORM/kernelnew/khadas/configs/${DEVICE}/kvims_defconfig common_drivers/arch/arm64/configs/
   ls -l common_drivers/arch/arm64/configs/
fi


cd $FENIX
source env/setenv.sh -q -s  KHADAS_BOARD=VIM4 LINUX=5.15 UBOOT=2019.01 DISTRIBUTION=Ubuntu DISTRIB_RELEASE=jammy DISTRIB_RELEASE_VERSION=22.04 DISTRIB_TYPE=server DISTRIB_ARCH=arm64 INSTALL_TYPE=SD-USB COMPRESS_IMAGE=no

make kernel-clean
make kernel-config

echo "Copying kernel config to platform-khadas/kernelnew/khadas/configs/vim4"
make kernel-saveconfig
cp build/linux/common_drivers/arch/arm64/configs/kvims_defconfig $PLATFORM/kernelnew/khadas/configs/${DEVICE}

make kernel-deb

echo "Cleaning previous .deb files from platform-khadas"
rm $PLATFORM/kernelnew/khadas/debs/${DEVICE}/linux-dtb*.deb
rm $PLATFORM/kernelnew/khadas/debs/${DEVICE}/linux-headers*.deb
rm $PLATFORM/kernelnew/khadas/debs/${DEVICE}/linux-image*.deb

echo "Backup new .deb files to platform-khadas"
cp build/images/debs/$VERSION/VIM4/linux-dtb*.deb $PLATFORM/kernelnew/khadas/debs/${DEVICE}/
cp build/images/debs/$VERSION/VIM4/linux-headers*.deb $PLATFORM/kernelnew/khadas/debs/${DEVICE}/
cp build/images/debs/$VERSION/VIM4/linux-image*.deb $PLATFORM/kernelnew/khadas/debs/${DEVICE}/

echo "Done..."
