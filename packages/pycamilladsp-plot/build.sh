#!/bin/bash
#########################################################################
#
# Build recipe for pycamilladsp-plot debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="pycamilladsp-plot_2.0.0-1moode1~a3"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp-plot.git"
PKG_SOURCE_GIT_TAG="v2.0.0-alpha3"


rbl_check_build_dep dh-python

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

#------------------------------------------------------------
# Custom part of the packing
cp -raf ${BASE_DIR}/debian ./debian

#-----------------------------------------------------------
rbl_build
echo "done"
