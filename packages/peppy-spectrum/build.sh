#!/bin/bash
#########################################################################
#
# Build recipe for peppy-spectrum debian package
#
# (C) bitkeeper 2025 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh
PKG="peppy-spectrum_2024.5.26-1moode1"

PKG_SOURCE_GIT="https://github.com/project-owner/PeppySpectrum.git"
PKG_SOURCE_GIT_TAG="main"

# For packign fpm is used, which is created with Ruby
rbl_check_fpm

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

# ------------------------------------------------------------
# Custom part of the packing

echo "build root : $BUILD_ROOT_DIR"

rbl_patch $BASE_DIR/configpath.patch
# rbl_patch $BASE_DIR/spectrum.patch
cp $BASE_DIR/spectrum.py .
# Create the package
# setup a directory structure for the files which should end up in the deb file:
rm -rf ../package
mkdir -p ../package/etc/peppyspectrum
mkdir -p ../package/opt/peppyspectrum
 #mkdir -p ../package/etc/systemd/system

cp config.txt ../package/etc/peppyspectrum/
cp -r * ../package/opt/peppyspectrum
rm -f ../package/opt/peppyspectrum/config.txt

# build a deb files based on the directory structure
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
-a all \
--deb-priority optional \
--url https://github.com/project-owner/PeppySpectrum \
-m moodeaudio.org \
--description 'PeppySpectrum is a software Spectrum Analyzer written in Python.' \
--depends python3-pil \
--depends peppy-alsa \
--deb-no-default-config-files \
--deb-systemd ../../peppyspectrum.service \
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
