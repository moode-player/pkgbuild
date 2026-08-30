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

PKG="shairport-sync_5.2.3-1moode1"

PKG_SOURCE_GIT="https://github.com/mikebrady/shairport-sync.git"
PKG_SOURCE_GIT_TAG="5.2.3"

PKG_DEBIAN="http://deb.debian.org/debian/pool/main/s/shairport-sync/shairport-sync_5.1~dev~git20260518-1.debian.tar.xz"

rbl_check_build_dep libplist-utils
rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

rbl_patch $BASE_DIR/debian.rules.patch

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde."

#------------------------------------------------------------
rbl_build
echo "done"
