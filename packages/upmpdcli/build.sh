#!/bin/bash
#########################################################################
#
# Build recipe for upmpdcli debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG="upmpdcli_1.8.10-1moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/upmpdcli.git"
PKG_SOURCE_GIT_TAG="upmpdcli-v1.8.10"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

#------------------------------------------------------------

rbl_build
echo "done"

