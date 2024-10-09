#!/bin/bash
#########################################################################
#
# Download recipe for the used chromium packages
# Is an older version that can't be installed with apt from the debian repo.
# We just republish those packages in our moode repo.
#
# Newer version (98) gives white screen issue on moode boot local uit.
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

# 2024-07-18
PKG_VERSION=126.0.6478.164-rpt1

mkdir -p dist/binary
cd dist/binary

rm -rf *$PKG_VERSION*.deb*

wget "http://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-browser_${PKG_VERSION}_arm64.deb"
wget "http://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-browser-l10n_${PKG_VERSION}_all.deb"
wget "http://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-codecs-ffmpeg-extra_${PKG_VERSION}_arm64.deb"

ls
echo "Ready for upload to moode repo"

cd ../../
