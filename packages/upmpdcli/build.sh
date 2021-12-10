#!/bin/bash

. ../../scripts/rebuilder.lib.sh


PKG="upmpdcli_1.5.12-1~moode1"

PKG_SOURCE_GIT="https://framagit.org/medoc92/upmpdcli.git"
PKG_SOURCE_GIT_TAG="upmpdcli-v1.5.11"

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

patch -p1 < $BASE_DIR/debian.control.patch

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch -b --newversion $FULL_VERSION "Rebuild for moOde."

#------------------------------------------------------------

rbl_build
echo "done"

