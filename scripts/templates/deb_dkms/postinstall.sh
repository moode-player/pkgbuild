#!/bin/bash

KERNEL_VER=%KERNEL_VER%
ARCHS=( %ARCHS% )
PACKAGE_NAME="%PKG_NAME%"
MODULE_PATH_ORG="%MODULE_PATH%"
MODULE=%MODULE%

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
