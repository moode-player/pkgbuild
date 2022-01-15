#!/bin/bash
#########################################################################
#
# Build recipe for patched in tree aloop driver with 384kHz support
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
# cloned git project already contains dkms project files
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

KERNEL_VER=$(rbl_get_current_kernel_version)

PKG="rtl88xxau_5.6.4.2-1"

PKG_SOURCE_GIT="https://github.com/aircrack-ng/rtl8812au.git"
PKG_SOURCE_GIT_TAG="v5.6.4.2"

rbl_prepare_clone_from_git $PKG_SOURCE_GIT
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# required for creating a dkms project:
DKMS_MODULE="$PKGNAME/$PKGVERSION"
ARCHS=( v7l+ v7+ )
MODULE="88XXau.ko"
# MODULE_PATH='net/wireless/realtek/rtlwifi'

# rbl_dkms_prepare intree
cd $BUILD_ROOT_DIR

echo $BUILD_ROOT_DIR
echo $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION

#------------------------------------------------------------
# Custom part of the packing
cd ..

# 1. build the modules with dkms:
dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR -k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+ $DKMS_MODULE

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
--category misc \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/aircrack-ng/rtl8812au \
-m $DEBEMAIL \
--description "RTL8812AU/21AU Wireless drivers" \
--post-install $BUILD_ROOT_DIR/postinstall.sh \
--after-remove  $BUILD_ROOT_DIR/afterremove.sh  \
$BUILD_ROOT_DIR/lib/=/lib/.


#------------------------------------------------------------
rbl_move_to_dist

echo "done"