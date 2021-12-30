#!/bin/bash
#########################################################################
#
# Build recipe for patched pcm1794a driver with 384kHz support
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="pcm1794a_5.10.63-1"

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir
#_rbl_cleanup_previous_build
_rbl_change_to_build_root

# BUILD_ROOT="/home/pi/moode.dev/bullseye/mooderepo/packages/pcm1794"
# BUILD_ROOT=`realpath .`
DKMS_MODULE="pcm1794a/0.2"
KERNEL_VER="5.10.63"


rbl_check_build_dep dkms
rbl_check_build_dep rpi-source
# this will download the kernel source if needed and set the ENV KERNEL_SOURCE_ARCHIVE to the location of the tarball
rbl_get_kernel_source

#------------------------------------------------------------
# Custom part of the packing

SRC_DIR="pcm1794a-0.2"
# setup files required for dkms:
mkdir -p $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/build.sh $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/dkms-patchmodule.sh $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/dkms.conf $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR


# build the modules with dkms:
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR/source -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# build the packing:
#dkms mkdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7+ $DKMS_MODULE

#dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7+ $DKMS_MODULE
#dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ $DKMS_MODULE
#dkms mktarball --dkmstree $BUILD_ROOT_DIR --binaries-only -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE
# dkms ldtarball --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

#mkdir -p BUILD_ROOT_DIR/pcm1794a/0.2/$KERNEL_VER-v7l+

# MODULE=snd-soc-pcm1794a.ko
# array=( v7l+ v7+ )
# for i in "${array[@]}"
# do
#     mkdir -p $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
#     install -m644 $BUILD_ROOT_DIR/pcm1794a/0.2/$KERNEL_VER-$i/armv7l/module/$MODULE $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
# done

# fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
# --license GPLv3 \
# --category sound \
# -S moode \
# --iteration $DEBVER$DEBLOC \
# --deb-priority optional \
# --url https://github.com/moode-player/pkgbuild \
# -m moodeaudio.org \
# --description 'Patched pcm1794a driver for 384kHz support.' \
# --depends python3-camilladsp \
# --pre-install $BASE_DIR/deb_preinstall.sh \
# --before-remove $BASE_DIR/deb_beforeremove.sh \
# package/opt/camillagui/.=/opt/camillagui \
# package/etc/=/etc/.


#------------------------------------------------------------

echo "done"