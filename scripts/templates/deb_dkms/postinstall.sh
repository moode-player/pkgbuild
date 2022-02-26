#!/bin/bash
#########################################################################
#
# Scripts for building moode packages
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

KERNEL_VER=%KERNEL_VER%
ARCHS=( %ARCHS% )
PACKAGE_NAME="%PKG_NAME%"
MODULE_PATH_ORG="%MODULE_PATH%"
MODULE=%MODULE%

for ARCH in "${ARCHS[@]}"
do
    # backup original kernel module
    if [ -f /lib/modules/$KERNEL_VER-$ARCH/kernel/$MODULE_PATH_ORG/$MODULE ]
    then
        mkdir -p /var/lib/dkms/$PACKAGE_NAME/original_module/$KERNEL_VER-$ARCH
        mv /lib/modules/$KERNEL_VER-$ARCH/kernel/$MODULE_PATH_ORG/$MODULE /var/lib/dkms/$PACKAGE_NAME/original_module/$KERNEL_VER-$ARCH
    fi

    depmod $KERNEL_VER-$ARCH
done
