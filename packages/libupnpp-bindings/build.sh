#!/bin/bash

. ../../scripts/rebuilder.lib.sh

PKG="libupnpp-bindings_0.20.1-1~moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/libupnpp-bindings.git "
PKG_SOURCE_GIT_TAG="libupnpp-bindings-v0.20.1"

rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

#------------------------------------------------------------
# Custom part of the packing

patch -p1 < ../debian.control.patch
echo "10" > debian/compat
_rbl_check_build_deps
./autogen.sh
chmod +x ./configure
# the two commands shouldn't be needed, but without wrong makefiles are generate wich cause a swig error about an unsupported option -Wdate-time
./configure --prefix=/usr PYTHON_VERSION=3.9
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

