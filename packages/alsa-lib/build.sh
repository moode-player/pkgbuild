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
# not months.
#
# The recipe therefore follows the base OS instead of pinning one version: it
# builds whatever alsa-lib the build host's distro offers, refuses versions it
# has not been validated against, and asks the source itself whether it is still
# needed, so nothing here has to track an upstream release or pull request number.
#
# (C) bitkeeper 2026 http://moodeaudio.org
# License: GPLv3
#
#########################################################################
. ../../scripts/rebuilder.lib.sh

# Version to rebuild. Defaults to the distro candidate, so a point release that
# drops the old .dsc from the pool does not break the build. Override both when
# the base OS carries its own alsa-lib revision.
ALSA_MIRROR=${ALSA_MIRROR:-http://deb.debian.org/debian}
ALSA_VERSION=${ALSA_VERSION:-`LC_ALL=C apt-cache policy libasound2t64 libasound2 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {print $2; exit}'`}

if [ -z "$ALSA_VERSION" ]
then
    echo "${RED}Error: could not determine the alsa-lib version to build, set ALSA_VERSION${NORMAL}"
    exit 1
fi

ALSA_UPSTREAM=${ALSA_VERSION%-*}

# Oldest upstream release the patches were validated against
PATCH_FLOOR="1.2.14"

if dpkg --compare-versions "$ALSA_UPSTREAM" lt "$PATCH_FLOOR"
then
    echo "${RED}Error: alsa-lib $ALSA_UPSTREAM is older than $PATCH_FLOOR, the patches are untested there${NORMAL}"
    exit 1
fi

# One patch set covers 1.2.14 up to 1.2.16.1: pcm_meter.c is unchanged from
# 1.2.15 onwards, and the 1.2.14 -> 1.2.15 churn (whitespace, SNDERR replaced by
# the new log macros) misses the patched hunks. Branch here if a later version
# moves them.
PATCHES="alsa_lib_scope_no_abort.patch alsa_lib_scope_dsd_levels.patch"

PKG_DSC_URL="$ALSA_MIRROR/pool/main/a/alsa-lib/alsa-lib_${ALSA_VERSION}.dsc"

echo "building alsa-lib $ALSA_VERSION from $PKG_DSC_URL"

rbl_prepare_from_dsc_url $PKG_DSC_URL

#------------------------------------------------------------
# Custom part of the packing

# This package only exists while the scope still bails out on a format it cannot
# convert. Ask the source, not a version number: any accepted form of the fix
# drops that bailout, whatever release or pull request it arrives by, and
# upstream numbers are not a reliable key - alsa-project reviews on alsa-devel
# and its maintainer commits most patches himself.
if ! awk '/^static int s16_enable/,/^}/' src/pcm/pcm_meter.c | grep -A2 "^	default:" | grep -q -- "return -EINVAL"
then
    echo "alsa-lib $ALSA_UPSTREAM already handles unconvertible formats, this package is obsolete - nothing to build"
    exit 0
fi

# patch and add patches to debian
for patch in $PATCHES
do
    rbl_patch $BASE_DIR/$patch
    EDITOR=/bin/true dpkg-source --commit . $patch
done

# patch(1) applies with offset and fuzz, so check the result instead of trusting
# the exit code alone
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

#------------------------------------------------------------

rbl_build
echo "done"
