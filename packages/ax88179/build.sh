#!/bin/bash
#########################################################################
#
# Build recipe for patched in tree ax88179_178a driver with allo usbridge_sig suppport
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
# https://github.com/allocom/USBridgeSig/tree/master/ethernet
# https://raw.githubusercontent.com/allocom/USBridgeSig/master/ethernet/ax88179.tar
# http://3.230.113.73:9011/Allocom/USBridgeSig/
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

KERNEL_VER=`uname -r | sed -r "s/([0-9.]*)[-].*/\1/"`

PKG="ax88179_$KERNEL_VER-1"

DKMS_MODULE="ax88179_178a/2.0"
SRC_DIR="ax88179_178a-2.0"
ARCHS=( v7l+ v7+ )
MODULE="ax88179_178a.ko"
MODULE_PATH='drivers/net/usb'

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

cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms-patchmodule.intree.sh $BUILD_ROOT_DIR/source/$SRC_DIR/dkms-patchmodule.sh
# cp $BASE_DIR/dkms-patchmodule.sh $BUILD_ROOT_DIR/source/$SRC_DIR/
chmod +x $BUILD_ROOT_DIR/source/$SRC_DIR/*.sh
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms.conf $BUILD_ROOT_DIR/source/$SRC_DIR/dkms.conf
cp $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR/
# cp $BASE_DIR/ax88179.tar $BUILD_ROOT_DIR/source/$SRC_DIR/
# tar -cf $BASE_DIR/ax88179_new.tar $BASE_DIR/ax88179*.c $BASE_DIR/ax88179*.h
cp $BASE_DIR/*.tar $BUILD_ROOT_DIR/source/$SRC_DIR/

# 2. build the modules with dkms:
#TODO: create arch args automatic
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
--category network \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/moode-player/pkgbuild \
-m $DEBEMAIL \
--description "Patched ax88179_178a driver with Allo usbridge_sig suppport." \
--post-install $BUILD_ROOT_DIR/postinstall.sh \
--after-remove  $BUILD_ROOT_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib/=/lib/.


#------------------------------------------------------------
rbl_move_to_dist

echo "done"