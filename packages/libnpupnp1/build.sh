#!/bin/bash

. ../../scripts/rebuilder.lib.sh


PKG="libnpupnp1_4.1.1-1~moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/npupnp.git"
PKG_SOURCE_GIT_TAG="libnpupnp-v4.1.1"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

#------------------------------------------------------------

rbl_build
echo "done"

