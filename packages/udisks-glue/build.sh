#!/bin/bash

. ../../scripts/rebuilder.lib.sh

PKG="udisks-glue_1.3.5-1moode1"

PKG_SOURCE_GIT="https://github.com/fernandotcl/udisks-glue.git"
PKG_SOURCE_GIT_TAG="release-1.3.5"

# Coming from https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/udisks-glue/1.3.2-1/udisks-glue_1.3.2-1.dsc
PKG_DEBIAN="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/udisks-glue/1.3.2-1/udisks-glue_1.3.2-1.debian.tar.gz"


rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# grab debian dir of older version
rbl_grab_debian_archive $PKG_DEBIAN

echo "10" > debian/compat

DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Build for moOde."

#------------------------------------------------------------
rbl_build
echo "done"

