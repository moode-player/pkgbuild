#!/bin/bash
#########################################################################
#
# Build Recipe for alsa-cdsp
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="alsa-cdsp_1.0.0-1~moode1"

PKG_SOURCE_GIT="https://github.com/bitkeeper/alsa_cdsp.git"
PKG_SOURCE_GIT_TAG="v1.0.0"

# used for converting readme.md to man page
rbl_check_build_dep pandoc

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

#------------------------------------------------------------
# Custom part of the packing

git archive  --format=tar.gz --output ../${PKGNAME}_${PKGVERSION}.tar.gz v$PKGVERSION

dh_make -l -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../LICENSE -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

patch -p1 < ../fix_make_clean.patch
EDITOR=/bin/true dpkg-source --commit . fix_make_clean.patch

patch -p1 < ../fix_libdir_for_deb_build.patch
EDITOR=/bin/true dpkg-source --commit . fix_deb_build.patch

patch -p1 < ../debian.control.patch

pandoc -r markdown -w man ./README.md -o ./debian/manpage.1
rm debian/manpage.*.ex
rm debian/README.*

# DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"

