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

KERNEL_VER=$(rbl_get_current_kernel_version)

PKG="pcm1794a_0.1-1"

# required for creating a dkms project:
DKMS_MODULE="pcm1794a/0.1"
SRC_DIR="pcm1794a-0.1"
ARCHS=( v7l+ v7+ )
MODULE="snd-soc-pcm1794a.ko"
MODULE_PATH='sound/soc/codecs'

rbl_dkms_prepare intree

#------------------------------------------------------------
# Custom part of the packing


# 1. build the modules with dkms:
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR/source -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# examples of other dkms outputs:
# build the packing:
# package for single arch
dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7+ $DKMS_MODULE
# package for single arch
# dkms mkbmdeb --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ $DKMS_MODULE
# rebuildable tarball which can be installed with with dkms
# dkms mktarball --dkmstree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE
# binaries tarball with prebuild modules which can be installed with with dkms
# dkms mktarball --dkmstree $BUILD_ROOT_DIR --binaries-only -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# 2. packed it with fpm:
# (wanted multiple arch deb which isn't possible with dkms and wanted to prevent install deps of dkms and related)

# create deb postinstall and afterremove scripts based on template:
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/postinstall.sh $BUILD_ROOT_DIR/postinstall.sh
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/afterremove.sh $BUILD_ROOT_DIR/afterremove.sh

# place build modules in the correct file tree
rbl_dkms_grab_modules

# build the package
fpm -s dir -t deb -n $PKGNAME-${KERNEL_VER} -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/moode-player/pkgbuild \
-m $DEBEMAIL \
--description "Patched pcm1794a driver with 384kHz support." \
--post-install $BUILD_ROOT_DIR/postinstall.sh \
--after-remove  $BUILD_ROOT_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib/=/lib/.


#------------------------------------------------------------
rbl_move_to_dist

echo "done"