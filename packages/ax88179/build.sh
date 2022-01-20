#!/bin/bash
#########################################################################
#
# Build recipe for patched in tree ax88179_178a driver with allo usbridge_sig suppport
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
# https://github.com/allocom/USBridgeSig-AX2v0
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

KERNEL_VER=$(rbl_get_current_kernel_version)

PKG="ax88179_$KERNEL_VER-1"

# required for creating a dkms project:
DKMS_MODULE="ax88179_178a/2.0"
SRC_DIR="ax88179_178a-2.0"
ARCHS=( v7l+ v7+ )
MODULE="ax88179_178a.ko"
MODULE_PATH='drivers/net/usb'

# allo source with module replacement:
SOURCE_GIT="https://github.com/allocom/USBridgeSig-AX2v0.git"
SOURCE_GIT_TAG="f0b2a2ef6d61f78631de70cdc985e6c96a203721"

rbl_dkms_prepare intree

#------------------------------------------------------------
# Custom part of the packing

# 1. get the updated drive from Allo:
git clone $SOURCE_GIT
cd USBridgeSig-AX2v0
# no tag available, use commit hash in case new commits are added:
git checkout -b work $SOURCE_GIT_TAG
git archive  --format=tar --output $BUILD_ROOT_DIR/source/$SRC_DIR/USBridgeSig-AX2v0.orig.tar $SOURCE_GIT_TAG

# 2. build the modules with dkms:
#TODO: create arch args automatic
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR/source -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

# 3. pack it with fpm:
# (wanted multiple arch deb which isn't possible with dkms and wanted to prevent install deps of dkms and related)

# create deb postinstall and afterremove scripts based on template:
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/postinstall.sh $BUILD_ROOT_DIR/postinstall.sh
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/afterremove.sh $BUILD_ROOT_DIR/afterremove.sh

# place build modules in the correct file tree for fpm
rbl_dkms_grab_modules

# build the package
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category network \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/allocom/USBridgeSig-AX2v0.git \
-m $DEBEMAIL \
--description "Patched ax88179_178a driver with Allo usbridge_sig suppport." \
--post-install $BUILD_ROOT_DIR/postinstall.sh \
--after-remove  $BUILD_ROOT_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib/=/lib/.


#------------------------------------------------------------
rbl_move_to_dist

cp $BUILD_ROOT_DIR/source/$SRC_DIR/USBridgeSig-AX2v0.orig.tar  $BASE_DIR/dist/source/

echo "done"