#!/bin/bash
#########################################################################
#
# Build recipe for patched in tree aloop driver with 384kHz support
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="aloop_5.10.63-1"

DKMS_MODULE="aloop/0.2"
SRC_DIR="aloop-0.2"
KERNEL_VER=`uname -r | sed -r "s/([0-9.]*)[-].*/\1/"`
ARCHS=( v7l+ v7+ )
MODULE="snd-aloop.ko"
MODULE_PATH='sound/drivers'

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
echo $BUILD_ROOT_DIR/source/$SRC_DIR
mkdir -p $BUILD_ROOT_DIR/source/$SRC_DIR

# cp $BASE_DIR/dkms-patchmodule.sh $BASE_DIR/dkms.conf $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR
cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms-patchmodule.intree.sh $BUILD_ROOT_DIR/source/$SRC_DIR/dkms-patchmodule.sh
chmod +x $BUILD_ROOT_DIR/source/$SRC_DIR/*.sh
cp $BASE_DIR/dkms.conf $BUILD_ROOT_DIR/source/$SRC_DIR
cp $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR

# 2. build the modules with dkms:
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR/source -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# 3. packed it with fpm:
# (wanted multiple arch deb which isn't possible with dkms and wanted to prevent install deps of dkms and related)

# create deb postinstall and afterremove scripts based on template:
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/postinstall.sh $BUILD_ROOT_DIR/postinstall.sh
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/afterremove.sh $BUILD_ROOT_DIR/afterremove.sh

# place build modules in the correct file tree
rbl_dkms_grab_modules

# build the package
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/moode-player/pkgbuild \
-m $DEBEMAIL \
--description "Patched aloop driver with 384kHz support." \
--post-install $BUILD_ROOT_DIR/postinstall.sh \
--after-remove  $BUILD_ROOT_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib/=/lib/.


#------------------------------------------------------------
rbl_move_to_dist

echo "done"