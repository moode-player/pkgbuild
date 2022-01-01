#!/bin/bash
#########################################################################
#
# Build recipe for patched in tree pcm1794a driver with 384kHz support
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="pcm1794a_5.10.63-1"

DKMS_MODULE="pcm1794a/0.2"
SRC_DIR="pcm1794a-0.2"
KERNEL_VER=`uname -r | sed -r "s/([0-9.]*)[-].*/\1/"`

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir
_rbl_cleanup_previous_build
_rbl_change_to_build_root

rbl_check_build_dep dkms
rbl_check_build_dep rpi-source
# this will download the kernel source if needed and set the ENV KERNEL_SOURCE_ARCHIVE to the location of the tarball
rbl_get_kernel_source

#------------------------------------------------------------
# Custom part of the packing

# 1. setup project files required for dkms:
mkdir -p $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/build.sh $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/dkms-patchmodule.sh $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/dkms.conf $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR


# 2. build the modules with dkms:
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR/source -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# build the packing:
# package for single arch
# dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7+ $DKMS_MODULE
# package for single arch
# dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ $DKMS_MODULE
# rebuildable tarball which can be installed with with dkms
# dkms mktarball --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE
# binaries tarball with prebuild modules which can be installed with with dkms
# dkms mktarball --dkmstree $BUILD_ROOT_DIR --binaries-only -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE


# 3. packed it with fpm:
# (wanted multiple arch deb which isn't possible with dkms and wanted to prevent install deps of dkms and related)
ARCHS=( v7l+ v7+ )

MODULE=snd-soc-pcm1794a.ko
for i in "${ARCHS[@]}"
do
    mkdir -p $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
    install -m644 $BUILD_ROOT_DIR/$DKMS_MODULE/$KERNEL_VER-$i/armv7l/module/$MODULE $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
done

fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/moode-player/pkgbuild \
-m $DEBEMAIL \
--description "Patched pcm1794a driver with 384kHz support." \
--post-install $BASE_DIR/postinstall.sh \
--after-remove  $BASE_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib=/lib/.


#------------------------------------------------------------

echo "done"