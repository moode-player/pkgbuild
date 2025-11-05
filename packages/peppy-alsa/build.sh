#!/bin/bash
#########################################################################
#
# Build recipe for peppymeter debian package
#
# (C) bitkeeper 2025 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="peppy-alsa_2024.02.10-1moode1"

PKG_SOURCE_GIT="https://github.com/project-owner/peppyalsa.git"
PKG_SOURCE_GIT_TAG="master"

rbl_check_build_dep libasound2-dev
rbl_check_build_dep libfftw3-dev

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.tar.gz

#------------------------------------------------------------
# Custom part of the packing
dh_make -l -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../LICENSE -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

rbl_patch $BASE_DIR/peppy_alsa_fixes_by_kent_reed.patch
EDITOR=/bin/true dpkg-source --commit . peppy_alsa_fixes_by_kent_reed.patch
rm debian/manpage.*.ex
rm debian/README.*
rm debian/pep

cp $BASE_DIR/control debian/control
cp -f README debian/README.Debian
# DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

