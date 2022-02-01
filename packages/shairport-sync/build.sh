#!/bin/bash
#########################################################################
#
# Build recipe for shairport-sync
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="shairport-sync_3.3.8-1moode1"
PKG_DSC_URL="http://deb.debian.org/debian/pool/main/s/shairport-sync/shairport-sync_3.3.8-1.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL


#------------------------------------------------------------
# Custom part of the packing

# patch and add patch to debian
# patch -p1 < $BASE_DIR/debian.rules.patch

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Rebuild for moOde bullseye."

#------------------------------------------------------------

rbl_build
echo "done"
