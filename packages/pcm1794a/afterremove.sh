#!/bin/bash

KERNEL_VER="5.10.63"
ARCHS=( v7l+ v7+ )
PACKAGE_NAME="pcm1794a"
MODULE_PATH_ORG="sound/soc/codecs"

for ARCH in "${ARCHS[@]}"
do
    # restore backup original kernel module
    if [ -f /var/lib/dkms/$MODULE/original_module/$KERNEL_VER-$ARCH/$MODULE ]
    then
        mv /var/lib/dkms/$PACKAGE_NAME/original_module/$KERNEL_VER-$ARCH/$MODULE /lib/modules/$KERNEL_VER-$ARCH/kernel/$MODULE_PATH_ORG
    fi

    depmod $KERNEL_VER-$ARCH
done
