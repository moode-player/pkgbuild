#!/bin/bash
#########################################################################
#
# Build recipe for log2ram debian package
#
# (C) bitkeeper 2024 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="log2ram_1.7.2-1moode1"

PKG_SOURCE_GIT="https://github.com/azlux/log2ram.git"
PKG_SOURCE_GIT_TAG="1.7.2"

rbl_check_build_dep jq
rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

#------------------------------------------------------------
# Custom part of the packing
./build-packages.sh

#------------------------------------------------------------
# rbl_build
mkdir -p $BASE_DIR/dist/binary
mv ./deb/log2ram_*.deb $BASE_DIR/dist/binary
echo "done"