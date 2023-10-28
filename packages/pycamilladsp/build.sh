#!/bin/bash
#########################################################################
#
# Build recipe for pycamilladsp debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org distutils version
# (C) bitkeeper 2023 http://moodeaudio.org pyproject.toml version
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

# don't forget to change the debian/changelog on version bump!
PKG="pycamilladsp_2.0.0-1moode1~a2"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp.git"
PKG_SOURCE_GIT_TAG="v2.0.0-alpha2"

rbl_check_build_dep dh-python

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

#------------------------------------------------------------
# Custom part of the packing
cp -raf ${BASE_DIR}/debian ./debian

#-----------------------------------------------------------
rbl_build
echo "done"
