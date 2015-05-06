#!/bin/sh

echo "do not run this howto as script!"
exit 0



BUILDROOT_VERSION=2015.02
BUILDROOT_NAME=buildroot-${BUILDROOT_VERSION}
BUILDROOT_FOLDER=build/${BUILDROOT_NAME}/

mkdir -p build download output mnt


# download buildroot
wget http://buildroot.net/downloads/${BUILDROOT_NAME}.tar.bz2 -P download/
tar xvfj download/${BUILDROOT_NAME}.tar.bz2 -C $(dirname $BUILDROOT_FOLDER)


# configure
make raspberrypi_defconfig -C $BUILDROOT_FOLDER
make menuconfig            -C $BUILDROOT_FOLDER
make linux-menuconfig      -C $BUILDROOT_FOLDER


# save own config
cp ${BUILDROOT_FOLDER}/.config my_raspberrypi_defconfig 


# run buildroot
make -C $BUILDROOT_FOLDER


# special buildroot folder
ls -l $BUILDROOT_FOLDER/dl              # downloades sources as tarballs, git and svn repos too
ls -l $BUILDROOT_FOLDER/output/build    # extracted sources
ls -l $BUILDROOT_FOLDER/output/host     # tools for host, compiler, lzop ....
ls -l $BUILDROOT_FOLDER/output/images   # kernel, bootloader, firmware, devicetree, ramdisk ....
ls -l $BUILDROOT_FOLDER/output/staging  # cross comiled libs for target
ls -l $BUILDROOT_FOLDER/output/target   # rfs for target


################################################
# some buildroot cmds
## rebuild kernel
## $ make linux-rebuild -C $BUILDROOT_FOLDER
## clear all in output/ folder
## $ make clean         -C $BUILDROOT_FOLDER
## clear all in output/ and dl/ folder
## $ make distclean     -C $BUILDROOT_FOLDER
#################################################


# configure network
cat > ${BUILDROOT_FOLDER}/output/target/etc/network/interfaces << 'EOF'
# Configure Loopback
auto lo
iface lo inet loopback
# Configure eth0 with static IP
auto eth0
iface eth0 inet static
        address 192.168.1.10
        network 192.168.1.0
        netmask 255.255.255.0 

# Configure eth0 with dhcp IP
# auto eth0
# iface eth0 inet dhcp 
EOF


# mount boot partition
echo '/dev/mmcblk0p1 /boot vfat defaults 0 0' >> ${BUILDROOT_FOLDER}/output/target/etc/fstab


# enable root shell on serial console
echo '/dev/ttyAMA0::respawn:/sbin/getty 115200 /dev/ttyAMA0 -n -l /sbin/sulogin' >> ${BUILDROOT_FOLDER}/output/target/etc/inittab


# rebuild rootfs.tar with modifications
make -C $BUILDROOT_FOLDER


# example usage of buildroot cross compiler
echo -en "#include <stdio.h>\nint main(){printf(\"Hello World\");}" | ${BUILDROOT_FOLDER}/output/host/usr/bin/arm-linux-gcc -o test.bin -xc -


# create inital image file
dd if=/dev/zero of=output/rpi.img bs=1M count=60


# create partitions
fdisk output/rpi.img << 'EOF'
n



+20M
t
c
n




t
2
83
p
w
EOF


# get partition from image to loopback
kpartx -as output/rpi.img


# write file systems
mkfs.vfat /dev/mapper/loop0p1
mkfs.ext2 /dev/mapper/loop0p2


# mount partitions
mkdir -p mnt/boot mnt/rfs
mount /dev/mapper/loop0p1 mnt/boot
mount /dev/mapper/loop0p2 mnt/rfs


# copy kernel and firmware to boot partition
cp ${BUILDROOT_DIR}/output/images/zImage mnt/boot/
cp ${BUILDROOT_DIR}/output/images/rpi-firmware/* mnt/boot/


# set kernel cmdline
## raspbian
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext2 elevator=deadline rootwait" > mnt/boot/cmdline.txt
## flash boot
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 elevator=deadline rootwait root=/dev/mmcblk0p2 rootfstype=ext4" > mnt/boot/cmdline.txt
## or nfsboot:
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 elevator=deadline rootwait ip=::::rpi::dhcp root=/dev/nfs nfsroot=192.168.1.1:/mnt/shares/rpifs/nfsroot,tcp,rsize=32768,wsize=32768" > mnt/boot/cmdline.txt
## speed up boot time ( ~0.5s) by adding "quiet" to cmdline.txt


# extract rfs
tar xvf ${BUILDROOT_FOLDER}/image/rootfs.tar -C mnt/rfs


# free image
sync
umount mnt/boot
umount mnt/rfs
kpartx -d output/rpi.img


# flash image to sdcard
dd if=output/rpi.img of=/dev/sdX

