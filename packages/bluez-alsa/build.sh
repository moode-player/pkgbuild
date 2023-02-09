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
#
#########################################################################


. ../../scripts/rebuilder.lib.sh

PKG="bluez-alsa_4.0.0-2moode1"

PKG_SOURCE_GIT="https://github.com/arkq/bluez-alsa.git"
PKG_SOURCE_GIT_TAG="v4.0.0"

PKG_DEBIAN="http://deb.debian.org/debian/pool/main/b/bluez-alsa/bluez-alsa_3.0.0-2.debian.tar.xz"


rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

# enable cli
rbl_patch $BASE_DIR/build_cli.debian.rules.patch

echo "usr/share/man/man7/bluealsa-plugins.7" >> debian/bluez-alsa-utils.manpages
echo "usr/share/man/man1/bluealsa-cli.1" >> debian/bluez-alsa-utils.manpages


DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde."

#------------------------------------------------------------

rbl_build
echo "done"
