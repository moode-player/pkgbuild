#!/bin/bash
#########################################################################
#
# Build recipe for rpi-source debian package.
# Fixes python3 compat for used functionality.
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG="rpi-source_0.1-1moode1"

PKG_SOURCE_GIT="https://github.com/RPi-Distro/rpi-source.git"
# no tags availabel lets use an commit hash for checkout
PKG_SOURCE_GIT_TAG="e2908c936e627fe6ef1fb375c9dc8b56e2751d59"

rbl_check_build_dep help2man
rbl_prepare_from_git_with_deb_repo


#------------------------------------------------------------
# Custom part of the packing

# rpi-source isn't working wiht python3
# found some patch, but the patchis ill created; need to apply it a reverse
# https://forums.raspberrypi.com/viewtopic.php?t=324870
patch -R rpi-source < $BASE_DIR/rpi_source_p3.patch
# But even then it doesn't work need additional patches
patch rpi-source < $BASE_DIR/py3_string.patch

patch debian/control < $BASE_DIR/debian.control.fixpy3.patch
echo "10" > debian/compat

EDITOR=/bin/true dpkg-source --commit . rpi_source_p3.patch

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

dpkg-buildpackage -b -uc -us -d
cd ..
#------------------------------------------------------------
# rbl_build
rbl_move_to_dist
echo "done"

