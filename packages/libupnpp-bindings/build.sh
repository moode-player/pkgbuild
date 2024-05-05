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

PKG="libupnpp-bindings_0.26.1-1moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/libupnpp-bindings.git"
PKG_SOURCE_GIT_TAG="libupnpp-bindings-v0.26.1"

rbl_prepare_from_git_with_deb_repo
#------------------------------------------------------------
# Custom part of the packing

rbl_patch $BASE_DIR/debian.rules.mesonoutput.patch

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

# -----------------------------------------------------------
rbl_build
echo "done"

