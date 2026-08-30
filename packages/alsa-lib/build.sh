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
# Built the way moOde builds mpd: the upstream release tag from git, plus the
# running distro's own debian/ packaging grabbed as a plain tarball. We do NOT
# fetch a source .dsc - on Raspberry Pi OS its .dsc is signed with a key dget
# cannot verify, and chasing per-distro pool URLs and revisions is fragile. The
# debian/ tarball is fetched and untarred without any signature check, pinned to
# the distro's revision, so the package keeps the distro's version and nothing
# has to refresh an apt source index on every build.
#
# Both patches are submitted upstream (alsa-project/alsa-lib #516 and #517), but
# merging there is only the first of four steps: alsa-project must cut a release,
# Debian package it, and the base OS pick it up. Trixie is stable and keeps
# alsa-lib 1.2.14 for its whole life, so the fix reaches users on the NEXT base
# OS - years, not months. Drop this package when a base OS ships a fixed alsa-lib.
#
# (C) bitkeeper 2026 http://moodeaudio.org
# (C) Gjuju 2026 alsa_lib_scope_no_abort.patch, alsa_lib_scope_dsd_levels.patch
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

PKG="alsa-lib_1.2.14-1+rpt1"
PKG_SOURCE_GIT="https://github.com/alsa-project/alsa-lib.git"
PKG_SOURCE_GIT_TAG="v1.2.14"
PKG_DEBIAN="http://archive.raspberrypi.com/debian/pool/main/a/alsa-lib/alsa-lib_1.2.14-1+rpt1.debian.tar.xz"

# The patches were written against 1.2.14 and dry-run clean through 1.2.16.1. If
# the distro's own alsa-lib has moved past that, warn - it may already carry a
# fix, or the hunks may need refreshing - but do not block the build.
PATCH_TESTED="1.2.16.1"
DISTRO_VERSION=`LC_ALL=C apt-cache policy libasound2t64 libasound2 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {print $2; exit}'`
if [ -n "$DISTRO_VERSION" ] && dpkg --compare-versions "${DISTRO_VERSION%-*}" gt "$PATCH_TESTED"
then
    echo "${YELLOW}Warning: the distro ships alsa-lib $DISTRO_VERSION, newer than the last tested $PATCH_TESTED - the meter scope may already be fixed upstream, or these patches may need updating.${NORMAL}"
fi

rbl_prepare_from_git_with_deb_repo

#------------------------------------------------------------
# Custom part of the packing

# bring in the distro's debian/ packaging (plain tarball, no signature to verify)
rbl_grab_debian_archive $PKG_DEBIAN

# add our two meter scope patches
rbl_patch $BASE_DIR/alsa_lib_scope_no_abort.patch
EDITOR=/bin/true dpkg-source --commit . alsa_lib_scope_no_abort.patch
rbl_patch $BASE_DIR/alsa_lib_scope_dsd_levels.patch
EDITOR=/bin/true dpkg-source --commit . alsa_lib_scope_dsd_levels.patch

# patch(1) applies with offset and fuzz, so check the result, not just the exit code
for marker in "s16->silent" "dsd_frame_bits"
do
    if ! grep -q "$marker" src/pcm/pcm_meter.c
    then
        echo "${RED}Error: $marker missing after patching, the patches did not apply as expected${NORMAL}"
        exit 1
    fi
done

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Added PCM meter scope patches: no abort on unconvertible formats, DSD levels"

# read back from the changelog: FULL_VERSION does not carry the local suffix here,
# the distro revision (1+rpt1) already fills the field it is decoded from
DEB_VERSION=`dpkg-parsechangelog -S Version`

#------------------------------------------------------------

rbl_build

# This source produces several binaries that have to be published together:
# libasound2-dev Depends: libasound2t64 (= ${binary:Version}). A repo holding the
# patched library without its matching -dev makes apt remove libasound2-dev, and
# every later build needing it fails. deploy.sh takes one package per run and
# matches on the file name, and alsa-lib is not one of the binary names.
echo "${GREEN}Publish with:${NORMAL}"
for binary in libasound2t64 libasound2-data libasound2-dev
do
    echo "  ../../scripts/deploy.sh ${binary}_${DEB_VERSION}"
done

echo "done"
