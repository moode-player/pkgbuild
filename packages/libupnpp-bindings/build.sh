#!/bin/bash
#########################################################################
#
# Build recipe for libupnpp-bindings debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################


. ../../scripts/rebuilder.lib.sh

PKG="libupnpp-bindings_0.21.0-1moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/libupnpp-bindings.git"
PKG_SOURCE_GIT_TAG="libupnpp-bindings-v0.21.0"

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

#------------------------------------------------------------
# Custom part of the packing

rbl_patch $BASE_DIR/debian.control.patch
rbl_patch $BASE_DIR/debian.rules.patch
echo "10" > debian/compat
_rbl_check_build_deps
./autogen.sh
chmod +x ./configure
# the two commands shouldn't be needed, but without wrong makefiles are generate wich cause a swig error about an unsupported option -Wdate-time
./configure --prefix=/usr PYTHON_VERSION=3.11
make

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

# -b only binary pkg no source possible to
# -d option required because the dep names aren't correct for python3
dpkg-buildpackage -b -uc -us -d
cd ..

# -----------------------------------------------------------
pwd
rbl_move_to_dist
echo "done"

