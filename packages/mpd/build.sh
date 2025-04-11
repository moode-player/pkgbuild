#!/bin/bash
#########################################################################
#
# Build recipe for mpd debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
# Note:
# During build it can happen that libgtest-dev can't be installed due
# conflict with ashuffle.
# Use sudo apt install -o Dpkg::Options::="--force-overwrite" libgtest-dev
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/m/mpd/mpd_0.24.3-1.dsc"
DEBSUFFIXVERSION=1

rbl_prepare_from_dsc_url $PKG_DSC_URL
#------------------------------------------------------------
# Custom part of the packing

rbl_patch $BASE_DIR/moode_build_options.patch
rbl_patch $BASE_DIR/debian.control.patch

# update the packageversion + debian version part
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Support for selective resample mode"
rbl_patch $BASE_DIR/mpd_0.24.xx_selective_resample_mode.patch
EDITOR=/bin/true dpkg-source --commit . selective_resample_mode.patch

# prevent using the pkgbuild repo for VCS_TAG
export GIT_DIR=`pwd`
#------------------------------------------------------------
rbl_build
echo "done"
