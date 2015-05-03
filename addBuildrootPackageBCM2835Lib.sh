#!/bin/bash

echo "do not run this howto as script!"
exit 0


# go into buildroot dir
cd BUILDROOT_DIR

# simple example for buildroot package
cat packages/tslib/tslib.mk


# add new target 
## bcm2835 lib for pi
## needed from cberry display
mkdir -p package/bcm2835lib/
cat > package/bcm2835lib/bcm2835lib.mk << 'EOF'
###########################################################
#
# lib bcm2835
#
###########################################################

BCM2835LIB_VERSION = 1.44
BCM2835LIB_SOURCE = bcm2835-$(BCM2835LIB_VERSION).tar.gz
BCM2835LIB_SITE = www.airspayce.com/mikem/bcm2835/
BCM2835LIB_INSTALL_TARGET = YES
BCM2835LIB_INSTALL_STAGING = YES

$(eval $(autotools-package))
EOF

cat > package/bcm2835lib/Config.in << 'EOF'
config BR2_PACKAGE_BCM2835LIB
	bool "BCM2835LIB"
	help
	  Library for raspberry pi bcm2835
EOF

sed -i 's,menu "Hardware handling",menu "Hardware handling"\n	source "package/bcm2835lib/Config.in"\n,' package/Config.in

# now select new packages with
make menuconfig
# build packa
make
