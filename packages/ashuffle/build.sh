#!/bin/bash
#########################################################################
#
# Build recipe for ashuffle debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

#TODO: If needed add systemd files

PKG="ashuffle_3.14.9-1moode1"

PKG_SOURCE_GIT="https://github.com/joshkunz/ashuffle.git"
PKG_SOURCE_GIT_TAG="v3.14.9"


rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -s -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

#TODO: replace it with a better solution: include submodules in the archive
rbl_patch $BASE_DIR/debian.rules.initsubmodule.patch
rbl_fix_control_patch_maintainer $BASE_DIR/debian.control.patch $BUILD_ROOT_DIR/debian.control.patch
rbl_patch $BUILD_ROOT_DIR/debian.control.patch
rm debian/manpage.*.ex
rm debian/README.*

# DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

