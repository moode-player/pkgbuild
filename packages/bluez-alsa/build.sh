#!/bin/bash
#########################################################################
#
# Build recipe for bluez-alsa debian package
#
# (C) bitkeeper 2023 http://moodeaudio.org
# License: GPLv3
#
# While 3.0.2 was just a rebuild from a dsc, for 4.0.0:
#  - the deb skeleton files from 3.0.2 are used
#  - Source from the git repo are used
# With 4.2.0 switched back to a build from dsc
#
#########################################################################


. ../../scripts/rebuilder.lib.sh

PKG="bluez-alsa_4.3.1-3moode1"

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/b/bluez-alsa/bluez-alsa_4.3.1-3.dsc"


rbl_check_build_dep libfdk-aac-dev
rbl_prepare_from_dsc_url $PKG_DSC_URL


#------------------------------------------------------------
# Custom part of the packing


# enable cli
rbl_patch $BASE_DIR/build_cli.debian.rules.patch
rbl_patch $BASE_DIR/debian.rules.aac.patch
rbl_patch $BASE_DIR/debian.rules.skiptest.patch

# changes deps
# rbl_patch $BASE_DIR/debian.control.patch

echo "usr/share/man/man1/bluealsa-cli.1" >> debian/bluez-alsa-utils.manpages


DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion "${FULL_VERSION}" "Build for moOde."

#------------------------------------------------------------

rbl_build
echo "done"
