#!/bin/bash
#########################################################################
#
# Build recipe for pibuz debian package
#
# (C) 2026 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

# Plain semver, matching the pibuz release tag below.
#
# A pre-release goes here as `~rc.N`, never `-rc.N` -- `pibuz_2.4.0~rc.3-1moode1`.
# dpkg sorts a plain 2.4.0 BELOW any hyphen-suffixed version, so a hyphenated rc
# would outrank the release it precedes and block the upgrade to it. A `~` sorts
# before the empty string, which is what a pre-release wants.
PKG="pibuz_2.4.0-1moode1"

PKG_SOURCE_GIT="https://github.com/PhilipVinc/pibuz.git"
PKG_SOURCE_GIT_TAG="v2.4.0"

# cargo defaults to one rustc per core; on a 4-core 1 GB board that stacks four
# and thrashes swap hard enough for the systemd watchdog to reset the board, so
# keep 512 MB aside for the system and budget another 512 MB per job, clamped
# to [1, nproc]: 1 GB builds single-job, 2 GB gets two. Set before
# rbl_check_cargo so it also covers the cargo-deb install it may trigger.
# An explicit CARGO_BUILD_JOBS from the environment wins.
if [[ -z "$CARGO_BUILD_JOBS" ]]
then
    MEM_MB=`awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo`
    CARGO_BUILD_JOBS=$(( (MEM_MB - 512) / 512 ))
    [[ $CARGO_BUILD_JOBS -lt 1 ]] && CARGO_BUILD_JOBS=1
    [[ $CARGO_BUILD_JOBS -gt `nproc` ]] && CARGO_BUILD_JOBS=`nproc`
    export CARGO_BUILD_JOBS
fi
echo "${YELLOW}building pibuz with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS} (RAM ${MEM_MB:-?}MB, `nproc` cores)${NORMAL}"

rbl_check_cargo

# The source tree carries a rust-toolchain.toml asking for floating stable.
# Left alone, rustup honours it and downloads a SECOND toolchain next to the
# one rbl_check_cargo just pinned -- some 400 MB of extra traffic and card on a
# board that has neither to spare. RUSTUP_TOOLCHAIN outranks the file.
export RUSTUP_TOOLCHAIN=`rustup show active-toolchain | cut -d' ' -f1`
echo "${YELLOW}pinning the build to ${RUSTUP_TOOLCHAIN}${NORMAL}"

rbl_prepare_clone_from_git ${PKG_SOURCE_GIT} ${PKG_SOURCE_GIT_TAG}
rbl_create_git_archive ${PKG_SOURCE_GIT_TAG} ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

# The whole native-dep list, verified by building in a container that had
# nothing else: alsa-sys, probed with pkg-config. Notably absent, and each
# checked by removing it and rebuilding the crate that would have wanted it:
#   libssl-dev        TLS is rustls; no openssl-sys in the graph
#   libdbus-1-dev     MPRIS is mpris-server on zbus, pure Rust
#   clang libclang-dev  nothing in the graph runs bindgen
#   cmake             aws-lc-sys, the rustls provider, builds its C with cc
#   libjack-jackd2-dev  JACK is off by default upstream as of 2.4.0-rc.3
# None of the desktop GUI stack (fontconfig, freetype, wayland, xcb, GL) is
# linked either: pibuz is the slint-free column of the workspace, which
# upstream CI gates on.
#
# The jack one is worth a word since it was needed as recently as rc.1.
# jack-sys fails its build script without jack.pc, so having the crate in the
# graph at all made libjack a build requirement -- for a routing backend that
# resamples, which a bit-perfect endpoint can never use. Upstream moved it
# behind an off-by-default feature, and upstream CI now fails if the default
# graph resolves jack again.
rbl_check_build_dep pkg-config
rbl_check_build_dep libasound2-dev

# cargo-deb derives the package version from the crate version plus a Debian
# revision, and a revision cannot hold the `~rc.N` a pre-release needs, so pass
# the whole thing. It comes from PKG, which stays the single place to bump.
RUSTFLAGS='-Ccodegen-units=1' cargo-deb -p pibuz --deb-version "${PKGVERSION}-${DEBVER}${DEBLOC}"

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build${NORMAL}"
    exit 1
fi

mv target/debian/* .
#------------------------------------------------------------
# post_build
rbl_move_to_dist

echo "done"
