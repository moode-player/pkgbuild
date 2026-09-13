#!/bin/bash
#########################################################################
#
# Build recipe for qbzd debian package
#
# (C) 2026 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="qbzd_2.0.2-49-1moode1"

# Upstream reads its build id back from QBZD_BUILD_ID at compile time; without
# it the binary reports the bare crate version and the build it came from is no
# longer identifiable.
export QBZD_BUILD_ID="2.0.2.moode49"

PKG_SOURCE_GIT="https://github.com/PhilipVinc/qbz.git"
PKG_SOURCE_GIT_TAG="qbzd-v2.0.2.moode49"

# Set before rbl_check_cargo so it also covers the cargo-deb install it may
# trigger, itself a build of some 200 crates.

# cargo defaults to one rustc per core; on a 4-core 1 GB board that stacks four
# and thrashes swap hard enough for the systemd watchdog to reset the board.
# This workspace is a good deal heavier than librespot, so keep 512 MB aside
# for the system and budget another 512 MB per job, clamped to [1, nproc]:
# 1 GB builds single-job, 2 GB gets two. An explicit CARGO_BUILD_JOBS wins.
if [[ -z "$CARGO_BUILD_JOBS" ]]
then
    MEM_MB=`awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo`
    CARGO_BUILD_JOBS=$(( (MEM_MB - 512) / 512 ))
    [[ $CARGO_BUILD_JOBS -lt 1 ]] && CARGO_BUILD_JOBS=1
    [[ $CARGO_BUILD_JOBS -gt `nproc` ]] && CARGO_BUILD_JOBS=`nproc`
    export CARGO_BUILD_JOBS
fi
echo "${YELLOW}building qbzd with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS} (RAM ${MEM_MB:-?}MB, `nproc` cores)${NORMAL}"

rbl_check_cargo
rbl_prepare_clone_from_git ${PKG_SOURCE_GIT} ${PKG_SOURCE_GIT_TAG}
rbl_create_git_archive ${PKG_SOURCE_GIT_TAG} ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

# qbzd is the slint-free column of the workspace: ALSA and JACK for audio,
# D-Bus for MPRIS, TLS, and the -sys toolchain. None of the GUI stack the
# desktop binary needs (fontconfig, freetype, wayland, xcb, GL) is linked.
rbl_check_build_dep pkg-config
rbl_check_build_dep cmake
rbl_check_build_dep clang
rbl_check_build_dep libclang-dev
rbl_check_build_dep libasound2-dev
rbl_check_build_dep libjack-jackd2-dev
rbl_check_build_dep libdbus-1-dev
rbl_check_build_dep libssl-dev

# Upstream packages for Arch, snap and Flatpak but ships no Debian metadata,
# so the [package.metadata.deb] section cargo-deb reads is added here.
rbl_patch $BASE_DIR/qbzd-cargo-deb.patch

# The cargo workspace root is crates/, not the repo root: the top level carries
# flake.nix, snapcraft.yaml and flatpak/ but no manifest.
cd crates

# cargo-deb builds the package version from the crate version plus a revision,
# and a Debian revision cannot hold the upstream build number (no hyphens are
# allowed in it), so pass the whole version instead. It comes from PKG, which
# stays the single place to bump.
RUSTFLAGS='-Ccodegen-units=1' cargo-deb -p qbzd --deb-version "${PKGVERSION}-${DEBVER}${DEBLOC}" --

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build${NORMAL}"
    exit 1
fi

mv target/debian/* ..
cd ..
#------------------------------------------------------------
# post_build
rbl_move_to_dist

echo "done"
