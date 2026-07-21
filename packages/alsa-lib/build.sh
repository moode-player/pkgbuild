#!/bin/bash
#########################################################################
#
# Build recipe for alsa-lib debian package with the PCM meter scope fixes
#
# The stock library is used as shipped by the distro. These two patches
# only touch the s16 scope of the `type meter` plugin, which is what
# libpeppyalsa taps for the VU meter:
#
#  - scope_no_abort: the scope aborts the calling application on any format
#    it cannot convert to S16 (DSD, the 3-byte packed formats, float). MPD
#    dies mid-playback on a DSD track. It now reads silence instead.
#  - scope_dsd_levels: recover a level from a DSD stream by bit density, so
#    the needles work on native DSD instead of sitting still.
#
# Both are submitted upstream (alsa-project/alsa-lib #516 and #517), but merging
# there is only the first of four steps: alsa-project must cut a release, Debian
# package it, and the base OS pick it up. Trixie is stable and keeps alsa-lib
# 1.2.14 for its whole life, so the fix reaches users on the NEXT base OS - years,
# not months. Drop this package when a base OS actually ships a fixed alsa-lib.
#
# (C) bitkeeper 2026 http://moodeaudio.org
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

PKG_DSC_URL="http://deb.debian.org/debian/pool/main/a/alsa-lib/alsa-lib_1.2.14-1.dsc"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# patch and add patches to debian
rbl_patch $BASE_DIR/alsa_lib_scope_no_abort.patch
EDITOR=/bin/true dpkg-source --commit . alsa_lib_scope_no_abort.patch
rbl_patch $BASE_DIR/alsa_lib_scope_dsd_levels.patch
EDITOR=/bin/true dpkg-source --commit . alsa_lib_scope_dsd_levels.patch

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Added PCM meter scope patches: no abort on unconvertible formats, DSD levels"

#------------------------------------------------------------

rbl_build
echo "done"
