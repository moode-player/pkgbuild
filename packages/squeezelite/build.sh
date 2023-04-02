#!/bin/bash
#########################################################################
#
# Build recipe for patched squeezelite with RPI and GPIO options
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG_DSC_URL="http://deb.debian.org/debian/pool/main/s/squeezelite/squeezelite_1.9+git20210102.78fef68-3.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# patch and add patch to debian
if [ $ARCH64 -eq 1 ]
then
    rbl_patch $BASE_DIR/debian.rules.64.patch
else
    rbl_patch $BASE_DIR/debian.rules.patch
fi

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Rebuild for moOde bullseye with RPI and GPIO options."

#------------------------------------------------------------

rbl_build
echo "done"
