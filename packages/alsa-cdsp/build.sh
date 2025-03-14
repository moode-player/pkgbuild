#!/bin/bash
#########################################################################
#
# Build recipe for alsa-cdsp debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="alsa-cdsp_1.2.0-2moode1"

PKG_SOURCE_GIT="https://github.com/bitkeeper/alsa_cdsp.git"
PKG_SOURCE_GIT_TAG="v1.2.0"
# PKG_SOURCE_GIT_TAG="fixes/bookworm_cargs_empty"

rbl_check_build_dep libasound2-dev
# used for converting readme.md to man page
rbl_check_build_dep pandoc

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
git checkout fixes/bookworm_cargs_empty
PKG_SOURCE_GIT_TAG="fixes/bookworm_cargs_empty"
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing

dh_make -l -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../LICENSE -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

rbl_patch $BASE_DIR/debug_level.patch
EDITOR=/bin/true dpkg-source --commit . debug_level.patch

rbl_patch $BASE_DIR/fix_make_clean.patch
EDITOR=/bin/true dpkg-source --commit . fix_make_clean.patch

rbl_patch $BASE_DIR/fix_libdir_for_deb_build.patch
EDITOR=/bin/true dpkg-source --commit . fix_deb_build.patch

rbl_fix_control_patch_maintainer $BASE_DIR/debian.control.patch $BUILD_ROOT_DIR/debian.control.patch
rbl_patch $BUILD_ROOT_DIR/debian.control.patch

rbl_patch $BASE_DIR/debian.rules.patch

pandoc -r markdown -w man ./README.md -o ./debian/manpage.1
rm debian/manpage.*.ex
rm debian/README.*

# DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

