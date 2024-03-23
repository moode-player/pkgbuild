#!/bin/bash
#########################################################################
#
# Build recipe for mpd2cdspvolume debian package
#
# (C) bitkeeper 2023 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG="mpd2cdspvolume_1.0.0-1moode2"

PKG_SOURCE_GIT="https://github.com/bitkeeper/mpd2cdspvolume.git"
PKG_SOURCE_GIT_TAG="v1.0.0"

# rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_prepare_clone_from_git $PKG_SOURCE_GIT

#------------------------------------------------------------
# Custom part of the packing

mkdir -p root/usr/local/bin
cp mpd2cdspvolume.py root/usr/local/bin/mpd2cdspvolume
cp cdspstorevolume.sh root/usr/local/bin/cdspstorevolume
mkdir -p root/usr/lib/tmpfiles.d
cp etc/mpd2cdspvolume.conf root/usr/lib/tmpfiles.d/
mkdir -p root/etc
cp etc/mpd2cdspvolume.config root/etc

chmod a+x root/usr/local/bin/mpd2cdspvolume
chmod a+x root/usr/local/bin/cdspstorevolume

# build the package
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license MIT \
--category misc \
-S moode \
--iteration $DEBVER$DEBLOC \
-a all \
--deb-priority optional \
--url https://github.com/bitkeeper/mpd2cdspvolume \
-m $DEBEMAIL \
--license LICENSE \
--description "Service for synchronizing MPD volume to CamillaDSP." \
--deb-systemd etc/mpd2cdspvolume.service \
--depends python3-mpd2 \
--depends python3-camilladsp \
--after-install etc/postinstall.sh \
root/usr/=/usr/. \
root/etc/=/etc/.

if [[ $? -gt 0 ]]
then
  exit 1
fi

#-----------------------------------------------------------
rbl_move_to_dist
echo "done"
