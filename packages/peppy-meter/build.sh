#!/bin/bash
#########################################################################
#
# Build recipe for peppy-meter debian package
#
# (C) bitkeeper 2025 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh
PKG="peppy-meter_2025.6.3-1moode1"

PKG_SOURCE_GIT="https://github.com/project-owner/PeppyMeter.git"
PKG_SOURCE_GIT_TAG="master"

# For packign fpm is used, which is created with Ruby
rbl_check_fpm

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

# ------------------------------------------------------------
# Custom part of the packing

echo "build root : $BUILD_ROOT_DIR"

rbl_patch $BASE_DIR/configpath.patch
# Create the package
# setup a directory structure for the files which should end up in the deb file:
rm -rf ../package
mkdir -p ../package/etc/peppymeter
mkdir -p ../package/opt/peppymeter

cp config.txt ../package/etc/peppymeter/
cp -r * ../package/opt/peppymeter
rm -f ../package/opt/peppymeter/config.txt

# build a deb files based on the directory structure
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
-a all \
--deb-priority optional \
--url https://github.com/project-owner/PeppyMeter \
-m moodeaudio.org \
--description 'PeppyMeter is a software VU Meter written in Python.' \
--depends python3-pygame \
--depends peppy-alsa \
--deb-no-default-config-files \
--deb-systemd ../../peppymeter.service \
../package/opt/=/opt/. \
../package/etc/=/etc/.


if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi

#------------------------------------------------------------
rbl_move_to_dist

echo "done"
