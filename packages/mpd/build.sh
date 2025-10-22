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

PKG="mpd_0.24.6-1moode1"
PKG_SOURCE_GIT="https://github.com/MusicPlayerDaemon/MPD.git"
PKG_SOURCE_GIT_TAG="v0.24.6"

PKG_DEBIAN="http://deb.debian.org/debian/pool/main/m/mpd/mpd_0.24.4-1.debian.tar.xz"
rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of same or older version
rbl_grab_debian_archive $PKG_DEBIAN

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
