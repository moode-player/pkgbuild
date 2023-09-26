#!/bin/bash
#########################################################################
#
# Build recipe for shairport-sync
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="shairport-sync_4.3.1-1moode1"

PKG_SOURCE_GIT="https://github.com/mikebrady/shairport-sync.git"
PKG_SOURCE_GIT_TAG="4.3.1"

PKG_DEBIAN="http://deb.debian.org/debian/pool/main/s/shairport-sync/shairport-sync_3.3.8-1.debian.tar.xz"


rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

rm -f debian/patches/github-1314.patch
echo "" > debian/patches/series

rbl_patch $BASE_DIR/debian.rules.patch
rbl_patch $BASE_DIR/debian.control.patch


DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde."

#------------------------------------------------------------
rbl_build
echo "done"
