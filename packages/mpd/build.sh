#!/bin/bash
#########################################################################
#
# Build recipe for mpd debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/m/mpd/mpd_0.23.14-1.dsc"
DEBSUFFIXVERSION=1

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

rbl_patch $BASE_DIR/mpd_0.23.xx_selective_resample_mode.patch
EDITOR=/bin/true dpkg-source --commit . selective_resample_mode.patch

rbl_patch $BASE_DIR/moode_build_options.patch
rbl_patch $BASE_DIR/debian.control.patch

# update the packageversion + debian version part
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -v $FULL_VERSION "Support for selective resample mode"

# prevent using the pkgbuild repo for VCS_TAG
export GIT_DIR=`pwd`
#------------------------------------------------------------
rbl_build
echo "done"
