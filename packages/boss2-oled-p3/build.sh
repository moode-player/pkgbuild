#!/bin/bash
#########################################################################
#
# Build recipe for allo boss2 oled python code
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="boss2-oled-p3_1.0.0-1moode2"

PKG_SOURCE_GIT="https://github.com/allocom/allo_boss2_oled_p3.git"
PKG_SOURCE_GIT_TAG="main"

rbl_check_fpm
rbl_prepare_clone_from_git $PKG_SOURCE_GIT
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz


# ------------------------------------------------------------
# Custom part of the packing


# ---------------------------------------------------------------
# Packing
# ---------------------------------------------------------------
cd $BUILD_ROOT_DIR

# build a deb files based on the directory structure
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category misc \
-S moode \
--iteration $DEBVER$DEBLOC \
-a all \
--deb-priority optional \
--url https://github.com/allocom/allo_boss2_oled_p3 \
-m moodeaudio.org \
--description 'Allo BOSS2 OLED driver that runs on Python 3.x .' \
--depends python3-rpi.lgpio \
--depends python3-smbus \
--depends python3-pil \
--deb-systemd $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/boss2_oled_p3/boss2oled.service \
$BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/boss2_oled_p3/.=/opt/boss2_oled_p3

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi



#------------------------------------------------------------
rbl_move_to_dist

echo "done"
