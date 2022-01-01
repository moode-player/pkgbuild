#!/bin/bash

KERNEL_VER="5.10.63"
ARCHS=( v7l+ v7+ )
PACKAGE_NAME="pcm1794a"
MODULE_PATH_ORG="sound/soc/codecs"
MODULE=snd-soc-pcm1794a.ko

for ARCH in "${ARCHS[@]}"
do
    # backup original kernel module
    if [ -f /lib/modules/$KERNEL_VER-$ARCH/kernel/sound/soc/codecs/$MODULE ]
    then
        mkdir -p /var/lib/dkms/pcm1794a/original_module/$KERNEL_VER-$ARCH
        mv /lib/modules/$KERNEL_VER-$ARCH/kernel/$MODULE_PATH_ORG/$MODULE /var/lib/dkms/$PACKAGE_NAME/original_module/$KERNEL_VER-$ARCH
    fi

    depmod $KERNEL_VER-$ARCH
done
