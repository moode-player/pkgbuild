#!/bin/bash
#########################################################################
#
# Build recipe for shairport-sync-metadata-reader debian package
#
# (C) bitkeeper 2025 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

GIT_HASH=9caf251
PKG="shairport-sync-metadata-reader_1.0.2~git20250413.$GIT_HASH-1moode1"

PKG_SOURCE_GIT="https://github.com/mikebrady/shairport-sync-metadata-reader.git"
PKG_SOURCE_GIT_TAG="master"


rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

git checkout -b dev $GIT_HASH
rbl_create_git_archive $GIT_HASH ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -s -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz


rbl_fix_control_patch_maintainer $BASE_DIR/debian-copyright.patch $BUILD_ROOT_DIR/debian-copyright.patch
rbl_patch $BUILD_ROOT_DIR/debian-copyright.patch

rm debian/manpage.*.ex
rm debian/README.*

rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

