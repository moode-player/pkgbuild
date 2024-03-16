#!/bin/bash
#########################################################################
#
# Build recipe for Allo usbridge_sig Wifi.
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

# required for creating a dkms project:
ARCHS=( rpi-v8 rpi-2712 )
MODULE="88XXau.ko"

rbl_prepare_clone_from_git $PKG_SOURCE_GIT
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz
rbl_dkms_prepare outtree

DKMS_MODULE="$PKGNAME/$PKGVERSION"

#------------------------------------------------------------
# Custom part of the packing

# 1. build the modules with dkms:

# use kernel headers (stock kernel) or source (rpi-update/custom kernel)
if [ $MODULE_BUILD_USE_SOURCE -eq 1 ]
then
  echo 'PRE_BUILD="dkms-patchmodule.sh %MODULE_PATH%"' >> $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/dkms.conf
  cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms-patchmodule.outtree.sh $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/dkms-patchmodule.sh
  cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/prepkernel.sh $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/
  chmod a+x $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/prepkernel.sh
fi


dkms build --dkmstree $BUILD_ROOT_DIR --sourcetree $BUILD_ROOT_DIR $DKMS_KERNEL_STRING $DKMS_MODULE

if [ $? -gt 0 ]
then
  echo "${RED}Error: problem during dkms build${NORMAL}"
  exit 1
fi

# 2. packed it with fpm:
# (wanted multiple arch deb which isn't possible with dkms and wanted to prevent install deps of dkms and related)

# create deb postinstall and afterremove scripts based on template:
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/postinstall.sh $BUILD_ROOT_DIR/postinstall.sh
rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/afterremove.sh $BUILD_ROOT_DIR/afterremove.sh

# place build modules in the correct file tree
rbl_dkms_grab_modules

# build the package
fpm -s dir -t deb -n $PKGNAME-${KERNEL_VERSION_PKG_SMALL} -v $PKGVERSION \
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