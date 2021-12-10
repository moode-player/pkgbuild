#!/bin/bash

. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/b/bluez-alsa/bluez-alsa_3.0.0-2.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Rebuild for moOde bullseye"

#------------------------------------------------------------

rbl_build
echo "done"
