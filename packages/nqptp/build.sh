#!/bin/bash
#########################################################################
#
# Build recipe for nqptpt debian package
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

GIT_BASH=c71b49a
PKG="nqptp_1.1.0~git20220930.$GIT_BASH-1moode1"
PKG_SOURCE_GIT="https://github.com/mikebrady/nqptp.git"
PKG_SOURCE_GIT_TAG="main"

# rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_prepare_clone_from_git $PKG_SOURCE_GIT
git checkout $GIT_BASH
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -l -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../LICENSE -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz
cp $BASE_DIR/nqptp.service debian/

rbl_fix_control_patch_maintainer $BASE_DIR/debian.control.patch $BUILD_ROOT_DIR/debian.control.patch
patch -p1 < $BASE_DIR/debian.control.patch

rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

