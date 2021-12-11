#!/bin/bash
#########################################################################
#
# Build recipe for trx debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="trx_0.6-1moode1"

PKG_SOURCE_GIT="https://github.com/bitkeeper/trx.git"
PKG_SOURCE_GIT_TAG="0.6"

PKG_DEBIAN="http://deb.debian.org/debian/pool/main/t/trx/trx_0.5-3.debian.tar.xz"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"

#------------------------------------------------------------
rbl_build
echo "done"

