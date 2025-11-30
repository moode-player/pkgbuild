#!/bin/bash
#########################################################################
#
# Build recipe for caps debian package with 12 band peq
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/c/caps/caps_0.9.26-1.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# patch and add patch to debian
rbl_patch $BASE_DIR/caps_12band_eqp.patch
EDITOR=/bin/true dpkg-source --commit . caps_12band_eqp.patch

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Added patch for 12 band eqfa12p PEQ"

#------------------------------------------------------------

rbl_build
echo "done"
