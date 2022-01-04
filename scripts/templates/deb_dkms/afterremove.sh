#!/bin/bash

KERNEL_VER=%KERNEL_VER%
ARCHS=( %ARCHS% )
PACKAGE_NAME="%PKG_NAME%"
MODULE_PATH_ORG="%MODULE_PATH%"
MODULE=%MODULE%

for ARCH in "${ARCHS[@]}"
do
    # restore backup original kernel module
    if [ -f /var/lib/dkms/$MODULE/original_module/$KERNEL_VER-$ARCH/$MODULE ]
    then
        mv /var/lib/dkms/$PACKAGE_NAME/original_module/$KERNEL_VER-$ARCH/$MODULE /lib/modules/$KERNEL_VER-$ARCH/kernel/$MODULE_PATH_ORG
    fi

    depmod $KERNEL_VER-$ARCH
done
