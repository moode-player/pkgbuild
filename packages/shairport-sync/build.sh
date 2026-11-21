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

# NOTE: When bumping the version don't push the commit until after moode
# and in-place update are released.
PKG="shairport-sync_5.6.2-3moode1"

PKG_DSC_URL=https://deb.debian.org/debian/pool/main/s/shairport-sync/shairport-sync_5.6.2-3.dsc

rbl_check_build_dep libplist-utils
#rbl_prepare_from_git_with_deb_repo
rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

rbl_patch $BASE_DIR/control-debhelper.patch
rbl_patch $BASE_DIR/debian.rules.patch

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde."

#------------------------------------------------------------
rbl_build
echo "done"
