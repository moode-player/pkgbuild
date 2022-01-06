#!/bin/bash
#########################################################################
#
# Build recipe for udisks debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################


DEBSUFFIX=moode
. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/udisks/1.0.5-1/udisks_1.0.5-1.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

echo "10" > debian/compat

sed -i "s/[ ]libparted0-dev/ libparted-dev/" debian/control
sed -i "/liblvm2-dev/d" debian/control
sed -i "s/enable-lvm2/disable-lvm2/" debian/rules
sed -i "s/udisks\///" debian/udisks.install

# fix a number of missing sys/sysmacros.h and sys/stat.h includes
patch -p2 < $BASE_DIR/fix_missing_includes.patch

# fix service file with file location
sed -r -i "s/\(prefix\)\/lib\/udisks/\(libexecdir\)/" data/Makefile.am

EDITOR=/bin/true dpkg-source --commit . fix_missing_includes.patch

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "fix and rebuild for moode"
# exit
#------------------------------------------------------------

rbl_build
echo "done"
