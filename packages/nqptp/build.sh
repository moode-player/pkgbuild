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

PKG="nqptp_1.2.4-1moode1"
PKG_SOURCE_GIT="https://github.com/mikebrady/nqptp.git"
PKG_SOURCE_GIT_TAG="1.2.4"

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -s -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz
cp $BASE_DIR/nqptp.service debian/

rbl_fix_control_patch_maintainer $BASE_DIR/debian.control.patch $BUILD_ROOT_DIR/debian.control.patch
rbl_patch $BUILD_ROOT_DIR/debian.control.patch

rbl_patch $BASE_DIR/skip_install_exe_hook.patch
EDITOR=/bin/true dpkg-source --commit . skip_install_exe_hook.patch
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"
