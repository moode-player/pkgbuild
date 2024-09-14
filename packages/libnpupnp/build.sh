#!/bin/bash
#########################################################################
#
# Build recipe for libnpupnp debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG="libnpupnp_6.2.0-1moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/npupnp.git"
PKG_SOURCE_GIT_TAG="libnpupnp-v6.2.0"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

#------------------------------------------------------------

rbl_build
echo "done"

