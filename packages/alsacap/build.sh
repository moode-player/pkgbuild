#!/bin/bash
#########################################################################
#
# Build recipe for alscap debian pacakge
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="alsacap_1.0.1-1moode1"

PKG_SOURCE_GIT="https://github.com/bubbapizza/alsacap.git"
PKG_SOURCE_GIT_TAG="master"  # warning not fixed to git 6b7687ca5542abe05dc3198d444fd8119b82fcee

rbl_check_build_dep libasound2-dev
rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -s -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../COPYING -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

rbl_fix_control_patch_maintainer $BASE_DIR/debian.control.patch $BUILD_ROOT_DIR/debian.control.patch
rbl_patch $BUILD_ROOT_DIR/debian.control.patch

rm debian/manpage.*.ex
rm debian/README.*
cp README debian/README

#DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde audioplayer" -b
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

