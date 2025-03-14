#!/bin/bash
#########################################################################
#
# Build recipe for mpc
#
# (C) bitkeeper 2025 http://moodeaudio.org
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

DEBSUFFIX=moode
PKG_DSC_URL="http://deb.debian.org/debian/pool/main/m/mpc/mpc_0.35-1.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "fix and rebuild for moode"

#------------------------------------------------------------

rbl_build
echo "done"
