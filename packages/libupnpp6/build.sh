#!/bin/bash

. ../../scripts/rebuilder.lib.sh


PKG="libupnpp6_0.21.0-1moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/libupnpp.git"
PKG_SOURCE_GIT_TAG="libupnpp-v0.21.0"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

#------------------------------------------------------------

rbl_build
echo "done"

